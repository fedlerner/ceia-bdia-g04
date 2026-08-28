# PostgreSQL

Implementación relacional del TP sobre PostgreSQL 16.

## Ejecución aislada

```bash
cd db
cp .env.example .env
docker compose up -d --wait
docker compose logs postgres
```

La primera inicialización ejecuta DDL, índices y vista, datos sintéticos, cinco
consultas, roles con privilegios mínimos y veintitrés controles de estado. Todos
los controles deben devolver `OK`; solo entonces se crea la marca que exige el
healthcheck.

La validación limpia completa puede ejecutarse desde Git Bash:

```bash
./scripts/validar_postgresql.sh --reset
```

Además de reconstruir la base, el script ejecuta cuatro controles de
comportamiento, quince pruebas de integridad y una prueba con dos inserciones
concurrentes sobre el mismo pedido.

La opción `--reset` elimina solamente el contenedor y el volumen administrados
por `db/docker-compose.yml`. No afecta Redis, MongoDB ni otros proyectos.

Para repetir solamente los veintitrés controles de estado:

```bash
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
  -U bdia_admin -d bdia_store \
  < validacion/01_validation.sql
```

Para reconstruir desde cero se debe eliminar exclusivamente el volumen de esta
práctica y volver a levantar el componente:

```bash
docker compose down -v
docker compose up -d --wait
```

El archivo `.env` no se versiona. Los valores de `.env.example` son únicamente
locales y didácticos.

## Seguridad

La matriz ejecutable de permisos está en
[`seguridad/01_roles_permisos.sql`](seguridad/01_roles_permisos.sql). El usuario
administrador local se reserva para migraciones y validación; `bdia_app` limita
las escrituras del backend y `bdia_analyst` permite lectura comercial sin acceso
directo a los datos identificatorios. Ambos son roles `NOLOGIN`, por lo que el
repositorio no distribuye credenciales de aplicación.

En particular, `bdia_app` no puede escribir `inventory.available_qty` ni
`sales_order.total_amount`: esos valores solo cambian mediante movimientos e
ítems, respectivamente.

## Fuente de verdad

PostgreSQL conserva catálogo, precios, stock, clientes, pedidos, reseñas y
recomendaciones persistentes. MongoDB conserva eventos de comportamiento y
Redis mantiene datos temporales. Los motores se conectan mediante códigos
externos documentados en [`datos/CATALOGO_CANONICO.md`](datos/CATALOGO_CANONICO.md).
