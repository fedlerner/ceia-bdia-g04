# Validación empírica de PostgreSQL

## Resultado

La implementación mínima de PostgreSQL fue ejecutada inicialmente el **25/08/2026** mediante Docker
Compose y PostgreSQL 16 (`postgres:16-alpine`). El contenedor quedó en estado `Up (healthy)` y los
14 controles originales devolvieron `OK`.

Después de la revisión de la PR, el procedimiento se amplió a 20 controles de estado, 9 pruebas
negativas de integridad y 1 prueba de concurrencia. La ejecución limpia se repitió correctamente el
**25/08/2026** y finalizó con:

```text
VALIDACIÓN COMPLETA: 5 consultas, 20 controles de estado,
9 controles de integridad y 1 control de concurrencia OK.
```

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

## Controles incluidos

Se verificaron productos, SKU, clientes, categorías principales, precios vigentes, inventario,
movimientos de stock, totales de pedidos, pedidos completados, recomendaciones, vista de catálogo,
códigos externos canónicos y atributos de las variantes. La ampliación agrega:

- signos válidos para cada tipo de movimiento de inventario;
- consistencia entre cliente y sesión de una recomendación;
- recomendación generada dentro del período de su sesión;
- línea temporal canónica de `session-456`;
- rechazo de cuatro operaciones inválidas;
- conservación del total ante dos inserciones concurrentes.

Los datos sintéticos esperados son 8 productos, 10 SKU, 5 clientes, 5 sesiones, 5 pedidos, 10 ítems,
2 recomendaciones y 4 ítems de recomendación. La prueba concurrente crea un pedido temporal y lo
elimina al finalizar.
