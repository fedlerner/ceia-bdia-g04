-- Pruebas negativas: cada operación inválida debe ser rechazada por PostgreSQL.

SET search_path TO bdia, public;

\echo 'CONTROLES DE INTEGRIDAD - Cada operación inválida debe ser rechazada'

DO $$
DECLARE
    test_sku_id BIGINT;
    test_order_id BIGINT;
BEGIN
    SELECT sku_id INTO STRICT test_sku_id
    FROM sku
    WHERE sku_code = 'AUR-LUM-050';

    SELECT order_id INTO STRICT test_order_id
    FROM sales_order
    ORDER BY order_id
    LIMIT 1;

    BEGIN
        INSERT INTO inventory_movement
            (sku_id, order_id, movement_type, quantity_change, reason)
        VALUES
            (test_sku_id, test_order_id, 'sale', 1, 'Prueba inválida');

        RAISE EXCEPTION 'ERROR: una venta con cantidad positiva fue aceptada';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;
END;
$$;
\echo '1 | Venta con cantidad positiva rechazada | OK'

DO $$
DECLARE
    test_sku_id BIGINT;
BEGIN
    SELECT sku_id INTO STRICT test_sku_id
    FROM sku
    WHERE sku_code = 'AUR-LUM-050';

    BEGIN
        INSERT INTO inventory_movement
            (sku_id, movement_type, quantity_change, reason)
        VALUES
            (test_sku_id, 'receipt', -1, 'Prueba inválida');

        RAISE EXCEPTION 'ERROR: una recepción con cantidad negativa fue aceptada';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;
END;
$$;
\echo '2 | Recepción con cantidad negativa rechazada | OK'

DO $$
DECLARE
    other_customer_id BIGINT;
BEGIN
    SELECT customer_id INTO STRICT other_customer_id
    FROM customer
    WHERE customer_code = 'user-124';

    BEGIN
        UPDATE customer_session
           SET customer_id = other_customer_id
         WHERE session_code = 'session-456';

        RAISE EXCEPTION 'ERROR: una sesión referenciada pudo reasignarse a otro cliente';
    EXCEPTION
        WHEN foreign_key_violation THEN
            NULL;
    END;
END;
$$;
\echo '3 | Reasignación inconsistente de sesión rechazada | OK'

DO $$
DECLARE
    other_customer_id BIGINT;
    test_session_id UUID;
BEGIN
    SELECT customer_id INTO STRICT other_customer_id
    FROM customer
    WHERE customer_code = 'user-124';

    SELECT session_id INTO STRICT test_session_id
    FROM customer_session
    WHERE session_code = 'session-456';

    BEGIN
        INSERT INTO recommendation
            (customer_id, session_id, method, context)
        VALUES
            (other_customer_id, test_session_id, 'invalid_test', '{}'::JSONB);

        RAISE EXCEPTION 'ERROR: una recomendación con cliente y sesión incompatibles fue aceptada';
    EXCEPTION
        WHEN foreign_key_violation THEN
            NULL;
    END;
END;
$$;
\echo '4 | Recomendación con cliente y sesión incompatibles rechazada | OK'

DO $$
DECLARE
    test_sku_id BIGINT;
    cancelled_order_id BIGINT;
BEGIN
    SELECT sku_id INTO STRICT test_sku_id
    FROM sku
    WHERE sku_code = 'CHR-BAS-030-N';

    SELECT order_id INTO STRICT cancelled_order_id
    FROM sales_order
    WHERE order_code = 'order-325';

    BEGIN
        INSERT INTO inventory_movement
            (sku_id, order_id, movement_type, quantity_change, reason)
        VALUES
            (test_sku_id, cancelled_order_id, 'sale', -1, 'Prueba inválida');

        RAISE EXCEPTION 'ERROR: una venta para un pedido cancelado fue aceptada';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;
END;
$$;
\echo '5 | Venta vinculada a pedido cancelado rechazada | OK'

DO $$
DECLARE
    absent_sku_id BIGINT;
    effective_order_id BIGINT;
BEGIN
    SELECT sku_id INTO STRICT absent_sku_id
    FROM sku
    WHERE sku_code = 'AUR-NOC-050';

    SELECT order_id INTO STRICT effective_order_id
    FROM sales_order
    WHERE order_code = 'order-321';

    BEGIN
        INSERT INTO inventory_movement
            (sku_id, order_id, movement_type, quantity_change, reason)
        VALUES
            (absent_sku_id, effective_order_id, 'sale', -1, 'Prueba inválida');

        RAISE EXCEPTION 'ERROR: una venta de un SKU ausente del pedido fue aceptada';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;
END;
$$;
\echo '6 | Venta de SKU ausente del pedido rechazada | OK'

