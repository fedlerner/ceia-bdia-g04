# 03. Rankings precalculados

Los comandos de este archivo se ejecutan en la consola de Redis o en el Workbench de RedisInsight, en
el orden en que aparecen. Los bloques **modifican el ranking**: el comando 2 sube el score de
`product-006` de 590 a 690, de modo que el comando 3, ejecutado a continuación, cuenta seis productos
por encima de 600 y no los cinco de la carga inicial. Para reproducir los valores del estado inicial
hay que recargarlo con `scripts/reiniciar_datos.sh`.

Esta estructura materializa en Redis el resultado de una agregación costosa. La consulta "productos
más visualizados" del modelo documental recorre la colección `user_events` completa, y ejecutarla en
cada visita a la página principal no resulta viable. El ranking se calcula una vez y se sirve desde
memoria.

## Comando 1. Consultar el ranking

**Pregunta de negocio:** ¿cuáles son los productos más vistos de los últimos siete días?

**Objetivo:** obtener el top de la página principal sin ejecutar la agregación sobre MongoDB.

```redis
ZREVRANGE ranking:productos:vistos:7d 0 4 WITHSCORES
```

**Resultado esperado:** los cinco productos con mayor cantidad de visualizaciones, encabezados por
`product-001` con 1240, junto a sus valores.

**Justificación:** el tipo Sorted Set mantiene sus miembros permanentemente ordenados por un score
numérico, de manera que el orden es una propiedad de la estructura y no un trabajo que deba hacerse
en el momento de la consulta. Recuperar el top N cuesta O(log n + m), donde m es la cantidad de
elementos devueltos.

El equivalente relacional sería `ORDER BY vistas DESC LIMIT 5`. Conviene ser preciso sobre esa
comparación: **con un índice B-tree sobre `vistas`, PostgreSQL no ordena nada**. Resuelve la consulta
con un `Index Scan Backward` que se detiene a la quinta fila. Sobre una tabla de 200 000 filas, el
plan medido es:

```text
Limit (actual time=0.037..0.055 rows=5 loops=1)
  ->  Index Scan Backward using idx_vistas on ranking (actual time=0.036..0.054 rows=5 loops=1)
Execution Time: 0.070 ms
```

Sin ese índice, en cambio, sí recorre y ordena: `Parallel Seq Scan` sobre 200 000 filas más un
`top-N heapsort`, con 13,4 ms de ejecución.

La ventaja del Sorted Set frente a un índice adecuado no es evitar el ordenamiento, porque ambos lo
evitan. Es otra: el score y el orden viven en la misma estructura, de modo que no hay una tabla y un
índice que mantener por separado; la actualización con `ZINCRBY` reubica el elemento en O(log n) sin
escribir en disco; y el dato reside en memoria. Para un ranking que se recalcula continuamente y se
consulta en cada visita, eso es lo que inclina la elección.

## Comando 2. Actualizar el ranking de forma incremental

**Pregunta de negocio:** ¿cómo se refleja una nueva visualización sin recalcular toda la agregación?

**Objetivo:** modificar el score de un producto y verificar que el orden se ajusta solo.

```redis
ZSCORE ranking:productos:vistos:7d product-006
ZINCRBY ranking:productos:vistos:7d 100 product-006
ZREVRANK ranking:productos:vistos:7d product-006
ZREVRANGE ranking:productos:vistos:7d 0 4 WITHSCORES
```

**Resultado esperado:** `product-006` pasa de 590 a 690 puntos, `ZREVRANK` devuelve `4` en lugar de
`5` y el producto aparece ahora dentro del top cinco.

**Justificación:** `ZINCRBY` suma al score de forma atómica y reubica el elemento como parte de la
misma escritura. Esto permite mantener el ranking evento a evento, sin volver a consultar MongoDB.

Conviene repetir la prueba con un incremento menor. Para que los números sean reproducibles hay que
volver al estado inicial primero, porque el `ZINCRBY` anterior ya dejó el score en 690:

```redis
ZADD ranking:productos:vistos:7d 590 product-006
ZINCRBY ranking:productos:vistos:7d 25 product-006
ZREVRANK ranking:productos:vistos:7d product-006
```

