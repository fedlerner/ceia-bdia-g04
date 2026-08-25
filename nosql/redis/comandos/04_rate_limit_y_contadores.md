# 04. Rate limit y contadores

Los comandos de este archivo se ejecutan en la consola de Redis o en el Workbench de RedisInsight, en
el orden en que aparecen.

El motor de recomendaciones y el modelo de IA son los componentes más costosos de la arquitectura. La
cache reduce cuántas veces se ejecutan ante solicitudes repetidas legítimas; el rate limit acota
cuántas veces puede invocarlos un mismo cliente. Son dos protecciones distintas sobre el mismo
recurso.

## Comando 1. Contadores operativos

**Pregunta de negocio:** ¿cuántas recomendaciones generó el motor y cuántas se sirvieron desde la
cache?

**Objetivo:** llevar acumulados operativos sin escribir en la base transaccional.

```redis
GET contador:{reco}:generadas
INCR contador:{reco}:generadas
INCRBY contador:{reco}:cache_hit 5
MGET contador:{reco}:generadas contador:{reco}:cache_hit
```

**Resultado esperado:** `INCR` devuelve el nuevo valor del contador y `MGET` devuelve ambos
acumulados en una sola respuesta.

**Justificación:** `INCR` interpreta el String como entero y lo incrementa de forma atómica. Si la
clave no existe, la inicializa en cero antes de incrementar, y ese comportamiento es el que permite
escribir el rate limit del comando siguiente sin comprobar previamente si la ventana ya existía.

En un motor relacional, un `UPDATE contadores SET valor = valor + 1` requiere una fila, un bloqueo y
una transacción. Acá el contador es la clave, y el costo de la operación es O(1).

Estos contadores no tienen expiración, a diferencia del resto de las estructuras de la capa. Eso no
los vuelve durables: al no haber persistencia se pierden con cada reinicio del contenedor y
`allkeys-lru` puede descartarlos bajo presión de memoria. Son acumulados best-effort, útiles para
observar el comportamiento durante una sesión de trabajo y no aptos como fuente de métricas de
negocio.

El hash tag de la clave, `contador:{reco}:...`, hace que Redis calcule el slot de Cluster únicamente
sobre la porción entre llaves. Sin él, las dos claves caerían en slots distintos y el `MGET` de este
bloque fallaría con `CROSSSLOT` en una instalación particionada.

## Comando 2. Rate limit por ventana fija

**Pregunta de negocio:** ¿cuántas solicitudes de recomendaciones lleva hechas este cliente en el
minuto actual?

**Objetivo:** contar las solicitudes de una ventana temporal que se descarta sola al vencer.

```redis
MULTI
INCR ratelimit:reco:user:user-123:202608191542
EXPIRE ratelimit:reco:user:user-123:202608191542 60 NX
EXEC
TTL ratelimit:reco:user:user-123:202608191542
```

Conviene repetir el bloque varias veces seguidas.

**Resultado esperado:** `EXEC` devuelve una lista de dos elementos. El primero es el contador, que
crece en cada repetición; el segundo es la respuesta de `EXPIRE`, que vale `1` en la primera
ejecución y `0` en las siguientes. El `TTL` decrece entre repeticiones.

**Justificación:** conviene separar dos cosas que es fácil confundir. **La ventana la define el
minuto que forma parte de la clave, no el TTL.** Al cambiar de minuto, la aplicación calcula otra
clave y el conteo vuelve a empezar solo. El TTL cumple una función distinta: eliminar las claves de
minutos ya pasados para que no se acumulen.

Por eso `EXPIRE ... NX`, que aplica el TTL únicamente si la clave todavía no tiene uno, acota la vida
de la clave a unos 60 segundos desde la primera solicitud de esa ventana. Sin `NX`, cada solicitud
extendería el vencimiento y la clave sobreviviría hasta 60 segundos después de la **última**
solicitud, ocupando memoria de más. **El límite se seguiría aplicando igual**, porque el conteo del
minuto 15:42 solo recibe las solicitudes de ese minuto.

En un diseño de ventana deslizante, donde la clave no lleva marca temporal y el TTL define la ventana,
omitir `NX` sí rompería el límite. No es el caso de este diseño.

Los dos comandos van dentro de una transacción. Ejecutados por separado, si la aplicación se cae
entre el `INCR` y el `EXPIRE`, la clave de ese minuto queda **sin TTL** y ya nunca se elimina. El
cliente no queda bloqueado, porque el minuto siguiente usa otra clave y su conteo arranca de cero; lo
que se produce es una **fuga de claves obsoletas** que se acumulan sin límite, una por cada minuto en
que ocurra el fallo. `MULTI` y `EXEC` garantizan que la creación del contador y su vencimiento se
apliquen juntos.

