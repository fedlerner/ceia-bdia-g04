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
    echo "ERROR: Docker Desktop no está iniciado." >&2
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

echo "1/5 Validando la configuración de Docker Compose..."
docker compose config --quiet

echo "2/5 Eliminando solamente el entorno PostgreSQL de esta práctica..."
docker compose down -v --remove-orphans

echo "3/5 Construyendo una instancia limpia de PostgreSQL 16..."
docker compose up -d --wait

echo "4/5 Ejecutando nuevamente las cinco consultas..."
for consulta in consultas/*.sql; do
    echo "  - $consulta"
    docker compose exec -T postgres \
        psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        < "$consulta" >/dev/null
done

echo "5/5 Ejecutando los catorce controles automáticos..."
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
if [ "$controles_ok" -ne 14 ]; then
    echo "ERROR: se esperaban 14 controles OK y se detectaron $controles_ok." >&2
    exit 1
fi

trap - EXIT
echo ""
echo "VALIDACIÓN COMPLETA: 5 consultas ejecutadas y 14 controles OK."
echo "PostgreSQL permanece levantado para revisión manual."
