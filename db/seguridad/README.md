# Seguridad y permisos de PostgreSQL

[`01_roles_permisos.sql`](01_roles_permisos.sql) separa la administración de
la operación normal:

- `POSTGRES_USER` es propietario y se reserva para migraciones, carga inicial y
  validación;
- `bdia_app` es un rol `NOLOGIN` para el backend, con escritura limitada por
  tabla y por columna;
- `bdia_analyst` es un rol `NOLOGIN` de solo lectura comercial, sin acceso
  directo a `customer`, `customer_session` ni `review`.

`inventory.available_qty` y `sales_order.total_amount` no son escribibles por
`bdia_app`. El primero cambia únicamente al insertar un movimiento; el segundo,
al modificar los ítems. Las dos actualizaciones internas se ejecutan mediante
funciones `SECURITY DEFINER` con un `search_path` fijo.

Los roles son deliberadamente `NOLOGIN`: el repositorio no distribuye
credenciales de aplicación. En un despliegue real se crea un usuario de login
con una contraseña administrada fuera de Git y se le concede el rol necesario.
