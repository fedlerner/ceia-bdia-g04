# Estructura PostgreSQL

[`01_schema.sql`](01_schema.sql) implementa el modelo relacional principal:

- catálogo, marcas, categorías, productos y SKU;
- precios con vigencia e historial;
- inventario obligatorio 1:1 por SKU, aprovisionado automáticamente, y movimientos auditables;
- clientes y registro mínimo de sesiones;
- pedidos e ítems;
- reseñas y recomendaciones persistentes.

Los eventos de navegación no se duplican en PostgreSQL: su fuente canónica es
MongoDB. Redis conserva únicamente estado temporal y caché.

`product_code`, `customer_code`, `session_code`, `order_code` y `sku_code` son identificadores
externos estables. Las claves numéricas y UUID son internas de PostgreSQL.

Los permisos de acceso no se definen en este archivo: se aplican después de crear
todos los objetos mediante
[`../seguridad/01_roles_permisos.sql`](../seguridad/01_roles_permisos.sql).

La clave primaria `inventory.sku_id` impide más de una fila por SKU. El trigger
`sku_create_inventory_trg` crea la fila al insertar el SKU y la restricción diferible
`inventory_required_for_sku_ctrg` impide eliminarla o reasignarla mientras el SKU exista.
