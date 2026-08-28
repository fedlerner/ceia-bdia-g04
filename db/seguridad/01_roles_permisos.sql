-- Roles de grupo y privilegios mínimos para PostgreSQL.
--
-- POSTGRES_USER conserva la propiedad de los objetos y se usa únicamente para
-- migraciones, carga inicial y validación. Los roles siguientes son NOLOGIN:
-- una aplicación real debe usar credenciales propias y heredar uno de ellos.

BEGIN;

SET search_path TO bdia, public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bdia_app') THEN
        CREATE ROLE bdia_app
            NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bdia_analyst') THEN
        CREATE ROLE bdia_analyst
            NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
    END IF;
END;
$$;

ALTER ROLE bdia_app
    NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE bdia_analyst
    NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

-- Ningún usuario implícito puede crear objetos ni ejecutar funciones del
-- esquema de la aplicación. Los privilegios se conceden siempre de forma
-- explícita a los roles de grupo.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA bdia FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA bdia FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA bdia FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA bdia FROM PUBLIC;
REVOKE ALL ON SCHEMA bdia FROM bdia_app, bdia_analyst;
REVOKE ALL ON ALL TABLES IN SCHEMA bdia FROM bdia_app, bdia_analyst;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA bdia FROM bdia_app, bdia_analyst;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA bdia FROM bdia_app, bdia_analyst;

-- Privilegios predeterminados para objetos futuros. Atencion: comprobado en
-- PostgreSQL 16, estas tres sentencias se aceptan pero no dejan registro en
-- pg_default_acl. Las dos primeras son inocuas, porque PUBLIC no recibe nada
-- sobre tablas ni secuencias por omision. La tercera si importa: PUBLIC si
-- recibe EXECUTE sobre funciones por omision, y una funcion creada despues de
-- este script vuelve a quedar ejecutable por PUBLIC. Toda funcion nueva debe
-- llevar su REVOKE explicito, como los de mas arriba.
ALTER DEFAULT PRIVILEGES IN SCHEMA bdia REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA bdia REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA bdia REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

GRANT USAGE ON SCHEMA bdia TO bdia_app, bdia_analyst;

-- Rol de aplicación: lectura necesaria para ejecutar las reglas de negocio y
-- escritura acotada. No recibe permisos de UPDATE/DELETE sobre movimientos.
GRANT SELECT ON ALL TABLES IN SCHEMA bdia TO bdia_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA bdia TO bdia_app;

GRANT INSERT (name, active) ON brand TO bdia_app;
GRANT UPDATE (name, active) ON brand TO bdia_app;
GRANT INSERT (name, description, active) ON category TO bdia_app;
GRANT UPDATE (name, description, active) ON category TO bdia_app;
GRANT INSERT (
    product_code, brand_id, name, description, attributes, active
) ON product TO bdia_app;
GRANT UPDATE (brand_id, name, description, attributes, active) ON product TO bdia_app;
GRANT INSERT (product_id, category_id, is_primary) ON product_category TO bdia_app;
GRANT DELETE ON product_category TO bdia_app;
GRANT INSERT (
    product_id, sku_code, presentation, size_value, size_unit, attributes, active
) ON sku TO bdia_app;
GRANT UPDATE (presentation, size_value, size_unit, attributes, active) ON sku TO bdia_app;
GRANT INSERT (sku_id, amount, currency, valid_from, valid_to) ON sku_price TO bdia_app;
GRANT UPDATE (valid_to) ON sku_price TO bdia_app;

-- available_qty nace en cero y solo cambia al insertar inventory_movement.
GRANT INSERT (sku_id, low_stock_threshold) ON inventory TO bdia_app;
GRANT UPDATE (low_stock_threshold) ON inventory TO bdia_app;
GRANT INSERT (
    sku_id, order_id, movement_type, quantity_change, reason
) ON inventory_movement TO bdia_app;

GRANT INSERT (
    customer_code, full_name, email, phone, active
) ON customer TO bdia_app;
GRANT UPDATE (full_name, email, phone, active) ON customer TO bdia_app;
GRANT INSERT (
    session_code, customer_id, started_at, ended_at
) ON customer_session TO bdia_app;
GRANT UPDATE (customer_id, started_at, ended_at) ON customer_session TO bdia_app;

-- total_amount se omite tanto del INSERT como del UPDATE. El trigger sobre
-- order_item lo mantiene mediante una función SECURITY DEFINER.
GRANT INSERT (
    order_code, customer_id, ordered_at, order_status,
    payment_status, shipping_status, currency
) ON sales_order TO bdia_app;
GRANT UPDATE (
    order_status, payment_status, shipping_status
) ON sales_order TO bdia_app;
GRANT INSERT (
    order_id, sku_id, quantity, unit_price_applied
) ON order_item TO bdia_app;
GRANT UPDATE (
    order_id, sku_id, quantity, unit_price_applied
) ON order_item TO bdia_app;
GRANT DELETE ON order_item TO bdia_app;

GRANT INSERT (
    customer_id, product_id, rating, review_text, moderation_status
) ON review TO bdia_app;
GRANT UPDATE (rating, review_text, moderation_status) ON review TO bdia_app;
GRANT INSERT (
    customer_id, session_id, generated_at, method, model_version, context
) ON recommendation TO bdia_app;
GRANT UPDATE (generated_at, method, model_version, context) ON recommendation TO bdia_app;
GRANT DELETE ON recommendation TO bdia_app;
GRANT INSERT (
    recommendation_id, sku_id, position, score, reason
) ON recommendation_item TO bdia_app;
GRANT UPDATE (position, score, reason) ON recommendation_item TO bdia_app;
GRANT DELETE ON recommendation_item TO bdia_app;

-- Rol analítico: lectura comercial y agregable sin acceso directo a los datos
-- identificatorios de customer, las sesiones ni el texto libre de review.
GRANT SELECT ON
    brand, category, product, product_category, sku, sku_price,
    inventory, inventory_movement, sales_order, order_item,
    recommendation, recommendation_item, v_active_catalog
TO bdia_analyst;

COMMENT ON ROLE bdia_app IS
    'Rol NOLOGIN para el backend; aplica privilegio mínimo y protege campos derivados';
COMMENT ON ROLE bdia_analyst IS
    'Rol NOLOGIN de lectura comercial sin acceso directo a datos identificatorios';

COMMIT;
