#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
db_dir="$(cd "$script_dir/.." && pwd)"
cd "$db_dir"

if [ ! -f .env ]; then
    echo "ERROR: falta db/.env. Copiarlo desde db/.env.example." >&2
    exit 1
fi

set -a
# shellcheck disable=SC1091
. ./.env
set +a

psql_base=(
    docker compose exec -T postgres
    psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"
)

test_order_id=""
first_log="$(mktemp)"
second_log="$(mktemp)"

cleanup() {
    status=$?

    if [ -n "$test_order_id" ]; then
        "${psql_base[@]}" -q -v test_order_id="$test_order_id" <<'SQL' >/dev/null 2>&1 || true
SET search_path TO bdia, public;
DELETE FROM order_item WHERE order_id = :'test_order_id'::BIGINT;
DELETE FROM sales_order WHERE order_id = :'test_order_id'::BIGINT;
SQL
    fi

    rm -f "$first_log" "$second_log"
    exit "$status"
}
trap cleanup EXIT

test_order_id="$("${psql_base[@]}" -qAt <<'SQL'
SET search_path TO bdia, public;
WITH new_order AS (
    INSERT INTO sales_order
        (order_code, customer_id, order_status, payment_status, shipping_status, currency)
    SELECT 'order-' || (EXTRACT(EPOCH FROM clock_timestamp()) * 1000000)::BIGINT,
           customer_id, 'pending', 'pending', 'pending', 'ARS'
    FROM customer
    WHERE customer_code = 'user-127'
    RETURNING order_id
)
SELECT order_id FROM new_order;
SQL
)"

if ! [[ "$test_order_id" =~ ^[0-9]+$ ]]; then
    echo "ERROR: no se pudo crear el pedido temporal para la prueba concurrente." >&2
    exit 1
fi

"${psql_base[@]}" -q -v test_order_id="$test_order_id" <<'SQL' >"$first_log" 2>&1 &
SET search_path TO bdia, public;
BEGIN;
INSERT INTO order_item (order_id, sku_id, quantity, unit_price_applied)
SELECT :'test_order_id'::BIGINT, sku_id, 1, 95000
FROM sku
WHERE sku_code = 'AUR-LUM-050';
SELECT pg_sleep(2);
COMMIT;
SQL
first_pid=$!

sleep 0.25

"${psql_base[@]}" -q -v test_order_id="$test_order_id" <<'SQL' >"$second_log" 2>&1 &
SET search_path TO bdia, public;
BEGIN;
INSERT INTO order_item (order_id, sku_id, quantity, unit_price_applied)
SELECT :'test_order_id'::BIGINT, sku_id, 1, 28000
FROM sku
WHERE sku_code = 'DER-ROS-050';
COMMIT;
SQL
second_pid=$!

first_status=0
second_status=0
wait "$first_pid" || first_status=$?
wait "$second_pid" || second_status=$?

if [ "$first_status" -ne 0 ]; then
    cat "$first_log" >&2
    echo "ERROR: falló la primera transacción concurrente." >&2
    exit 1
fi

if [ "$second_status" -ne 0 ]; then
    cat "$second_log" >&2
    echo "ERROR: falló la segunda transacción concurrente." >&2
    exit 1
fi

concurrent_result="$("${psql_base[@]}" -qAt -v test_order_id="$test_order_id" <<'SQL'
SET search_path TO bdia, public;
SELECT so.total_amount = 123000
   AND so.total_amount = SUM(oi.quantity * oi.unit_price_applied)
FROM sales_order so
JOIN order_item oi ON oi.order_id = so.order_id
WHERE so.order_id = :'test_order_id'::BIGINT
GROUP BY so.order_id, so.total_amount;
SQL
)"

if [ "$concurrent_result" != "t" ]; then
    echo "ERROR: el total del pedido no conservó las dos inserciones concurrentes." >&2
    exit 1
fi

echo "1 | Dos inserciones concurrentes conservan el total correcto | OK"
