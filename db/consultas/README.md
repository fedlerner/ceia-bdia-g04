# Consultas representativas PostgreSQL

| Archivo | Pregunta de negocio |
| --- | --- |
| [`01_catalogo_activo_disponibilidad.sql`](01_catalogo_activo_disponibilidad.sql) | ¿Qué productos activos tienen precio vigente y stock? |
| [`02_ventas_ingresos_por_categoria.sql`](02_ventas_ingresos_por_categoria.sql) | ¿Qué categorías generan más ventas e ingresos? |
| [`03_clientes_frecuencia_valor.sql`](03_clientes_frecuencia_valor.sql) | ¿Qué clientes concentran mayor frecuencia y valor de compra? |
| [`04_stock_bajo.sql`](04_stock_bajo.sql) | ¿Qué SKU requieren reposición? |
| [`05_productos_comprados_conjuntamente.sql`](05_productos_comprados_conjuntamente.sql) | ¿Qué productos se compran junto con `product-001`? |
| [`06_ranking_productos_por_ingresos.sql`](06_ranking_productos_por_ingresos.sql) | ¿En qué posición queda cada producto por ingresos dentro de su moneda? |

Las consultas de productos vistos, búsquedas e interacciones se mantienen en
MongoDB. Esta separación elimina la contradicción anterior que consultaba en
PostgreSQL eventos definidos como documentales.

Los scripts no contienen parámetros externos y pueden ejecutarse directamente
sobre los datos de ejemplo.
