# Estructura PostgreSQL

[`01_schema.sql`](01_schema.sql) implementa el modelo relacional principal:

- catálogo, marcas, categorías, productos y SKU;
- precios con vigencia e historial;
- inventario y movimientos auditables;
- clientes y registro mínimo de sesiones;
- pedidos e ítems;
- reseñas y recomendaciones persistentes.

Los eventos de navegación no se duplican en PostgreSQL: su fuente canónica es
MongoDB. Redis conserva únicamente estado temporal y caché.

`product_code`, `customer_code`, `session_code` y `sku_code` son identificadores
externos estables. Las claves numéricas y UUID son internas de PostgreSQL.
