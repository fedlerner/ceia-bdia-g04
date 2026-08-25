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
