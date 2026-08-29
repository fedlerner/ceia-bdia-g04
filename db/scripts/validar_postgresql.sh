#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
db_dir="$(cd "$script_dir/.." && pwd)"
cd "$db_dir"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: Docker no está instalado o no está disponible en PATH." >&2
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: No se pudo acceder al daemon de Docker. Verificá que Docker esté iniciado y que tu usuario tenga permisos." >&2
    exit 1
fi

if [ ! -f .env ]; then
    cp .env.example .env
    echo "Se creó db/.env a partir de db/.env.example."
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

: "${POSTGRES_DB:?Falta POSTGRES_DB en db/.env}"
: "${POSTGRES_USER:?Falta POSTGRES_USER en db/.env}"
: "${POSTGRES_PASSWORD:?Falta POSTGRES_PASSWORD en db/.env}"
: "${POSTGRES_LISTEN_PORT:?Falta POSTGRES_LISTEN_PORT en db/.env}"
: "${TZ:?Falta TZ en db/.env}"

if [ "${1:-}" != "--reset" ]; then
    echo "Uso: ./scripts/validar_postgresql.sh --reset" >&2
    echo "" >&2
    echo "--reset elimina únicamente los contenedores y el volumen de datos" >&2
    echo "de este componente PostgreSQL para comprobar una inicialización limpia." >&2
    exit 2
fi

mostrar_logs_si_falla() {
    estado=$?
    if [ "$estado" -ne 0 ]; then
        echo "" >&2
        echo "La validación falló. Últimas líneas del log de PostgreSQL:" >&2
        docker compose logs --tail=120 postgres >&2 || true
    fi
    exit "$estado"
}
trap mostrar_logs_si_falla EXIT

echo "1/10 Validando la configuración de Docker Compose..."
docker compose config --quiet

echo "2/10 Eliminando solamente el entorno PostgreSQL de esta práctica..."
docker compose down -v --remove-orphans

echo "3/10 Construyendo una instancia limpia de PostgreSQL 16..."
docker compose up -d --wait

