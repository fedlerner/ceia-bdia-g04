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
consultas y veinte controles de estado. Todos los controles deben devolver
`OK`.

La validación limpia completa puede ejecutarse desde Git Bash:

```bash
./scripts/validar_postgresql.sh --reset
```

Además de reconstruir la base, el script ejecuta nueve pruebas negativas de
integridad y una prueba con dos inserciones concurrentes sobre el mismo pedido.

La opción `--reset` elimina solamente el contenedor y el volumen administrados
por `db/docker-compose.yml`. No afecta Redis, MongoDB ni otros proyectos.

Para repetir solamente los veinte controles de estado:

```bash
docker compose exec -T postgres psql -U bdia_admin -d bdia_store \
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

## Fuente de verdad

PostgreSQL conserva catálogo, precios, stock, clientes, pedidos, reseñas y
recomendaciones persistentes. MongoDB conserva eventos de comportamiento y
Redis mantiene datos temporales. Los motores se conectan mediante códigos
externos documentados en [`datos/CATALOGO_CANONICO.md`](datos/CATALOGO_CANONICO.md).