El score pasa de 590 a 615 y `ZREVRANK` sigue devolviendo `5`: la posición no cambia, porque 615
sigue por debajo de los 640 de `product-005`. El orden depende del score acumulado y no de la
cantidad de escrituras recibidas.

## Comando 3. Filtrar por umbral de visualizaciones

**Pregunta de negocio:** ¿cuántos productos superaron las 600 visualizaciones en la ventana?

**Objetivo:** consultar por rango de score en lugar de por posición.

```redis
ZCARD ranking:productos:vistos:7d
ZCOUNT ranking:productos:vistos:7d (600 +inf
ZRANGEBYSCORE ranking:productos:vistos:7d (600 +inf WITHSCORES
```

**Resultado esperado:** `ZCARD` devuelve 8, que es la cantidad de productos del catálogo inicial, y
`ZCOUNT` devuelve la cantidad que supera el umbral.

**Justificación:** `ZCOUNT` responde sin materializar la lista de resultados, lo que resulta adecuado
cuando solo interesa la cantidad. `ZRANGEBYSCORE` recupera el conjunto cuando además se necesitan los
elementos. Los literales `+inf` y `-inf` expresan un límite abierto sin necesidad de elegir un número
máximo arbitrario.

El paréntesis de `(600` no es un error de tipeo: **en Redis los límites de score son inclusivos por
defecto**, y el prefijo `(` los vuelve exclusivos. La pregunta pide los productos que *superaron* las
600 visualizaciones, de modo que `600` a secas incluiría también a uno que tuviera exactamente 600.
Con el catálogo actual ningún producto está en ese valor y el resultado coincide, pero el comando
debe expresar la pregunta que dice responder.

## Comando 4. Reconstruir el ranking

**Pregunta de negocio:** ¿cómo se refresca el ranking cuando el proceso periódico recalcula la
agregación?

**Objetivo:** reemplazar el contenido completo de la estructura y volver a fijarle su vida útil.

```redis
MULTI
DEL ranking:productos:vistos:7d
ZADD ranking:productos:vistos:7d 1240 product-001 980 product-002 870 product-003 815 product-004 640 product-005 590 product-006 410 product-007 250 product-008
EXPIRE ranking:productos:vistos:7d 3600
EXEC
ZCARD ranking:productos:vistos:7d
TTL ranking:productos:vistos:7d
```

**Resultado esperado:** los tres comandos encolados responden `QUEUED`, `EXEC` devuelve la lista de
sus tres resultados, `ZCARD` devuelve 8 y `TTL` un valor cercano a 3600.

**Justificación:** el `DEL` previo es necesario. Sin él, los productos que dejaron de figurar en el
resultado de la agregación conservarían su score anterior y el ranking acumularía datos obsoletos
entre recálculos.

Los tres comandos van dentro de una transacción por dos motivos. Sin ella, cualquier lectura que
llegue entre el `DEL` y el `ZADD` obtiene un ranking vacío, y un fallo entre el `ZADD` y el `EXPIRE`
deja el ranking reconstruido **sin TTL**, lo que contradice la garantía de que un ranking que dejó de
actualizarse no se sirva de forma indefinida. `MULTI` encola los comandos y `EXEC` los ejecuta de
corrido, sin que ningún otro cliente pueda intercalar operaciones ni observar un estado intermedio.

A diferencia de una transacción relacional, `EXEC` no ofrece rollback: si un comando encolado falla
en tiempo de ejecución, los demás igual se aplican. Lo que garantiza es el aislamiento y la ejecución
completa de la secuencia, que es lo que este caso necesita.

El TTL de una hora es más largo que los diez minutos de la cache de recomendaciones. La diferencia es
deliberada: una agregación sobre una ventana de siete días cambia mucho más lentamente que una
recomendación personalizada. Su función es garantizar que un ranking que dejó de actualizarse no se
siga sirviendo de forma indefinida.

La ventana temporal forma parte de la clave y no del valor. Eso permite mantener `:7d`, `:30d` y
`:24h` en paralelo, cada una con su propio TTL, sin que ninguna consulta deba filtrarlas.
