# PostgreSQL

Implementación relacional del TP sobre PostgreSQL 16.

## Ejecución aislada

Con la pila unificada levantada desde la raíz, el [`Makefile`](../Makefile) general expone los
targets de este componente (`make postgresql.shell`, `make postgresql.checks`, etc.), que operan
sobre el contenedor por nombre y sirven igual en cualquiera de los dos modos de arranque.

Para levantar este componente por separado:

```bash
cd db
cp .env.example .env
docker compose up -d --wait
docker compose logs postgres
```

La primera inicialización ejecuta DDL, índices y vista, datos sintéticos, cinco
consultas, roles con privilegios mínimos y veinticuatro controles de estado. Todos
los controles deben devolver `OK`; solo entonces se crea la marca que exige el
healthcheck.

La validación limpia completa puede ejecutarse desde Git Bash:

```bash
./scripts/validar_postgresql.sh --reset
```

Además de reconstruir la base, el script ejecuta cuatro controles de
comportamiento, diecisiete pruebas de integridad y una prueba con dos inserciones
concurrentes sobre el mismo pedido.

El puerto se publica únicamente en `127.0.0.1`, con el valor de
`POSTGRES_LISTEN_PORT` en `.env`, de modo que la base no queda expuesta fuera del
equipo. Las credenciales son de entorno local y no deben reutilizarse.

La opción `--reset` elimina solamente el contenedor y el volumen administrados
por `db/docker-compose.yml`. No afecta a Redis ni a MongoDB, comprobado con la
pila unificada levantada: sus contenedores y volúmenes quedan intactos. Sí
conviene tener presente que el volumen `bdia_g04_postgres_data` lleva `name:`
explícito y es el mismo que usa el arranque desde la raíz, igual que en los otros
dos componentes, así que el `--reset` descarta también los datos de esa pila.

Para repetir las verificaciones sobre un contenedor ya levantado, desde la raíz:

```bash
make postgresql.queries      # re-ejecuta las 6 consultas
make postgresql.checks       # 24 controles de estado
make postgresql.integrity    # 17 pruebas de integridad
make postgresql.concurrency  # 1 prueba de concurrencia
make postgresql.verify       # las cuatro juntas
```

Desde este directorio, sin pasar por la raíz, el mismo control se ejecuta apuntando al contenedor por
nombre. Esa forma funciona con la pila levantada de cualquiera de las dos maneras, porque no depende
del proyecto de Compose que resuelva el directorio actual:

```bash
docker exec -i bdia_g04_postgres \
  sh -c 'psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
  < validacion/01_validation.sql
```

El script `scripts/validar_postgresql.sh --reset` (validación limpia completa) no forma parte del
Makefile general porque es destructivo y gestiona el ciclo de vida del contenedor; queda disponible
como script autónomo en modo componente.

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
