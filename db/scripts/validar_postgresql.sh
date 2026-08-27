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

echo "1/7 Validando la configuración de Docker Compose..."
docker compose config --quiet

echo "2/7 Eliminando solamente el entorno PostgreSQL de esta práctica..."
docker compose down -v --remove-orphans

echo "3/7 Construyendo una instancia limpia de PostgreSQL 16..."
docker compose up -d --wait

echo "4/7 Ejecutando nuevamente las cinco consultas..."
for consulta in consultas/*.sql; do
    echo "  - $consulta"
    docker compose exec -T postgres \
        psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        < "$consulta" >/dev/null
done

echo "5/7 Ejecutando los veinte controles de estado..."
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
if [ "$controles_ok" -ne 20 ]; then
    echo "ERROR: se esperaban 20 controles OK y se detectaron $controles_ok." >&2
    exit 1
fi

echo "6/7 Comprobando que PostgreSQL rechace operaciones inválidas..."
resultado_integridad="$({
    docker compose exec -T postgres \
        psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        < validacion/02_integrity_tests.sql
} 2>&1)"
printf '%s\n' "$resultado_integridad"

controles_integridad_ok="$(printf '%s\n' "$resultado_integridad" | grep -c '| OK' || true)"
if [ "$controles_integridad_ok" -ne 9 ]; then
    echo "ERROR: se esperaban 9 controles de integridad OK y se detectaron $controles_integridad_ok." >&2
    exit 1
fi

echo "7/7 Comprobando dos inserciones concurrentes sobre el mismo pedido..."
bash scripts/validar_concurrencia_totales.sh

trap - EXIT
echo ""
echo "VALIDACIÓN COMPLETA: 5 consultas, 20 controles de estado,"
echo "9 controles de integridad y 1 control de concurrencia OK."
echo "PostgreSQL permanece levantado para revisión manual."
