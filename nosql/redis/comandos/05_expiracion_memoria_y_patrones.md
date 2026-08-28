# 05. Expiración, memoria y patrones de búsqueda

Los comandos de este archivo se ejecutan en la consola de Redis o en el Workbench de RedisInsight.
Todos son de lectura y no modifican el estado, con una excepción: el comando 5 invoca
`scripts/demo_limite_memoria.sh`, que llena la base con claves de relleno y al terminar recarga el
estado inicial.

Este archivo cubre los dos aspectos que la consigna exige específicamente para una base clave-valor:
los patrones de búsqueda, en el punto 4, y las políticas de expiración, en el punto 7.

## Comando 1. Recorrer una familia de claves

**Pregunta de negocio:** ¿qué entradas existen actualmente para cada estructura del modelo?

**Objetivo:** inspeccionar el espacio de claves sin bloquear al resto de los clientes.

```redis
SCAN 0 MATCH reco:* COUNT 100
SCAN 0 MATCH session:* COUNT 100
SCAN 0 MATCH ranking:* COUNT 100
```

**Resultado esperado:** un cursor y un lote de claves por cada familia. El recorrido termina cuando
el cursor devuelto vuelve a ser `0`.

**Justificación:** Redis no dispone de índices secundarios. No es posible consultar qué
recomendaciones se generaron con una determinada `model_version`, porque el valor es opaco para el
servidor. El único criterio de acceso es la clave, y por eso el prefijo cumple en este modelo el
papel que cumple el índice en el modelo relacional.

`SCAN` recorre el espacio de claves de forma incremental y devuelve el control entre lote y lote. La
opción `MATCH` filtra por un patrón glob y `COUNT` sugiere cuántas claves examinar por iteración,
aunque se trata de una indicación y no de una garantía.

## Comando 2. El comando que no debe usarse fuera de esta consola

**Pregunta de negocio:** ¿por qué no alcanza con listar todas las claves de una vez?

**Objetivo:** contrastar `KEYS` con `SCAN` sobre el mismo patrón.

```redis
KEYS reco:*
```

**Resultado esperado:** las mismas claves que devuelve `SCAN`, en una única respuesta.

**Justificación:** `KEYS` es O(n) sobre el total de claves de la base y se ejecuta como una sola
operación. Como Redis atiende los comandos de manera secuencial, un `KEYS` sobre una base grande deja
esperando a todos los demás clientes durante toda su ejecución. Con las seis claves de esta
implementación resulta instantáneo, pero no debe utilizarse fuera de una consola de inspección.
`SCAN` cumple esa función sin ese costo.

## Comando 3. Medir el tamaño de cada estructura

**Pregunta de negocio:** ¿cuánta memoria requeriría esta capa al crecer el volumen?

**Objetivo:** obtener el costo real por clave, en lugar de estimarlo.

```redis
TYPE reco:user:user-123:home
OBJECT ENCODING reco:user:user-123:home
MEMORY USAGE reco:user:user-123:home

TYPE session:session-456
OBJECT ENCODING session:session-456
MEMORY USAGE session:session-456

TYPE ranking:productos:vistos:7d
OBJECT ENCODING ranking:productos:vistos:7d
MEMORY USAGE ranking:productos:vistos:7d
```

**Resultado esperado:** 312 bytes para la entrada de cache, 208 para la sesión y 216 para el ranking
de ocho productos, con codificaciones `raw`, `listpack` y `listpack` respectivamente.

**Justificación:** estos valores son el insumo para dimensionar la memoria de la capa. La estimación
de RAM del análisis de escalabilidad se calcula sobre mediciones y no sobre supuestos.

`OBJECT ENCODING` muestra la representación interna que eligió Redis. Los hashes y sorted sets
pequeños usan `listpack`, una codificación compacta, y pasan a `hashtable` o `skiplist` al crecer.
Esa optimización es automática y no requiere configuración.

La clave misma consume memoria: `reco:user:user-123:home` ocupa 23 bytes, y ese costo se multiplica
por la cantidad de entradas. Es la razón por la que la convención de nombres abrevia
`recommendations` como `reco`.

