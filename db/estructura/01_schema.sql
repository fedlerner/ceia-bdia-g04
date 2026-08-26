-- Trabajo Práctico Integrador - Bases de Datos con y para IA
-- Grupo 4 - Tienda online de cosmética y perfumería
-- Modelo físico PostgreSQL (implementación mínima)
--
-- Alcance:
--   * PostgreSQL como fuente principal de verdad.
--   * JSONB acotado a atributos variables y contexto de recomendaciones.
--   * Los eventos de navegación se almacenan exclusivamente en MongoDB.
--   * MongoDB, Redis, pgvector y embeddings no forman parte de este script.

BEGIN;

CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS bdia;
SET search_path TO bdia, public;

-- ---------------------------------------------------------------------------
-- Catálogo
-- ---------------------------------------------------------------------------

CREATE TABLE brand (
    brand_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(120) NOT NULL,
    active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT brand_name_uq UNIQUE (name),
    CONSTRAINT brand_name_not_blank_ck CHECK (btrim(name) <> '')
);

CREATE TABLE category (
    category_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(120) NOT NULL,
    description   TEXT,
    active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT category_name_uq UNIQUE (name),
    CONSTRAINT category_name_not_blank_ck CHECK (btrim(name) <> '')
);

CREATE TABLE product (
    product_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_code  VARCHAR(30) NOT NULL,
    brand_id      BIGINT NOT NULL,
    name          VARCHAR(180) NOT NULL,
    description   TEXT,
    attributes    JSONB NOT NULL DEFAULT '{}'::JSONB,
    active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT product_brand_fk
        FOREIGN KEY (brand_id) REFERENCES brand (brand_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT product_code_uq UNIQUE (product_code),
    CONSTRAINT product_brand_name_uq UNIQUE (brand_id, name),
    CONSTRAINT product_code_format_ck
        CHECK (product_code ~ '^product-[0-9]{3,}$'),
    CONSTRAINT product_name_not_blank_ck CHECK (btrim(name) <> ''),
    CONSTRAINT product_attributes_object_ck
        CHECK (jsonb_typeof(attributes) = 'object')
);

CREATE TABLE product_category (
    product_id    BIGINT NOT NULL,
    category_id   BIGINT NOT NULL,
    is_primary    BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT product_category_pk PRIMARY KEY (product_id, category_id),
    CONSTRAINT product_category_product_fk
        FOREIGN KEY (product_id) REFERENCES product (product_id)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT product_category_category_fk
        FOREIGN KEY (category_id) REFERENCES category (category_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT
);

-- Cada producto puede tener, como máximo, una categoría principal.
CREATE UNIQUE INDEX product_one_primary_category_uq
    ON product_category (product_id)
    WHERE is_primary = TRUE;

CREATE TABLE sku (
    sku_id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id     BIGINT NOT NULL,
    sku_code       VARCHAR(80) NOT NULL,
    presentation   VARCHAR(160) NOT NULL,
    size_value     NUMERIC(12,3),
    size_unit      VARCHAR(30),
    attributes     JSONB NOT NULL DEFAULT '{}'::JSONB,
    active         BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sku_product_fk
        FOREIGN KEY (product_id) REFERENCES product (product_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT sku_code_uq UNIQUE (sku_code),
    CONSTRAINT sku_code_not_blank_ck CHECK (btrim(sku_code) <> ''),
    CONSTRAINT sku_presentation_not_blank_ck CHECK (btrim(presentation) <> ''),
    CONSTRAINT sku_size_positive_ck CHECK (size_value IS NULL OR size_value > 0),
    CONSTRAINT sku_size_pair_ck CHECK (
        (size_value IS NULL AND size_unit IS NULL)
        OR (size_value IS NOT NULL AND size_unit IS NOT NULL AND btrim(size_unit) <> '')
    ),
    CONSTRAINT sku_attributes_object_ck
        CHECK (jsonb_typeof(attributes) = 'object')
);

CREATE TABLE sku_price (
    price_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku_id         BIGINT NOT NULL,
    amount         NUMERIC(14,2) NOT NULL,
    currency       VARCHAR(3) NOT NULL DEFAULT 'ARS',
    valid_from     TIMESTAMPTZ NOT NULL,
    valid_to       TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sku_price_sku_fk
        FOREIGN KEY (sku_id) REFERENCES sku (sku_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT sku_price_amount_nonnegative_ck CHECK (amount >= 0),
    CONSTRAINT sku_price_currency_ck CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT sku_price_period_ck CHECK (valid_to IS NULL OR valid_to > valid_from),
    CONSTRAINT sku_price_no_overlapping_periods_excl
        EXCLUDE USING gist (
            sku_id WITH =,
            tstzrange(valid_from, COALESCE(valid_to, 'infinity'::TIMESTAMPTZ), '[)') WITH &&
        )
);

-- Cada SKU puede tener una sola fila de precio sin fecha de cierre.
CREATE UNIQUE INDEX sku_one_open_ended_price_uq
    ON sku_price (sku_id)
    WHERE valid_to IS NULL;

CREATE TABLE inventory (
    sku_id                 BIGINT PRIMARY KEY,
    available_qty          INTEGER NOT NULL DEFAULT 0,
    low_stock_threshold    INTEGER NOT NULL DEFAULT 0,
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT inventory_sku_fk
        FOREIGN KEY (sku_id) REFERENCES sku (sku_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT inventory_available_nonnegative_ck CHECK (available_qty >= 0),
    CONSTRAINT inventory_threshold_nonnegative_ck CHECK (low_stock_threshold >= 0)
);

-- ---------------------------------------------------------------------------
-- Clientes, sesiones y comportamiento
-- ---------------------------------------------------------------------------

CREATE TABLE customer (
    customer_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_code  VARCHAR(40) NOT NULL,
    full_name      VARCHAR(180) NOT NULL,
    email          VARCHAR(254) NOT NULL,
    phone          VARCHAR(40),
    active         BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT customer_code_uq UNIQUE (customer_code),
    CONSTRAINT customer_code_format_ck CHECK (customer_code ~ '^user-[0-9]+$'),
    CONSTRAINT customer_name_not_blank_ck CHECK (btrim(full_name) <> ''),
    CONSTRAINT customer_email_not_blank_ck CHECK (btrim(email) <> '')
);

-- Unicidad de correo sin distinguir mayúsculas y minúsculas.
CREATE UNIQUE INDEX customer_email_lower_uq ON customer (lower(email));

CREATE TABLE customer_session (
    session_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_code   VARCHAR(50) NOT NULL,
    customer_id    BIGINT,
    started_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at       TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT customer_session_customer_fk
        FOREIGN KEY (customer_id) REFERENCES customer (customer_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT customer_session_id_customer_uq UNIQUE (session_id, customer_id),
    CONSTRAINT customer_session_code_uq UNIQUE (session_code),
    CONSTRAINT customer_session_code_format_ck CHECK (session_code ~ '^session-[0-9]+$'),
    CONSTRAINT customer_session_period_ck CHECK (ended_at IS NULL OR ended_at > started_at)
);


-- ---------------------------------------------------------------------------
-- Pedidos e inventario auditable
-- ---------------------------------------------------------------------------

CREATE TABLE sales_order (
    order_id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_code         VARCHAR(40) NOT NULL,
    customer_id        BIGINT NOT NULL,
    ordered_at         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_status       VARCHAR(20) NOT NULL DEFAULT 'pending',
    payment_status     VARCHAR(20) NOT NULL DEFAULT 'pending',
    shipping_status    VARCHAR(20) NOT NULL DEFAULT 'pending',
    total_amount       NUMERIC(14,2) NOT NULL DEFAULT 0,
    currency           VARCHAR(3) NOT NULL DEFAULT 'ARS',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT sales_order_customer_fk
        FOREIGN KEY (customer_id) REFERENCES customer (customer_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT sales_order_code_uq UNIQUE (order_code),
    CONSTRAINT sales_order_code_format_ck CHECK (order_code ~ '^order-[0-9]+$'),
    CONSTRAINT sales_order_status_ck CHECK (
        order_status IN ('pending', 'confirmed', 'completed', 'cancelled')
    ),
    CONSTRAINT sales_order_payment_status_ck CHECK (
        payment_status IN ('pending', 'approved', 'rejected', 'refunded')
    ),
    CONSTRAINT sales_order_shipping_status_ck CHECK (
        shipping_status IN ('pending', 'prepared', 'shipped', 'delivered', 'cancelled')
    ),
    CONSTRAINT sales_order_total_nonnegative_ck CHECK (total_amount >= 0),
    CONSTRAINT sales_order_currency_ck CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE TABLE order_item (
    order_item_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id               BIGINT NOT NULL,
    sku_id                 BIGINT NOT NULL,
    quantity               INTEGER NOT NULL,
    unit_price_applied     NUMERIC(14,2) NOT NULL,
    CONSTRAINT order_item_order_fk
        FOREIGN KEY (order_id) REFERENCES sales_order (order_id)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT order_item_sku_fk
        FOREIGN KEY (sku_id) REFERENCES sku (sku_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT order_item_order_sku_uq UNIQUE (order_id, sku_id),
    CONSTRAINT order_item_quantity_positive_ck CHECK (quantity > 0),
    CONSTRAINT order_item_price_nonnegative_ck CHECK (unit_price_applied >= 0)
);

CREATE TABLE inventory_movement (
    movement_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku_id             BIGINT NOT NULL,
    order_id           BIGINT,
    movement_type      VARCHAR(20) NOT NULL,
    quantity_change    INTEGER NOT NULL,
    reason             TEXT,
    occurred_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT inventory_movement_sku_fk
        FOREIGN KEY (sku_id) REFERENCES sku (sku_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT inventory_movement_order_fk
        FOREIGN KEY (order_id) REFERENCES sales_order (order_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT inventory_movement_type_ck CHECK (
        movement_type IN ('receipt', 'sale', 'adjustment', 'return', 'cancellation')
    ),
    CONSTRAINT inventory_movement_nonzero_ck CHECK (quantity_change <> 0),
    CONSTRAINT inventory_movement_sign_ck CHECK (
        (movement_type = 'sale' AND quantity_change < 0)
        OR (movement_type IN ('receipt', 'return', 'cancellation') AND quantity_change > 0)
        OR (movement_type = 'adjustment' AND quantity_change <> 0)
    ),
    CONSTRAINT inventory_movement_sale_order_ck CHECK (
        movement_type <> 'sale' OR order_id IS NOT NULL
    )
);

-- ---------------------------------------------------------------------------
-- Reseñas y recomendaciones sintéticas
-- ---------------------------------------------------------------------------

CREATE TABLE review (
    review_id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id          BIGINT NOT NULL,
    product_id           BIGINT NOT NULL,
    rating               SMALLINT NOT NULL,
    review_text          TEXT,
    moderation_status    VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT review_customer_fk
        FOREIGN KEY (customer_id) REFERENCES customer (customer_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT review_product_fk
        FOREIGN KEY (product_id) REFERENCES product (product_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT review_customer_product_uq UNIQUE (customer_id, product_id),
    CONSTRAINT review_rating_ck CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT review_moderation_status_ck CHECK (
        moderation_status IN ('pending', 'approved', 'rejected')
    )
);

CREATE TABLE recommendation (
    recommendation_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id           BIGINT,
    session_id            UUID,
    generated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    method                VARCHAR(80) NOT NULL,
    model_version         VARCHAR(80),
    context               JSONB NOT NULL DEFAULT '{}'::JSONB,
    CONSTRAINT recommendation_customer_fk
        FOREIGN KEY (customer_id) REFERENCES customer (customer_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT recommendation_session_fk
        FOREIGN KEY (session_id) REFERENCES customer_session (session_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT recommendation_session_customer_fk
        FOREIGN KEY (session_id, customer_id)
        REFERENCES customer_session (session_id, customer_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT recommendation_target_ck CHECK (
        customer_id IS NOT NULL OR session_id IS NOT NULL
    ),
    CONSTRAINT recommendation_method_not_blank_ck CHECK (btrim(method) <> ''),
    CONSTRAINT recommendation_context_object_ck CHECK (jsonb_typeof(context) = 'object')
);

CREATE TABLE recommendation_item (
    recommendation_id    BIGINT NOT NULL,
    sku_id               BIGINT NOT NULL,
    position             INTEGER NOT NULL,
    score                NUMERIC(12,6),
    reason               TEXT,
    CONSTRAINT recommendation_item_pk PRIMARY KEY (recommendation_id, sku_id),
    CONSTRAINT recommendation_item_recommendation_fk
        FOREIGN KEY (recommendation_id) REFERENCES recommendation (recommendation_id)
        ON UPDATE RESTRICT ON DELETE CASCADE,
    CONSTRAINT recommendation_item_sku_fk
        FOREIGN KEY (sku_id) REFERENCES sku (sku_id)
        ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT recommendation_item_position_uq UNIQUE (recommendation_id, position),
    CONSTRAINT recommendation_item_position_positive_ck CHECK (position > 0)
);

-- ---------------------------------------------------------------------------
-- Funciones y triggers de integridad
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER product_set_updated_at_trg
BEFORE UPDATE ON product
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER sku_set_updated_at_trg
BEFORE UPDATE ON sku
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER customer_set_updated_at_trg
BEFORE UPDATE ON customer
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER sales_order_set_updated_at_trg
BEFORE UPDATE ON sales_order
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER review_set_updated_at_trg
BEFORE UPDATE ON review
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- El total se mantiene con deltas atómicos. Las actualizaciones concurrentes
-- sobre una misma cabecera quedan serializadas por el bloqueo de fila del UPDATE.
CREATE OR REPLACE FUNCTION apply_order_total_delta()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE sales_order
           SET total_amount = total_amount + (NEW.quantity * NEW.unit_price_applied)
         WHERE order_id = NEW.order_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE sales_order
           SET total_amount = total_amount - (OLD.quantity * OLD.unit_price_applied)
         WHERE order_id = OLD.order_id;
    ELSIF OLD.order_id = NEW.order_id THEN
        UPDATE sales_order
           SET total_amount = total_amount
                            + (NEW.quantity * NEW.unit_price_applied)
                            - (OLD.quantity * OLD.unit_price_applied)
         WHERE order_id = NEW.order_id;
    ELSE
        UPDATE sales_order
           SET total_amount = total_amount - (OLD.quantity * OLD.unit_price_applied)
         WHERE order_id = OLD.order_id;

        UPDATE sales_order
           SET total_amount = total_amount + (NEW.quantity * NEW.unit_price_applied)
         WHERE order_id = NEW.order_id;
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER order_item_refresh_total_trg
AFTER INSERT OR UPDATE OR DELETE ON order_item
FOR EACH ROW EXECUTE FUNCTION apply_order_total_delta();

-- Una salida por venta solo puede descontar unidades realmente compradas.
-- El bloqueo del ítem serializa ventas concurrentes del mismo pedido y SKU.
CREATE OR REPLACE FUNCTION validate_sale_inventory_movement()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    purchased_qty BIGINT;
    already_sold_qty BIGINT;
BEGIN
    -- Los signos inválidos quedan a cargo de inventory_movement_sign_ck.
    IF NEW.movement_type <> 'sale' OR NEW.quantity_change >= 0 THEN
        RETURN NEW;
    END IF;

    SELECT oi.quantity
      INTO purchased_qty
      FROM order_item oi
      JOIN sales_order so ON so.order_id = oi.order_id
     WHERE oi.order_id = NEW.order_id
       AND oi.sku_id = NEW.sku_id
       AND so.order_status = 'completed'
       AND so.payment_status = 'approved'
     FOR UPDATE OF oi, so;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'La venta requiere un pedido completado y pagado que contenga el SKU';
    END IF;

    SELECT COALESCE(-SUM(quantity_change), 0)
      INTO already_sold_qty
      FROM inventory_movement
     WHERE order_id = NEW.order_id
       AND sku_id = NEW.sku_id
       AND movement_type = 'sale';

    IF already_sold_qty + ABS(NEW.quantity_change) > purchased_qty THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'La venta supera la cantidad comprada para el pedido y SKU';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER inventory_movement_validate_sale_trg
BEFORE INSERT ON inventory_movement
FOR EACH ROW EXECUTE FUNCTION validate_sale_inventory_movement();

-- Una compra ya reflejada en inventario no puede quedar asociada luego a un
-- pedido no efectivo ni a un ítem que deje de respaldar la cantidad vendida.
CREATE OR REPLACE FUNCTION protect_effective_order_with_sales()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF (NEW.order_status <> 'completed' OR NEW.payment_status <> 'approved')
       AND EXISTS (
           SELECT 1
             FROM inventory_movement im
            WHERE im.order_id = OLD.order_id
              AND im.movement_type = 'sale'
       ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Un pedido con ventas registradas debe permanecer completado y pagado';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER sales_order_protect_effective_sale_trg
BEFORE UPDATE OF order_status, payment_status ON sales_order
FOR EACH ROW EXECUTE FUNCTION protect_effective_order_with_sales();

CREATE OR REPLACE FUNCTION protect_order_item_with_sales()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    sold_qty INTEGER;
BEGIN
    SELECT COALESCE(-SUM(quantity_change), 0)
      INTO sold_qty
      FROM inventory_movement
     WHERE order_id = OLD.order_id
       AND sku_id = OLD.sku_id
       AND movement_type = 'sale';

    IF TG_OP = 'DELETE'
       OR NEW.order_id <> OLD.order_id
       OR NEW.sku_id <> OLD.sku_id THEN
        IF sold_qty > 0 THEN
            RAISE EXCEPTION USING
                ERRCODE = '23514',
                MESSAGE = 'No se puede quitar o reasignar un ítem con ventas registradas';
        END IF;
    ELSIF NEW.quantity < sold_qty THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'La cantidad del ítem no puede ser menor que la ya descontada';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER order_item_protect_sales_trg
BEFORE UPDATE OR DELETE ON order_item
FOR EACH ROW EXECUTE FUNCTION protect_order_item_with_sales();

-- Cada movimiento modifica el stock actual. La restricción de inventory
-- impide que el resultado sea negativo.
CREATE OR REPLACE FUNCTION apply_inventory_movement()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE inventory
       SET available_qty = available_qty + NEW.quantity_change,
           updated_at = CURRENT_TIMESTAMP
     WHERE sku_id = NEW.sku_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe inventario para el SKU %', NEW.sku_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER inventory_movement_apply_trg
AFTER INSERT ON inventory_movement
FOR EACH ROW EXECUTE FUNCTION apply_inventory_movement();

-- Los movimientos son registros de auditoría: se compensan, no se modifican.
CREATE OR REPLACE FUNCTION prevent_inventory_movement_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'Los movimientos de inventario son inmutables; registre un movimiento compensatorio';
END;
$$;

CREATE TRIGGER inventory_movement_immutable_trg
BEFORE UPDATE OR DELETE ON inventory_movement
FOR EACH ROW EXECUTE FUNCTION prevent_inventory_movement_change();


COMMENT ON SCHEMA bdia IS
    'Capa relacional principal para la tienda online de cosmética y perfumería';

COMMENT ON COLUMN product.product_code IS
    'Identificador externo estable compartido con MongoDB y Redis';

COMMENT ON COLUMN customer.customer_code IS
    'Identificador seudónimo estable compartido con MongoDB y Redis';

COMMENT ON COLUMN customer_session.session_code IS
    'Identificador externo de sesión compartido con MongoDB y Redis';

COMMENT ON COLUMN sales_order.order_code IS
    'Identificador externo estable del pedido compartido con MongoDB';

COMMENT ON COLUMN product.attributes IS
    'Atributos variables comunes al producto; no reemplaza relaciones normalizadas';

COMMENT ON COLUMN sku.attributes IS
    'Atributos variables propios de la variante, como tono o color';

COMMENT ON TABLE customer_session IS
    'Registro durable mínimo; el estado activo y su TTL se administran en Redis';

COMMENT ON TABLE recommendation IS
    'Resultados sintéticos persistentes para trazabilidad; no implica entrenar ni ejecutar un modelo';

COMMIT;