DO $$
DECLARE
    purchased_sku_id BIGINT;
    effective_order_id BIGINT;
BEGIN
    SELECT sku_id INTO STRICT purchased_sku_id
    FROM sku
    WHERE sku_code = 'AUR-LUM-050';

    SELECT order_id INTO STRICT effective_order_id
    FROM sales_order
    WHERE order_code = 'order-321';

    BEGIN
        INSERT INTO inventory_movement
            (sku_id, order_id, movement_type, quantity_change, reason)
        VALUES
            (purchased_sku_id, effective_order_id, 'sale', -1, 'Prueba inválida');

        RAISE EXCEPTION 'ERROR: una venta superior a la cantidad comprada fue aceptada';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;
END;
$$;
\echo '7 | Venta superior a la cantidad comprada rechazada | OK'

BEGIN;

DO $$
DECLARE
    first_sku_id BIGINT;
    second_sku_id BIGINT;
    effective_order_id BIGINT;
BEGIN
    SELECT order_id INTO STRICT effective_order_id
    FROM sales_order
    WHERE order_code = 'order-321';

    SELECT sku_id INTO STRICT first_sku_id
    FROM sku
    WHERE sku_code = 'AUR-LUM-050';

    SELECT sku_id INTO STRICT second_sku_id
    FROM sku
    WHERE sku_code = 'DER-ROS-050';

    BEGIN
        UPDATE sales_order
           SET order_status = 'cancelled'
         WHERE order_id = effective_order_id;

        RAISE EXCEPTION 'ERROR: un pedido con ventas sin compensar dejó de ser efectivo';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    BEGIN
        INSERT INTO inventory_movement
            (sku_id, movement_type, quantity_change, reason)
        VALUES
            (first_sku_id, 'return', 1, 'Prueba inválida');

        RAISE EXCEPTION 'ERROR: una devolución sin pedido fue aceptada';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    BEGIN
        INSERT INTO inventory_movement
            (sku_id, order_id, movement_type, quantity_change, reason)
        VALUES
            (first_sku_id, effective_order_id, 'return', 2, 'Prueba inválida');

        RAISE EXCEPTION 'ERROR: una devolución superior a lo vendido fue aceptada';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    INSERT INTO inventory_movement
        (sku_id, order_id, movement_type, quantity_change, reason)
    VALUES
        (first_sku_id, effective_order_id, 'return', 1, 'Devolución completa de prueba');

    BEGIN
        UPDATE sales_order
           SET payment_status = 'refunded'
         WHERE order_id = effective_order_id;

        RAISE EXCEPTION 'ERROR: un reembolso parcial fue aceptado';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;

    INSERT INTO inventory_movement
        (sku_id, order_id, movement_type, quantity_change, reason)
    VALUES
        (second_sku_id, effective_order_id, 'cancellation', 1, 'Cancelación completa de prueba');

    UPDATE sales_order
       SET order_status = 'cancelled',
           payment_status = 'refunded',
           shipping_status = 'cancelled'
     WHERE order_id = effective_order_id;

    IF NOT EXISTS (
        SELECT 1
        FROM sales_order
        WHERE order_id = effective_order_id
          AND order_status = 'cancelled'
          AND payment_status = 'refunded'
    ) THEN
        RAISE EXCEPTION 'ERROR: la compensación total no permitió cancelar y reembolsar el pedido';
    END IF;
END;
$$;

ROLLBACK;
\echo '8 | Pedido solo cancelable y reembolsable tras compensación total | OK'

DO $$
BEGIN
    BEGIN
        UPDATE order_item oi
           SET quantity = 1
          FROM sales_order so, sku s
         WHERE oi.order_id = so.order_id
           AND oi.sku_id = s.sku_id
           AND so.order_code = 'order-322'
           AND s.sku_code = 'CHR-LAB-CAR';

        RAISE EXCEPTION 'ERROR: un ítem quedó por debajo de la cantidad vendida';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;
END;
$$;
\echo '9 | Reducción de ítem por debajo de lo vendido rechazada | OK'

DO $$
BEGIN
    BEGIN
        UPDATE order_item oi
           SET unit_price_applied = unit_price_applied + 1
          FROM sales_order so, sku s
         WHERE oi.order_id = so.order_id
           AND oi.sku_id = s.sku_id
           AND so.order_code = 'order-322'
           AND s.sku_code = 'CHR-LAB-CAR';

        RAISE EXCEPTION 'ERROR: se modificó el precio histórico de un ítem vendido';
    EXCEPTION
        WHEN check_violation THEN
            NULL;
    END;
END;
$$;
\echo '10 | Modificación del precio histórico de un ítem vendido rechazada | OK'
