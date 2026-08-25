-- Índices y vista operativa del modelo PostgreSQL.

BEGIN;
SET search_path TO bdia, public;

-- ---------------------------------------------------------------------------
-- Índices de acceso
-- ---------------------------------------------------------------------------

CREATE INDEX product_brand_active_idx
    ON product (brand_id, active);

CREATE INDEX product_category_category_idx
    ON product_category (category_id, product_id);

CREATE INDEX sku_product_active_idx
    ON sku (product_id, active);

CREATE INDEX sku_price_history_idx
    ON sku_price (sku_id, valid_from DESC);

CREATE INDEX inventory_low_stock_idx
    ON inventory (available_qty, sku_id)
    WHERE available_qty <= low_stock_threshold;

CREATE INDEX customer_session_customer_time_idx
    ON customer_session (customer_id, started_at DESC)
    WHERE customer_id IS NOT NULL;


CREATE INDEX sales_order_customer_status_time_idx
    ON sales_order (customer_id, order_status, ordered_at DESC);

CREATE INDEX sales_order_completed_time_idx
    ON sales_order (ordered_at DESC)
    WHERE order_status = 'completed' AND payment_status = 'approved';

CREATE INDEX order_item_sku_order_idx
    ON order_item (sku_id, order_id);

CREATE INDEX inventory_movement_sku_time_idx
    ON inventory_movement (sku_id, occurred_at DESC);

CREATE INDEX review_product_status_idx
    ON review (product_id, moderation_status, created_at DESC);

CREATE INDEX recommendation_customer_time_idx
    ON recommendation (customer_id, generated_at DESC)
    WHERE customer_id IS NOT NULL;

CREATE INDEX recommendation_session_time_idx
    ON recommendation (session_id, generated_at DESC)
    WHERE session_id IS NOT NULL;

CREATE INDEX recommendation_item_sku_idx
    ON recommendation_item (sku_id, recommendation_id);

-- GIN solo para filtros que realmente consulten claves o valores JSONB.
CREATE INDEX product_attributes_gin_idx
    ON product USING gin (attributes);

CREATE INDEX sku_attributes_gin_idx
    ON sku USING gin (attributes);

-- ---------------------------------------------------------------------------
-- Vista operativa de catálogo activo
-- ---------------------------------------------------------------------------

CREATE VIEW v_active_catalog AS
SELECT
    p.product_id,
    p.product_code,
    p.name AS product_name,
    b.brand_id,
    b.name AS brand_name,
    s.sku_id,
    s.sku_code,
    s.presentation,
    s.size_value,
    s.size_unit,
    s.attributes AS sku_attributes,
    sp.amount AS current_price,
    sp.currency,
    i.available_qty,
    i.low_stock_threshold,
    p.attributes AS product_attributes
FROM product p
JOIN brand b
  ON b.brand_id = p.brand_id
JOIN sku s
  ON s.product_id = p.product_id
JOIN sku_price sp
  ON sp.sku_id = s.sku_id
 AND sp.valid_to IS NULL
JOIN inventory i
  ON i.sku_id = s.sku_id
WHERE p.active = TRUE
  AND b.active = TRUE
  AND s.active = TRUE
  AND i.available_qty > 0;


COMMIT;
