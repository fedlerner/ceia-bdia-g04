# 01. Cache de recomendaciones

Los comandos de este archivo **se recorren en orden**: el comando 4 invalida la entrada que crea el
comando 2. Ejecutado por su cuenta sobre una carga limpia, ese `DEL` devuelve `0` en lugar de `1`,
porque la clave `reco:user:user-999:home` no forma parte del estado inicial.

Los comandos se ejecutan en la consola de Redis:

```bash
docker compose exec redis sh -c 'redis-cli --no-auth-warning -a "$REDIS_PASSWORD"'
```

La contraseña se toma de la variable del contenedor y no se escribe en el comando, de modo que la
instrucción sigue siendo válida si se cambia `REDIS_PASSWORD` en el `.env`.

También pueden ejecutarse desde el Workbench de RedisInsight, en <http://localhost:5540>.

Esta es la estructura central de la capa clave-valor: la que evita reejecutar el motor de
recomendaciones cuando un cliente solicita recomendaciones varias veces en un período reducido.

## Comando 1. Leer la cache

**Pregunta de negocio:** ¿hay recomendaciones vigentes para este cliente y este contexto?

**Objetivo:** resolver la solicitud sin consultar PostgreSQL ni MongoDB y sin ejecutar el motor.

```redis
GET reco:user:user-123:home
```

**Resultado esperado:** el documento JSON con `generated_at`, `model_version`, `source` y la lista
`recommendations` ordenada por `score`. Si la clave no existe o venció, devuelve `nil`.

**Justificación:** es la primera operación del patrón cache-aside y la más frecuente de toda la capa.
Su costo es O(1) y no depende del tamaño de la base. La respuesta `nil` es la condición de MISS que
dispara la ejecución del motor.

El valor se almacena como String y Redis lo trata como una secuencia de bytes opaca: no interpreta su
contenido. La serialización y deserialización quedan del lado de la aplicación. Esto es adecuado
porque el valor se consume siempre completo; no existe ninguna consulta del caso que necesite leer
solo una parte del documento.

Se conserva `model_version` dentro del valor para poder determinar qué versión del modelo produjo una
recomendación servida desde la cache, según lo exige la regla de negocio 9 del modelo conceptual.

## Comando 2. Escribir en la cache con expiración

**Pregunta de negocio:** ¿cómo se guarda el resultado del motor para que no se sirva indefinidamente?

**Objetivo:** almacenar la recomendación con una vida útil acotada, sin necesidad de un proceso de
limpieza.

```redis
SET reco:user:user-999:home '{"generated_at":"2026-08-19T16:00:00Z","model_version":"v1","source":"motor","recommendations":[{"product_id":"product-006","score":0.91}]}' EX 600
TTL reco:user:user-999:home
```

**Resultado esperado:** `SET` devuelve `OK` y `TTL` devuelve un valor cercano a 600 que decrece en
cada ejecución posterior.

**Justificación:** la opción `EX` de `SET` fija la expiración en la misma operación de escritura, de
modo que no existe la posibilidad de que una entrada quede sin TTL por un error de la aplicación. El
valor de 600 segundos se ubica dentro del rango de 5 a 15 minutos definido en el modelo.

La expiración automática es una de las razones por las que se eligió Redis para esta capa. En un
motor relacional habría que agregar una columna de vencimiento y un proceso programado que eliminara
las filas vencidas; acá el vencimiento es una propiedad de la clave.

## Comando 3. Distinguir cliente identificado de sesión anónima

**Pregunta de negocio:** ¿puede una sesión anónima recibir por error las recomendaciones de un
cliente registrado?

**Objetivo:** verificar que los dos espacios de nombres están efectivamente separados.

```redis
GET reco:sess:session-456:product
EXISTS reco:user:session-456:product
```

**Resultado esperado:** el primer comando devuelve el documento JSON de la sesión anónima; el segundo
devuelve `0`.

**Justificación:** el segundo segmento de la clave discrimina el tipo de sujeto. Sin ese
discriminador, un `session_id` y un `customer_id` con el mismo texto competirían por la misma entrada
y una sesión anónima podría resolver contra la cache de un cliente registrado. El modelo de datos
admite eventos de ambos tipos de sujeto, de manera que la separación no es hipotética.

Cumple el papel de una clave primaria compuesta que incluye el tipo de sujeto además de su
identificador.

## Comando 4. Invalidar explícitamente

**Pregunta de negocio:** ¿cómo se fuerza la regeneración de una recomendación que quedó obsoleta
antes de vencer?

**Objetivo:** eliminar una entrada vigente para que la siguiente solicitud vuelva a ejecutar el
motor.

```redis
DEL reco:user:user-999:home
GET reco:user:user-999:home
```

**Resultado esperado:** `DEL` devuelve `1` y el `GET` posterior devuelve `nil`.

**Justificación:** el TTL es la política por defecto y cubre el envejecimiento normal de la cache.
`DEL` es la vía para los eventos que no pueden esperar al vencimiento, como una compra que vuelve
obsoleta la recomendación vigente. Queda pendiente definir si la compra debe disparar esta
invalidación; ver la sección 2.10 del modelo.

A diferencia de un `DELETE` relacional, acá no hay integridad referencial ni transacción que
proteger: el dato es reconstruible desde las otras dos fuentes.

## Comando 5. Medir el comportamiento de la cache

**Pregunta de negocio:** ¿la cache está sirviendo efectivamente para lo que fue diseñada?

**Objetivo:** obtener evidencia agregada de aciertos y fallos sin instrumentar la aplicación.

```redis
INFO stats
```

**Resultado esperado:** entre otras métricas, los contadores acumulados `keyspace_hits` y
`keyspace_misses`.

**Justificación:** el cociente entre ambos es la tasa de aciertos, y es el indicador que permite
decidir si el TTL y el diseño de las claves están bien dimensionados. Una tasa baja indica que el TTL
es demasiado corto o que las claves son demasiado específicas; una tasa muy alta acompañada de datos
desactualizados indica lo contrario.

El script `scripts/demo_cache_aside.py` mide estos dos contadores junto con la latencia de cada
solicitud, de modo que la afirmación sobre el beneficio de la cache se apoya en una medición y no en
una estimación.
