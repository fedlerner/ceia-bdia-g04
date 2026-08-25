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
GET contador:reco:generadas
INCR contador:reco:generadas
INCRBY contador:reco:cache_hit 5
MGET contador:reco:generadas contador:reco:cache_hit
```

**Resultado esperado:** `INCR` devuelve el nuevo valor del contador y `MGET` devuelve ambos
acumulados en una sola respuesta.

**Justificación:** `INCR` interpreta el String como entero y lo incrementa de forma atómica. Si la
clave no existe, la inicializa en cero antes de incrementar, y ese comportamiento es el que permite
escribir el rate limit del comando siguiente sin comprobar previamente si la ventana ya existía.

En un motor relacional, un `UPDATE contadores SET valor = valor + 1` requiere una fila, un bloqueo y
una transacción. Acá el contador es la clave, y el costo de la operación es O(1).

Estos contadores no tienen expiración, a diferencia del resto de las estructuras de la capa: un
acumulado operativo pierde su sentido si se reinicia solo.

## Comando 2. Rate limit por ventana fija

**Pregunta de negocio:** ¿cuántas solicitudes de recomendaciones lleva hechas este cliente en el
minuto actual?

**Objetivo:** contar las solicitudes de una ventana temporal que se descarta sola al vencer.

```redis
INCR ratelimit:reco:user-123:2026081915
EXPIRE ratelimit:reco:user-123:2026081915 60 NX
TTL ratelimit:reco:user-123:2026081915
```

Conviene repetir las tres líneas varias veces seguidas.

**Resultado esperado:** el valor de `INCR` crece en cada repetición mientras el `TTL` decrece.
`EXPIRE` devuelve `1` en la primera ejecución y `0` en las siguientes.

**Justificación:** la opción `NX` de `EXPIRE` aplica el TTL únicamente si la clave todavía no tiene
uno. Es el detalle que hace correcto al patrón: sin `NX`, cada solicitud extendería la ventana y el
límite no se alcanzaría nunca.

El identificador de la ventana forma parte de la clave y lo calcula la aplicación a partir del reloj,
con el formato `AAAAMMDDHHmm`. Para Redis se trata simplemente de otra clave distinta, de modo que
cada minuto obtiene su propio contador y no hace falta borrar el anterior.

Resolver esto en PostgreSQL exigiría una tabla de solicitudes con su marca temporal, un `COUNT(*)`
con filtro por fecha en cada solicitud y un proceso de purga. Acá son dos operaciones O(1) y la purga
es automática.

## Comando 3. Verificar el comportamiento en el límite

**Pregunta de negocio:** ¿qué estado observa la aplicación cuando un cliente agota su cuota?

**Objetivo:** llegar al límite sin ejecutar treinta comandos.

```redis
DEL ratelimit:reco:user-demo:ventana-prueba
INCRBY ratelimit:reco:user-demo:ventana-prueba 30
EXPIRE ratelimit:reco:user-demo:ventana-prueba 60 NX
GET ratelimit:reco:user-demo:ventana-prueba
INCR ratelimit:reco:user-demo:ventana-prueba
```

**Resultado esperado:** el último `INCR` devuelve 31.

**Justificación:** Redis no rechaza nada por sí mismo. Devuelve 31 y la decisión de rechazar la
solicitud corresponde a la aplicación, que compara ese valor contra el límite configurado. Redis
aporta el contador atómico y la expiración; la política es responsabilidad del backend.

El límite de 30 solicitudes por minuto es un valor de ejemplo. Definir el número que corresponde al
caso queda pendiente, según la sección 2.10 del modelo.

Las claves `ratelimit:*` que crea esta comprobación vencen solas en 60 segundos y no requieren
limpieza manual.

## Comando 4. Consultar la cuota sin consumirla

**Pregunta de negocio:** ¿cuántas solicitudes le quedan al cliente y cuándo se reinicia su ventana?

**Objetivo:** obtener el estado de la cuota sin producir efectos sobre ella.

```redis
GET ratelimit:reco:user-demo:ventana-prueba
TTL ratelimit:reco:user-demo:ventana-prueba
```

**Resultado esperado:** el valor actual del contador y los segundos que faltan para que la ventana se
reinicie.

**Justificación:** son las dos mitades de la información que un backend devolvería al cliente en las
cabeceras `X-RateLimit-Remaining` y `X-RateLimit-Reset`. A diferencia de `INCR`, ninguno de los dos
comandos modifica el estado, de modo que consultar la cuota no consume cuota.
