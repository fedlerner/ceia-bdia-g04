# Validación empírica de PostgreSQL

## Resultado

La implementación mínima de PostgreSQL fue ejecutada el **25/08/2026** mediante Docker Compose y
PostgreSQL 16 (`postgres:16-alpine`). El contenedor quedó en estado `Up (healthy)` y los **14
controles automáticos devolvieron `OK`**.

La ejecución se realizó desde Git Bash, dentro de `db/`. En el equipo de validación el puerto externo
`5432` estaba ocupado, por lo que se utilizó:

```text
127.0.0.1:5433 -> 5432/tcp
```

El cambio se efectuó únicamente en el archivo local `db/.env`, que no se versiona. El puerto interno
de PostgreSQL continuó siendo `5432`.

## Procedimiento reproducible

Desde la raíz del repositorio:

```bash
cd db
cp .env.example .env
```

Si el puerto externo `5432` está ocupado, editar `.env` y usar, por ejemplo:

```text
POSTGRES_LISTEN_PORT=5433
```

Después ejecutar:

```bash
bash "scripts/validar_postgresql.sh" --reset
```

Para repetir solamente los controles sobre un contenedor ya levantado:

```bash
source ".env"
docker compose exec -T postgres psql -X -v ON_ERROR_STOP=1 \
  -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  < "validacion/01_validation.sql"
```

## Controles confirmados

Se verificaron productos, SKU, clientes, categorías principales, precios vigentes, inventario,
movimientos de stock, totales de pedidos, pedidos completados, recomendaciones, vista de catálogo,
códigos externos canónicos y atributos de las variantes.

La salida de la ejecución mostró **14 filas de validación con resultado `OK`** y los datos sintéticos
esperados: 8 productos, 10 SKU, 5 clientes, 5 sesiones, 5 pedidos, 10 ítems, 2 recomendaciones y
4 ítems de recomendación.
