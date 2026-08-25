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
MULTI
HINCRBY session:session-456 events_count 1
HSET session:session-456 last_seen_at 2026-08-19T15:47:00Z last_product_id product-004
EXPIRE session:session-456 1800
EXEC
TTL session:session-456
```

**Resultado esperado:** el primer `TTL` devuelve el tiempo restante, los tres comandos encolados
responden `QUEUED`, `EXEC` devuelve sus tres resultados y el último `TTL` vuelve a ser 1800.

**Justificación:** `EXPIRE` reinicia el TTL a partir del momento de la llamada, de modo que la sesión
sobrevive mientras haya actividad y desaparece sola tras 30 minutos de inactividad. Es el
comportamiento opuesto al de la cache de recomendaciones, cuyo TTL no se renueva al leerlo: la cache
debe envejecer para regenerarse con los eventos nuevos, mientras que la sesión debe persistir durante
toda la visita.

`HINCRBY` incrementa el contador de eventos de forma atómica. Redis atiende los comandos de manera
secuencial, por lo que el incremento no puede perderse aunque lleguen solicitudes concurrentes. Esto
evita la condición de carrera de leer el valor, sumarle uno y volver a escribirlo desde la
aplicación.

Las tres escrituras van dentro de una transacción por el mismo motivo que el rate limit del
archivo 04. `HINCRBY` sobre un hash inexistente **lo crea**: si la sesión venció o fue descartada
justo antes, ese comando la revive, y una caída de la aplicación antes del `EXPIRE` dejaría una
sesión incompleta y sin TTL, es decir permanente. `MULTI` y `EXEC` garantizan que las tres
escrituras se apliquen juntas.

Queda una limitación que la transacción no cubre: si la sesión ya venció, `EXEC` la recrea igual, con
los campos de estos comandos y sin los originales. Impedir esa resurrección requeriría comprobar la
existencia de la clave y escribir en la misma operación, lo que en Redis se resuelve con un script
Lua. Para el alcance de este trabajo alcanza con la transacción: el efecto es una sesión nueva con el
contexto reciente, no una clave permanente.

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

Al vencer, `session:session-tmp` desaparece y la base vuelve a tener las seis claves de la carga
inicial: esta comprobación no deja claves de más ni de menos. Lo que sí quedó modificado es
`session:session-456`, porque el comando anterior le incrementó `events_count`, le cambió
`last_seen_at` y `last_product_id` y le renovó el TTL. Para volver a los valores originales,
`scripts/reiniciar_datos.sh` recarga el estado inicial.
