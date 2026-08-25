# 02. Sesiones de visitantes anónimos

Los comandos de este archivo se ejecutan en la consola de Redis o en el Workbench de RedisInsight, en
el orden en que aparecen.

El modelo de datos admite eventos de clientes identificados o de sesiones anónimas. Esta estructura
sostiene el segundo caso: conserva el estado temporal de un visitante que todavía no se registró, sin
escribir nada en PostgreSQL.

## Comando 1. Recuperar el estado completo de la sesión

**Pregunta de negocio:** ¿qué se sabe del visitante actual para poder personalizar su experiencia?

**Objetivo:** obtener en una sola operación el contexto que necesita el motor de recomendaciones.

```redis
HGETALL session:session-456
```

**Resultado esperado:** los cinco campos de la sesión: `started_at`, `last_seen_at`, `events_count`,
`last_product_id` y `preferred_category`.

**Justificación:** la sesión almacena comportamiento y no identidad. No guarda dirección IP, user
agent, correo ni teléfono. Es una decisión deliberada del diseño: una sesión anónima debe permitir
personalizar durante la visita sin acumular datos personales, y el TTL funciona además como política
de retención automática.

El tipo Hash asocia una clave a un conjunto de pares campo-valor, lo que permite modelar la sesión
como un registro con campos en lugar de un documento opaco.

## Comando 2. Leer campos puntuales

**Pregunta de negocio:** ¿cuál fue el último producto que miró el visitante?

**Objetivo:** recuperar un dato individual sin traer ni deserializar el resto de la sesión.

```redis
HGET session:session-456 last_product_id
HMGET session:session-456 preferred_category events_count
```

**Resultado esperado:** `product-002` en el primer comando; `perfumes` y `7` en el segundo.

**Justificación:** esta es la ventaja concreta del Hash frente a almacenar la sesión como un String
JSON. El contexto "ficha de producto" solo necesita `last_product_id`, y con un documento JSON habría
que transferir y deserializar la sesión completa para obtenerlo. `HMGET` agrupa varios campos en una
sola ida y vuelta a la red, lo que reduce el número de viajes cuando la aplicación conoce de antemano
el subconjunto que necesita.

Equivale a proyectar columnas en lugar de ejecutar un `SELECT *`.

## Comando 3. Registrar actividad y renovar la vida útil

**Pregunta de negocio:** ¿cómo se mantiene viva la sesión mientras el visitante siga navegando?

**Objetivo:** implementar la expiración deslizante, distinta del TTL fijo de la cache.

```redis
TTL session:session-456
HINCRBY session:session-456 events_count 1
HSET session:session-456 last_seen_at 2026-08-19T15:47:00Z last_product_id product-004
EXPIRE session:session-456 1800
TTL session:session-456
```

**Resultado esperado:** el primer `TTL` devuelve el tiempo restante y el último vuelve a ser 1800.

**Justificación:** `EXPIRE` reinicia el TTL a partir del momento de la llamada, de modo que la sesión
sobrevive mientras haya actividad y desaparece sola tras 30 minutos de inactividad. Es el
comportamiento opuesto al de la cache de recomendaciones, cuyo TTL no se renueva al leerlo: la cache
debe envejecer para regenerarse con los eventos nuevos, mientras que la sesión debe persistir durante
toda la visita.

`HINCRBY` incrementa el contador de eventos de forma atómica. Redis atiende los comandos de manera
secuencial, por lo que el incremento no puede perderse aunque lleguen solicitudes concurrentes. Esto
evita la condición de carrera de leer el valor, sumarle uno y volver a escribirlo desde la
aplicación.

Resolver esto en PostgreSQL requeriría una columna `last_seen_at` y un proceso programado que
eliminara las sesiones inactivas.

## Comando 4. Comprobar el vencimiento

**Pregunta de negocio:** ¿qué ocurre efectivamente cuando una sesión queda inactiva?

**Objetivo:** observar el vencimiento real de una clave dentro del tiempo de una prueba.

```redis
HSET session:session-tmp started_at 2026-08-19T15:50:00Z events_count 1
EXPIRE session:session-tmp 5
TTL session:session-tmp
```

Transcurridos seis segundos:

```redis
EXISTS session:session-tmp
TTL session:session-tmp
```

**Resultado esperado:** `EXISTS` devuelve `0` y `TTL` devuelve `-2`.

**Justificación:** la clave se eliminó sin que ningún comando la borrara. `TTL` distingue tres
situaciones con valores distintos: un número positivo indica los segundos restantes, `-1` indica que
la clave no expira nunca y `-2` que la clave no existe. Esa diferencia es la que permite verificar en
el script de carga que cada estructura tenga el régimen de expiración que le corresponde.

El TTL de cinco segundos se usa únicamente para hacer observable en una prueba un comportamiento que
en la solución real tarda 30 minutos.

Esta comprobación deja el estado con una clave menos que la carga inicial. El script
`scripts/reiniciar_datos.sh` restaura el estado original.