## Comando 4. Contrastar los tres regímenes de expiración

**Pregunta de negocio:** ¿qué significa que cada dato quede obsoleto, y cuánto debe durar?

**Objetivo:** verificar que cada estructura tiene el régimen de expiración que le corresponde.

```redis
TTL reco:user:user-123:home
TTL session:session-456
TTL ranking:productos:vistos:7d
TTL contador:{reco}:generadas
```

**Resultado esperado:** valores positivos en las tres primeras y `-1` en la última.

**Justificación:** la política de expiración no es global sino que la decidimos por estructura. La cache
usa un TTL fijo que no se renueva al leerla, porque debe envejecer para regenerarse con los eventos
nuevos. La sesión usa un TTL deslizante que se renueva con cada actividad, porque debe sobrevivir
mientras el visitante navegue. Los contadores no expiran por tiempo, aunque eso no los vuelve
durables: se pierden al reiniciar el contenedor y `allkeys-lru` puede descartarlos, de modo que son
acumulados best-effort.

Redis no ejecuta un proceso que recorra todas las claves buscando vencimientos. La eliminación es
perezosa, al intentar leer una clave vencida, y activa, mediante un ciclo de fondo que muestrea
claves con TTL. Por eso una clave vencida puede seguir ocupando memoria durante unos instantes
después de su vencimiento.

## Comando 5. Límite de memoria y descarte de claves

**Pregunta de negocio:** ¿qué ocurre cuando la capa alcanza el límite de memoria asignado?

**Objetivo:** conocer la política vigente y el margen disponible.

```redis
CONFIG GET maxmemory
CONFIG GET maxmemory-policy
INFO memory
```

**Resultado esperado:** 268435456 bytes, la política `allkeys-lru` y el consumo actual.

Para observar el descarte con evidencia medida se ejecuta, desde `nosql/redis`:

```bash
docker compose exec redis sh /scripts/demo_limite_memoria.sh
```

El script reduce `maxmemory` a 4 MB, inserta 6000 claves de relleno, informa `evicted_keys` antes y
después y comprueba si las claves del estado inicial sobrevivieron. La configuración se restaura
mediante un `trap`, tanto al terminar bien como ante una interrupción. La recarga de los datos solo
ocurre si el script llega al final; si se interrumpe, el propio script indica cómo recargarlos.

**Justificación:** con `allkeys-lru` el descarte alcanza a cualquier clave, tenga TTL o no. La
corrida del script lo confirma: la cache, la sesión y el ranking fueron descartados junto con el
relleno. De ahí una restricción del diseño: ninguna información que deba sobrevivir puede residir
únicamente en Redis. La sesión anónima es un estado temporal que resulta aceptable perder; el pedido,
el precio aplicado y el inventario residen en PostgreSQL.

Esta es la diferencia que hay que asumir al elegir Redis. PostgreSQL nunca descarta filas por presión
de memoria: descarta páginas de su cache y accede a disco. Redis no tiene disco al que recurrir.

### Políticas de memoria evaluadas

| Política | Comportamiento | Motivo del descarte |
| --- | --- | --- |
| `allkeys-lru` | Descarta las claves menos usadas recientemente entre todas. | **Elegida.** Todo el contenido de la capa es descartable: la cache, las sesiones y los rankings se reconstruyen, y aceptamos la pérdida de los contadores y de la cuota en curso. |
| `noeviction` | Rechaza las escrituras al alcanzar el límite. | Convertiría un problema de memoria en errores de escritura del backend. |
| `volatile-lru` | Descarta solo entre las claves que tienen TTL. | Las claves sin TTL quedan fuera del conjunto desalojable. Al agotarse los candidatos con TTL, Redis rechaza las escrituras con `OOM command not allowed`: el mismo fallo que `noeviction`, pero más tarde y menos predecible. |
| `allkeys-lfu` | Descarta por frecuencia de uso en lugar de por recencia. | Favorece claves populares históricas frente a recomendaciones recientes, que es lo contrario de lo que necesita la personalización. |
