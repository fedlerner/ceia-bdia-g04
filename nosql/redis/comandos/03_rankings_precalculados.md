# 03. Rankings precalculados

Los comandos de este archivo se ejecutan en la consola de Redis o en el Workbench de RedisInsight.

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

El equivalente relacional sería `ORDER BY vistas DESC LIMIT 5`, que exige recorrer y ordenar filas
aunque exista un índice sobre la columna.

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

Conviene repetir la prueba con un incremento menor, por ejemplo 25 en lugar de 100. El score sube
pero la posición no cambia, porque 615 sigue por debajo de los 640 de `product-005`. El orden depende
del score acumulado y no de la cantidad de escrituras recibidas.

## Comando 3. Filtrar por umbral de visualizaciones

**Pregunta de negocio:** ¿cuántos productos superaron las 600 visualizaciones en la ventana?

**Objetivo:** consultar por rango de score en lugar de por posición.

```redis
ZCARD ranking:productos:vistos:7d
ZCOUNT ranking:productos:vistos:7d 600 +inf
ZRANGEBYSCORE ranking:productos:vistos:7d 600 +inf WITHSCORES
```

**Resultado esperado:** `ZCARD` devuelve 8, que es la cantidad de productos del catálogo inicial, y
`ZCOUNT` devuelve la cantidad que supera el umbral.

**Justificación:** `ZCOUNT` responde sin materializar la lista de resultados, lo que resulta adecuado
cuando solo interesa la cantidad. `ZRANGEBYSCORE` recupera el conjunto cuando además se necesitan los
elementos. Los literales `+inf` y `-inf` expresan un límite abierto sin necesidad de elegir un número
máximo arbitrario.

## Comando 4. Reconstruir el ranking

**Pregunta de negocio:** ¿cómo se refresca el ranking cuando el proceso periódico recalcula la
agregación?

**Objetivo:** reemplazar el contenido completo de la estructura y volver a fijarle su vida útil.

```redis
DEL ranking:productos:vistos:7d
ZADD ranking:productos:vistos:7d 1240 product-001 980 product-002 870 product-003 815 product-004 640 product-005 590 product-006 410 product-007 250 product-008
EXPIRE ranking:productos:vistos:7d 3600
ZCARD ranking:productos:vistos:7d
TTL ranking:productos:vistos:7d
```

**Resultado esperado:** `ZCARD` devuelve 8 y `TTL` devuelve un valor cercano a 3600.

**Justificación:** el `DEL` previo es necesario. Sin él, los productos que dejaron de figurar en el
resultado de la agregación conservarían su score anterior y el ranking acumularía datos obsoletos
entre recálculos.

El TTL de una hora es más largo que los diez minutos de la cache de recomendaciones. La diferencia es
deliberada: una agregación sobre una ventana de siete días cambia mucho más lentamente que una
recomendación personalizada. Su función es garantizar que un ranking que dejó de actualizarse no se
siga sirviendo de forma indefinida.

La ventana temporal forma parte de la clave y no del valor. Eso permite mantener `:7d`, `:30d` y
`:24h` en paralelo, cada una con su propio TTL, sin que ninguna consulta deba filtrarlas.