La clave lleva el discriminador `user` / `sess`, igual que la cache de recomendaciones. Un visitante
anónimo también invoca al motor, de modo que su cuota se cuenta en
`ratelimit:reco:sess:{session_id}:{ventana}`. Sin ese discriminador, un `session_id` y un
`customer_id` con el mismo texto compartirían contador.

El identificador de la ventana forma parte de la clave y lo calcula la aplicación a partir del reloj,
con el formato `AAAAMMDDHHmm`. En el ejemplo, `202608191542` corresponde al minuto 15:42 del
2026-08-19. Para Redis se trata simplemente de otra clave distinta, de modo que cada minuto obtiene su
propio contador y no hace falta borrar el anterior.

Resolver esto en PostgreSQL exigiría una tabla de solicitudes con su marca temporal, un `COUNT(*)`
con filtro por fecha en cada solicitud y un proceso de purga. Acá son dos operaciones O(1) y la purga
es automática.

### Limitación: el rate limit falla abierto bajo presión de memoria

Las claves `ratelimit:*` no están exentas de la política de descarte. Con `allkeys-lru`, si la
instancia alcanza `maxmemory` esos contadores pueden ser desalojados como cualquier otra clave, y el
siguiente `INCR` los recrea en 1. El cliente recupera su cuota completa **justo durante la
sobrecarga**, que es cuando el límite haría más falta.

Comprobado: con un contador en 30 de 30 y `maxmemory` forzado al límite, la clave fue descartada y el
`INCR` siguiente devolvió 1.

Redis no permite asignar prioridad de desalojo por clave, de modo que dentro de una única instancia
no hay forma de proteger estos contadores. Se acepta en este alcance porque la función del rate limit
aquí es acotar el uso normal y evitar invocaciones repetidas al motor, no resistir un abuso
deliberado. Una implementación en producción aislaría los contadores en una instancia o base
independiente cuya política no los desaloje, o los complementaría con un mecanismo que falle cerrado
cuando el contador no está disponible.

## Comando 3. Verificar el comportamiento en el límite

**Pregunta de negocio:** ¿qué estado observa la aplicación cuando un cliente agota su cuota?

**Objetivo:** llegar al límite sin ejecutar treinta comandos.

> Este bloque **prepara** el escenario que interesa observar; no es el patrón que debe
> implementarse. Usa `INCRBY` para saltar de una vez a la cuota agotada y emite el `EXPIRE` por
> separado. El patrón de producción es el del comando anterior, con `MULTI` y `EXEC`.

```redis
DEL ratelimit:reco:user:user-demo:202608191543
INCRBY ratelimit:reco:user:user-demo:202608191543 30
EXPIRE ratelimit:reco:user:user-demo:202608191543 60 NX
GET ratelimit:reco:user:user-demo:202608191543
INCR ratelimit:reco:user:user-demo:202608191543
```

**Resultado esperado:** el último `INCR` devuelve 31.

**Justificación:** Redis no rechaza nada por sí mismo. Devuelve 31 y la decisión de rechazar la
solicitud corresponde a la aplicación, que compara ese valor contra el límite configurado. Redis
aporta el contador atómico y la expiración; la política es responsabilidad del backend.

El límite de 30 solicitudes por minuto es un valor de ejemplo, elegido para poder observar el
escenario de cuota agotada. Fijar el número que corresponde al caso es una política de la aplicación
y queda fuera del alcance de este trabajo, que cubre la capa de datos: Redis aporta el contador
atómico y la expiración de la ventana. Ver la sección 2.10 del modelo.

Las claves `ratelimit:*` que crea esta comprobación vencen solas en 60 segundos y no requieren
limpieza manual.

## Comando 4. Consultar la cuota sin consumirla

**Pregunta de negocio:** ¿cuántas solicitudes le quedan al cliente y cuándo se reinicia su ventana?

**Objetivo:** obtener el estado de la cuota sin producir efectos sobre ella.

```redis
GET ratelimit:reco:user:user-demo:202608191543
TTL ratelimit:reco:user:user-demo:202608191543
```

**Resultado esperado:** el valor actual del contador y los segundos que le restan a la clave.

**Justificación:** ninguno de los dos comandos modifica el estado, de modo que consultar la cuota no
consume cuota. Son el insumo para las cabeceras `X-RateLimit-Remaining` y `X-RateLimit-Reset`, pero
ninguno de los dos es directamente el valor de esas cabeceras:

- `GET` devuelve las solicitudes **consumidas**, no las restantes. El backend calcula
  `restantes = limite - consumidas`.
- `TTL` devuelve lo que le queda de vida a la clave, que **no coincide** con el momento en que se
  reinicia la cuota. La cuota se reinicia al cambiar de minuto, mientras que el TTL vence 60 segundos
  después de la primera solicitud de la ventana. Sólo coinciden si esa primera solicitud cae justo en
  el límite del minuto. El backend debe derivar el reinicio del próximo cambio de minuto, o bien
  alinear la expiración a ese borde en lugar de usar 60 segundos fijos.