echo "4/10 Ejecutando nuevamente las cinco consultas..."
for consulta in consultas/*.sql; do
    echo "  - $consulta"
    docker compose exec -T postgres \
        psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        < "$consulta" >/dev/null
done

echo "5/10 Comprobando filtros de marca y precio en las consultas operativas..."

resultado_stock_base="$({
    printf '%s\n' '\i /docker-entrypoint-initdb.d/04_04_stock.sql'
} | docker compose exec -T postgres \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB")"

if ! printf '%s\n' "$resultado_stock_base" | grep -Fq '|AUR-LUM-100|'; then
    echo "ERROR: la consulta de stock bajo no devolvió el SKU de control AUR-LUM-100." >&2
    exit 1
fi

resultado_stock_marca_inactiva="$({
    printf '%s\n' 'BEGIN;'
    printf '%s\n' "UPDATE bdia.brand SET active = FALSE WHERE name = 'Aurelia';"
    printf '%s\n' '\i /docker-entrypoint-initdb.d/04_04_stock.sql'
    printf '%s\n' 'ROLLBACK;'
} | docker compose exec -T postgres \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB")"

if printf '%s\n' "$resultado_stock_marca_inactiva" | grep -Fq '|AUR-LUM-100|'; then
    echo "ERROR: la consulta de stock bajo incluyó un SKU de una marca inactiva." >&2
    exit 1
fi
echo "  - Stock bajo excluye marcas inactivas | OK"

resultado_compra_conjunta_base="$({
    printf '%s\n' '\i /docker-entrypoint-initdb.d/04_05_compra_conjunta.sql'
} | docker compose exec -T postgres \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB")"

if ! printf '%s\n' "$resultado_compra_conjunta_base" | grep -Fq 'product-003|' \
   || ! printf '%s\n' "$resultado_compra_conjunta_base" | grep -Fq 'product-005|'; then
    echo "ERROR: la consulta de compra conjunta no devolvió los productos de control." >&2
    exit 1
fi

resultado_compra_conjunta_no_vendible="$({
    printf '%s\n' 'BEGIN;'
    printf '%s\n' "UPDATE bdia.brand SET active = FALSE WHERE name = 'Dermabelle';"
    printf '%s\n' "UPDATE bdia.sku_price sp SET valid_to = CURRENT_TIMESTAMP - INTERVAL '1 second' FROM bdia.sku s WHERE s.sku_id = sp.sku_id AND s.sku_code = 'CHR-LAB-CAR' AND sp.valid_from <= CURRENT_TIMESTAMP AND (sp.valid_to IS NULL OR sp.valid_to > CURRENT_TIMESTAMP);"
    printf '%s\n' '\i /docker-entrypoint-initdb.d/04_05_compra_conjunta.sql'
    printf '%s\n' 'ROLLBACK;'
} | docker compose exec -T postgres \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB")"

if printf '%s\n' "$resultado_compra_conjunta_no_vendible" | grep -Fq 'product-003|' \
   || printf '%s\n' "$resultado_compra_conjunta_no_vendible" | grep -Fq 'product-005|'; then
    echo "ERROR: la compra conjunta incluyó un producto fuera del catálogo vendible." >&2
    exit 1
fi
echo "  - Compra conjunta exige marca activa y precio vigente | OK"

echo "6/10 Ejecutando los veinticuatro controles de estado..."
resultado="$({
    docker compose exec -T postgres \
        psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        < validacion/01_validation.sql
} 2>&1)"
printf '%s\n' "$resultado"

if printf '%s\n' "$resultado" | grep -q '| ERROR'; then
    echo "ERROR: al menos un control devolvió ERROR." >&2
    exit 1
fi

controles_ok="$(printf '%s\n' "$resultado" | grep -c '| OK' || true)"
if [ "$controles_ok" -ne 24 ]; then
    echo "ERROR: se esperaban 24 controles OK y se detectaron $controles_ok." >&2
    exit 1
fi

echo "7/10 Comprobando que un control fallido termine con código de error..."
set +e
resultado_fallo_esperado="$({
    printf '%s\n' 'BEGIN;'
    printf '%s\n' 'UPDATE bdia.inventory SET available_qty = available_qty + 1;'
    printf '%s\n' '\i /docker-entrypoint-initdb.d/06_validation.sql'
    printf '%s\n' 'ROLLBACK;'
} | docker compose exec -T postgres \
    psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" 2>&1)"
estado_fallo_esperado=$?
set -e

if [ "$estado_fallo_esperado" -eq 0 ]; then
    echo "ERROR: una validación con stock inconsistente finalizó exitosamente." >&2
    exit 1
fi

if ! printf '%s\n' "$resultado_fallo_esperado" \
    | grep -Fq 'Falló al menos un control de estado de PostgreSQL'; then
    echo "ERROR: la validación falló por un motivo distinto del control provocado." >&2
    printf '%s\n' "$resultado_fallo_esperado" >&2
    exit 1
fi
echo "  - Una invariante falsa hace fallar psql | OK"

echo "8/10 Comprobando que el healthcheck exija la validación completa..."
docker compose exec -T postgres \
    psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    -c "DELETE FROM bdia.deployment_validation WHERE validation_name = 'initialization';"

# El healthcheck tiene 12 reintentos cada 5 segundos; después de quitar la
# marca puede necesitar hasta 60 segundos para cambiar de healthy a unhealthy.
estado_health=""
for _ in {1..40}; do
    estado_health="$(docker inspect --format '{{.State.Health.Status}}' bdia_g04_postgres)"
    [ "$estado_health" = "unhealthy" ] && break
    sleep 2
done

if [ "$estado_health" != "unhealthy" ]; then
    echo "ERROR: el contenedor siguió healthy sin la marca de validación." >&2
    exit 1
fi

docker compose exec -T postgres \
    psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    < validacion/01_validation.sql >/dev/null

for _ in {1..40}; do
    estado_health="$(docker inspect --format '{{.State.Health.Status}}' bdia_g04_postgres)"
    [ "$estado_health" = "healthy" ] && break
    sleep 2
done

if [ "$estado_health" != "healthy" ]; then
    echo "ERROR: el contenedor no recuperó el estado healthy tras validar." >&2
    exit 1
fi
echo "  - El healthcheck depende de la validación completa | OK"

echo "9/10 Comprobando que PostgreSQL rechace operaciones inválidas..."
resultado_integridad="$({
    docker compose exec -T postgres \
        psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        < validacion/02_integrity_tests.sql
} 2>&1)"
printf '%s\n' "$resultado_integridad"

controles_integridad_ok="$(printf '%s\n' "$resultado_integridad" | grep -c '| OK' || true)"
if [ "$controles_integridad_ok" -ne 17 ]; then
    echo "ERROR: se esperaban 17 controles de integridad OK y se detectaron $controles_integridad_ok." >&2
    exit 1
fi

echo "10/10 Comprobando dos inserciones concurrentes sobre el mismo pedido..."
bash scripts/validar_concurrencia_totales.sh

trap - EXIT
echo ""
echo "VALIDACIÓN COMPLETA: 5 consultas, 24 controles de estado,"
echo "4 controles de comportamiento, 17 controles de integridad"
echo "y 1 control de concurrencia OK."
echo "PostgreSQL permanece levantado para revisión manual."
