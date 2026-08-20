# Consultas representativas — Punto 8

Las siguientes consultas son una propuesta lógica preliminar. **Los nombres definitivos de tablas y
columnas deberán ajustarse durante la construcción del modelo lógico y físico.** En conjunto, cubren
consultas operativas, analíticas y de personalización, y muestran relaciones, filtros, agregaciones,
subconsultas y decisiones de indexación o de vistas.

| Archivo | Pregunta de negocio |
| --- | --- |
| [`01_catalogo_activo_disponibilidad.sql`](01_catalogo_activo_disponibilidad.sql) | ¿Qué productos activos están disponibles, indicando marca, precio y stock? |
| [`02_ventas_ingresos_por_categoria.sql`](02_ventas_ingresos_por_categoria.sql) | ¿Qué categorías generan más unidades vendidas e ingresos durante un período determinado? |
| [`03_productos_vistos_no_comprados.sql`](03_productos_vistos_no_comprados.sql) | ¿Qué productos visitó recientemente un cliente y todavía no compró? |
| [`04_stock_bajo.sql`](04_stock_bajo.sql) | ¿Qué productos requieren reposición o deberían excluirse temporalmente de las recomendaciones? |
| [`05_productos_comprados_conjuntamente.sql`](05_productos_comprados_conjuntamente.sql) | ¿Qué productos suelen comprarse junto con un producto determinado? |

Las consultas sobre MongoDB (historial reciente, productos más interactuados, eventos de una sesión y
productos más visualizados) están en [`../../nosql/modelo_nosql.md`](../../nosql/modelo_nosql.md).

## Cobertura de los requisitos del punto 8

| Requisito | Consultas que lo cubren |
| --- | --- |
| Selección y filtrado | 1, 3 y 4 |
| Relaciones entre entidades | Todas |
| Agregaciones | 1, 2 y 5 |
| Indicadores comerciales | 2 y 4 |
| Personalización | 3 y 5 |
| Subconsulta o CTE | 3, 4 y 5 |
| Justificación de índices o vistas | 1, 3 y 4 |
| Apoyo a decisiones | 2, 4 y 5 |

## Pendiente

- [ ] Ajustar nombres de tablas y columnas contra el modelo físico definitivo.
- [ ] Verificar la ejecución de cada consulta sobre los datos de ejemplo cargados.
- [ ] Decidir si la consulta 3 se resuelve sobre PostgreSQL o sobre MongoDB, dado que el modelado
      NoSQL ubica los eventos en MongoDB.
