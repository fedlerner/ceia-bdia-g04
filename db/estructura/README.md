# Estructura — scripts DDL (PostgreSQL)

**Pendiente de implementar.** La consigna (punto 7) pide, para una base relacional:

- [ ] scripts de creación de tablas;
- [ ] tipos de datos;
- [ ] claves primarias y foráneas;
- [ ] restricciones relevantes.

Entidades a implementar según [`../../docs/modelo_conceptual.md`](../../docs/modelo_conceptual.md):
`user`, `role`, `brand`, `category`, `product`, `product_category`, `sku`, `inventory`,
`sales_order`, `order_item`, `review`, `recommendation`, `recommendation_item`.

Restricciones derivadas de las reglas de negocio a contemplar en el DDL:

- `sku_code` único;
- precio y stock no negativos;
- cantidad de ítem de pedido mayor que cero;
- calificación de reseña dentro del rango 1 a 5;
- todo evento con fecha y hora y con cliente **o** sesión.
