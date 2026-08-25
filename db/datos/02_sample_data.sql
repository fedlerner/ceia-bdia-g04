-- Datos sintéticos para validar el modelo físico y las consultas.
-- No contienen información personal real.

BEGIN;
SET search_path TO bdia, public;

-- ---------------------------------------------------------------------------
-- Catálogo: 4 marcas, 5 categorías, 8 productos y 10 SKU
-- ---------------------------------------------------------------------------

INSERT INTO brand (name) VALUES
    ('Aurelia'),
    ('Dermabelle'),
    ('Chromia'),
    ('Naturalis');

INSERT INTO category (name, description) VALUES
    ('Perfumes', 'Fragancias y perfumes'),
    ('Cuidado facial', 'Productos para el cuidado del rostro'),
    ('Solares', 'Productos de protección solar'),
    ('Maquillaje', 'Productos de maquillaje'),
    ('Cuidado capilar', 'Productos para el cabello');

INSERT INTO product (product_code, brand_id, name, description, attributes)
SELECT 'product-001', brand_id, 'Perfume Floral Lumière',
       'Fragancia floral de uso diario',
       '{"familia_olfativa":"floral","genero":"unisex"}'::JSONB
FROM brand WHERE name = 'Aurelia';

INSERT INTO product (product_code, brand_id, name, description, attributes)
SELECT 'product-002', brand_id, 'Eau de Parfum Nocturne',
       'Fragancia intensa con notas amaderadas',
       '{"familia_olfativa":"amaderada","momento":"noche"}'::JSONB
FROM brand WHERE name = 'Aurelia';

INSERT INTO product (product_code, brand_id, name, description, attributes)
SELECT 'product-003', brand_id, 'Crema Hidratante Rosa',
       'Crema facial hidratante con extracto de rosa',
       '{"tipo_de_piel":["seca","normal"],"cruelty_free":true}'::JSONB
FROM brand WHERE name = 'Dermabelle';

INSERT INTO product (product_code, brand_id, name, description, attributes)
SELECT 'product-004', brand_id, 'Protector Solar Facial FPS50',
       'Protector solar facial de amplio espectro',
       '{"factor_solar":50,"resistente_al_agua":true}'::JSONB
FROM brand WHERE name = 'Dermabelle';

INSERT INTO product (product_code, brand_id, name, description, attributes)
SELECT 'product-005', brand_id, 'Labial Mate Carmín',
       'Labial de acabado mate color carmín',
       '{"acabado":"mate","color":"carmín"}'::JSONB
FROM brand WHERE name = 'Chromia';

INSERT INTO product (product_code, brand_id, name, description, attributes)
SELECT 'product-006', brand_id, 'Base Fluida Natural',
       'Base fluida de cobertura media',
       '{"acabado":"natural","cobertura":"media"}'::JSONB
FROM brand WHERE name = 'Chromia';

INSERT INTO product (product_code, brand_id, name, description, attributes)
SELECT 'product-007', brand_id, 'Shampoo Nutritivo Argán',
       'Shampoo nutritivo con aceite de argán',
       '{"tipo_de_cabello":["seco","dañado"],"sin_parabenos":true}'::JSONB
FROM brand WHERE name = 'Naturalis';

INSERT INTO product (product_code, brand_id, name, description, attributes)
SELECT 'product-008', brand_id, 'Acondicionador Nutritivo Argán',
       'Acondicionador nutritivo con aceite de argán',
       '{"tipo_de_cabello":["seco","dañado"],"sin_parabenos":true}'::JSONB
FROM brand WHERE name = 'Naturalis';

INSERT INTO product_category (product_id, category_id, is_primary)
SELECT p.product_id, c.category_id, TRUE
FROM product p
JOIN category c ON c.name = 'Perfumes'
WHERE p.name IN ('Perfume Floral Lumière', 'Eau de Parfum Nocturne');

INSERT INTO product_category (product_id, category_id, is_primary)
SELECT p.product_id, c.category_id, TRUE
FROM product p
JOIN category c ON c.name = 'Cuidado facial'
WHERE p.name IN ('Crema Hidratante Rosa', 'Protector Solar Facial FPS50');

INSERT INTO product_category (product_id, category_id, is_primary)
SELECT p.product_id, c.category_id, FALSE
FROM product p
JOIN category c ON c.name = 'Solares'
WHERE p.name = 'Protector Solar Facial FPS50';

INSERT INTO product_category (product_id, category_id, is_primary)
SELECT p.product_id, c.category_id, TRUE
FROM product p
JOIN category c ON c.name = 'Maquillaje'
WHERE p.name IN ('Labial Mate Carmín', 'Base Fluida Natural');

INSERT INTO product_category (product_id, category_id, is_primary)
SELECT p.product_id, c.category_id, TRUE
FROM product p
JOIN category c ON c.name = 'Cuidado capilar'
WHERE p.name IN ('Shampoo Nutritivo Argán', 'Acondicionador Nutritivo Argán');

INSERT INTO sku (product_id, sku_code, presentation, size_value, size_unit)
SELECT product_id, 'AUR-LUM-050', 'Frasco de 50 ml', 50, 'ml'
FROM product WHERE name = 'Perfume Floral Lumière';

INSERT INTO sku (product_id, sku_code, presentation, size_value, size_unit)
SELECT product_id, 'AUR-LUM-100', 'Frasco de 100 ml', 100, 'ml'
FROM product WHERE name = 'Perfume Floral Lumière';

INSERT INTO sku (product_id, sku_code, presentation, size_value, size_unit)
SELECT product_id, 'AUR-NOC-050', 'Frasco de 50 ml', 50, 'ml'
FROM product WHERE name = 'Eau de Parfum Nocturne';

INSERT INTO sku (product_id, sku_code, presentation, size_value, size_unit)
SELECT product_id, 'DER-ROS-050', 'Pote de 50 ml', 50, 'ml'
FROM product WHERE name = 'Crema Hidratante Rosa';

INSERT INTO sku (product_id, sku_code, presentation, size_value, size_unit)
SELECT product_id, 'DER-SOL-050', 'Pomo de 50 ml', 50, 'ml'
FROM product WHERE name = 'Protector Solar Facial FPS50';

INSERT INTO sku (product_id, sku_code, presentation, attributes)
SELECT product_id, 'CHR-LAB-CAR', 'Unidad',
       '{"color":"carmín","acabado":"mate"}'::JSONB
FROM product WHERE name = 'Labial Mate Carmín';

INSERT INTO sku (product_id, sku_code, presentation, size_value, size_unit, attributes)
SELECT product_id, 'CHR-BAS-030-N', 'Frasco de 30 ml - tono neutral', 30, 'ml',
       '{"tono":"neutral"}'::JSONB
FROM product WHERE name = 'Base Fluida Natural';

INSERT INTO sku (product_id, sku_code, presentation, size_value, size_unit)
SELECT product_id, 'NAT-SHA-300', 'Botella de 300 ml', 300, 'ml'
FROM product WHERE name = 'Shampoo Nutritivo Argán';

INSERT INTO sku (product_id, sku_code, presentation, size_value, size_unit)
SELECT product_id, 'NAT-ACO-300', 'Botella de 300 ml', 300, 'ml'
FROM product WHERE name = 'Acondicionador Nutritivo Argán';

-- Una segunda variante de tono permite validar que un producto tenga varios SKU.
INSERT INTO sku (product_id, sku_code, presentation, size_value, size_unit, attributes)
SELECT product_id, 'CHR-BAS-030-C', 'Frasco de 30 ml - tono cálido', 30, 'ml',
       '{"tono":"cálido"}'::JSONB
FROM product WHERE name = 'Base Fluida Natural';

INSERT INTO sku_price (sku_id, amount, currency, valid_from)
SELECT sku_id,
       CASE sku_code
           WHEN 'AUR-LUM-050' THEN 95000
           WHEN 'AUR-LUM-100' THEN 145000
           WHEN 'AUR-NOC-050' THEN 110000
           WHEN 'DER-ROS-050' THEN 28000
           WHEN 'DER-SOL-050' THEN 32000
           WHEN 'CHR-LAB-CAR' THEN 18000
           WHEN 'CHR-BAS-030-N' THEN 35000
           WHEN 'CHR-BAS-030-C' THEN 35000
           WHEN 'NAT-SHA-300' THEN 15000
           WHEN 'NAT-ACO-300' THEN 15500
       END,
       'ARS',
       TIMESTAMPTZ '2026-08-01 00:00:00-03'
FROM sku;

INSERT INTO inventory (sku_id, available_qty, low_stock_threshold)
SELECT sku_id,
       0,
       CASE sku_code
           WHEN 'AUR-LUM-100' THEN 4
           WHEN 'CHR-BAS-030-N' THEN 3
           ELSE 2
       END
FROM sku;

-- Los ingresos iniciales alimentan el stock mediante el trigger auditable.
INSERT INTO inventory_movement (sku_id, movement_type, quantity_change, reason, occurred_at)
SELECT sku_id,
       'receipt',
       CASE sku_code
           WHEN 'AUR-LUM-050' THEN 12
           WHEN 'AUR-LUM-100' THEN 4
           WHEN 'AUR-NOC-050' THEN 8
           WHEN 'DER-ROS-050' THEN 10
           WHEN 'DER-SOL-050' THEN 6
           WHEN 'CHR-LAB-CAR' THEN 9
           WHEN 'CHR-BAS-030-N' THEN 3
           WHEN 'CHR-BAS-030-C' THEN 5
           WHEN 'NAT-SHA-300' THEN 10
           WHEN 'NAT-ACO-300' THEN 10
       END,
       'Stock inicial sintético',
       TIMESTAMPTZ '2026-08-01 09:00:00-03'
FROM sku;

-- ---------------------------------------------------------------------------
-- Clientes y sesiones
-- ---------------------------------------------------------------------------

INSERT INTO customer (customer_code, full_name, email, phone) VALUES
    ('user-123', 'Ana Torres', 'ana.torres@example.test', '+54 11 5555 0101'),
    ('user-124', 'Bruno Díaz', 'bruno.diaz@example.test', '+54 11 5555 0102'),
    ('user-125', 'Carla Méndez', 'carla.mendez@example.test', '+54 11 5555 0103'),
    ('user-126', 'Diego Ruiz', 'diego.ruiz@example.test', '+54 11 5555 0104'),
    ('user-127', 'Elena Soto', 'elena.soto@example.test', '+54 11 5555 0105');

INSERT INTO customer_session (session_id, session_code, customer_id, started_at, ended_at)
SELECT '00000000-0000-0000-0000-000000000101'::UUID,
       'session-456',
       customer_id,
       TIMESTAMPTZ '2026-08-23 10:00:00-03',
       TIMESTAMPTZ '2026-08-23 10:45:00-03'
FROM customer WHERE email = 'ana.torres@example.test';

INSERT INTO customer_session (session_id, session_code, customer_id, started_at, ended_at)
SELECT '00000000-0000-0000-0000-000000000102'::UUID,
       'session-457',
       customer_id,
       TIMESTAMPTZ '2026-08-23 12:00:00-03',
       TIMESTAMPTZ '2026-08-23 12:25:00-03'
FROM customer WHERE email = 'bruno.diaz@example.test';

INSERT INTO customer_session (session_id, session_code, customer_id, started_at, ended_at)
SELECT '00000000-0000-0000-0000-000000000103'::UUID,
       'session-458',
       customer_id,
       TIMESTAMPTZ '2026-08-24 18:00:00-03',
       TIMESTAMPTZ '2026-08-24 18:40:00-03'
FROM customer WHERE email = 'carla.mendez@example.test';

INSERT INTO customer_session (session_id, session_code, customer_id, started_at)
SELECT '00000000-0000-0000-0000-000000000104'::UUID,
       'session-459',
       customer_id,
       TIMESTAMPTZ '2026-08-25 08:00:00-03'
FROM customer WHERE email = 'elena.soto@example.test';

INSERT INTO customer_session (session_id, session_code, customer_id, started_at, ended_at) VALUES
    ('00000000-0000-0000-0000-000000000199', 'session-460', NULL,
     TIMESTAMPTZ '2026-08-24 20:00:00-03',
     TIMESTAMPTZ '2026-08-24 20:30:00-03');

-- ---------------------------------------------------------------------------
-- Pedidos e ítems. Los triggers recalculan total_amount.
-- ---------------------------------------------------------------------------

INSERT INTO sales_order
    (customer_id, ordered_at, order_status, payment_status, shipping_status, currency)
SELECT customer_id, TIMESTAMPTZ '2026-08-10 11:00:00-03',
       'completed', 'approved', 'delivered', 'ARS'
FROM customer WHERE email = 'ana.torres@example.test';

INSERT INTO sales_order
    (customer_id, ordered_at, order_status, payment_status, shipping_status, currency)
SELECT customer_id, TIMESTAMPTZ '2026-08-12 14:30:00-03',
       'completed', 'approved', 'delivered', 'ARS'
FROM customer WHERE email = 'bruno.diaz@example.test';

INSERT INTO sales_order
    (customer_id, ordered_at, order_status, payment_status, shipping_status, currency)
SELECT customer_id, TIMESTAMPTZ '2026-08-15 16:20:00-03',
       'completed', 'approved', 'delivered', 'ARS'
FROM customer WHERE email = 'carla.mendez@example.test';

INSERT INTO sales_order
    (customer_id, ordered_at, order_status, payment_status, shipping_status, currency)
SELECT customer_id, TIMESTAMPTZ '2026-08-20 09:10:00-03',
       'completed', 'approved', 'delivered', 'ARS'
FROM customer WHERE email = 'diego.ruiz@example.test';

INSERT INTO sales_order
    (customer_id, ordered_at, order_status, payment_status, shipping_status, currency)
SELECT customer_id, TIMESTAMPTZ '2026-08-22 17:40:00-03',
       'cancelled', 'refunded', 'cancelled', 'ARS'
FROM customer WHERE email = 'ana.torres@example.test';

INSERT INTO order_item (order_id, sku_id, quantity, unit_price_applied)
SELECT so.order_id, s.sku_id, 1, 95000
FROM sales_order so
JOIN customer c ON c.customer_id = so.customer_id
JOIN sku s ON s.sku_code = 'AUR-LUM-050'
WHERE c.email = 'ana.torres@example.test'
  AND so.ordered_at = TIMESTAMPTZ '2026-08-10 11:00:00-03';

INSERT INTO order_item (order_id, sku_id, quantity, unit_price_applied)
SELECT so.order_id, s.sku_id, 1, 28000
FROM sales_order so
JOIN customer c ON c.customer_id = so.customer_id
JOIN sku s ON s.sku_code = 'DER-ROS-050'
WHERE c.email = 'ana.torres@example.test'
  AND so.ordered_at = TIMESTAMPTZ '2026-08-10 11:00:00-03';

INSERT INTO order_item (order_id, sku_id, quantity, unit_price_applied)
SELECT so.order_id, s.sku_id, 1, 95000
FROM sales_order so
JOIN customer c ON c.customer_id = so.customer_id
JOIN sku s ON s.sku_code = 'AUR-LUM-050'
WHERE c.email = 'bruno.diaz@example.test'
  AND so.ordered_at = TIMESTAMPTZ '2026-08-12 14:30:00-03';

INSERT INTO order_item (order_id, sku_id, quantity, unit_price_applied)
SELECT so.order_id, s.sku_id, 2, 18000
FROM sales_order so
JOIN customer c ON c.customer_id = so.customer_id
JOIN sku s ON s.sku_code = 'CHR-LAB-CAR'
WHERE c.email = 'bruno.diaz@example.test'
  AND so.ordered_at = TIMESTAMPTZ '2026-08-12 14:30:00-03';

INSERT INTO order_item (order_id, sku_id, quantity, unit_price_applied)
SELECT so.order_id, s.sku_id, 1, 145000
FROM sales_order so
JOIN customer c ON c.customer_id = so.customer_id
JOIN sku s ON s.sku_code = 'AUR-LUM-100'
WHERE c.email = 'carla.mendez@example.test'
  AND so.ordered_at = TIMESTAMPTZ '2026-08-15 16:20:00-03';

INSERT INTO order_item (order_id, sku_id, quantity, unit_price_applied)
SELECT so.order_id, s.sku_id, 1, 28000
FROM sales_order so
JOIN customer c ON c.customer_id = so.customer_id
JOIN sku s ON s.sku_code = 'DER-ROS-050'
WHERE c.email = 'carla.mendez@example.test'
  AND so.ordered_at = TIMESTAMPTZ '2026-08-15 16:20:00-03';

INSERT INTO order_item (order_id, sku_id, quantity, unit_price_applied)
SELECT so.order_id, s.sku_id, 1, 18000
FROM sales_order so
JOIN customer c ON c.customer_id = so.customer_id
JOIN sku s ON s.sku_code = 'CHR-LAB-CAR'
WHERE c.email = 'carla.mendez@example.test'
  AND so.ordered_at = TIMESTAMPTZ '2026-08-15 16:20:00-03';

INSERT INTO order_item (order_id, sku_id, quantity, unit_price_applied)
SELECT so.order_id, s.sku_id, 1, 15000
FROM sales_order so
JOIN customer c ON c.customer_id = so.customer_id
JOIN sku s ON s.sku_code = 'NAT-SHA-300'
WHERE c.email = 'diego.ruiz@example.test'
  AND so.ordered_at = TIMESTAMPTZ '2026-08-20 09:10:00-03';

INSERT INTO order_item (order_id, sku_id, quantity, unit_price_applied)
SELECT so.order_id, s.sku_id, 1, 15500
FROM sales_order so
JOIN customer c ON c.customer_id = so.customer_id
JOIN sku s ON s.sku_code = 'NAT-ACO-300'
WHERE c.email = 'diego.ruiz@example.test'
  AND so.ordered_at = TIMESTAMPTZ '2026-08-20 09:10:00-03';

INSERT INTO order_item (order_id, sku_id, quantity, unit_price_applied)
SELECT so.order_id, s.sku_id, 1, 35000
FROM sales_order so
JOIN customer c ON c.customer_id = so.customer_id
JOIN sku s ON s.sku_code = 'CHR-BAS-030-N'
WHERE c.email = 'ana.torres@example.test'
  AND so.ordered_at = TIMESTAMPTZ '2026-08-22 17:40:00-03';

-- Solo los pedidos completados producen movimientos de venta.
INSERT INTO inventory_movement
    (sku_id, order_id, movement_type, quantity_change, reason, occurred_at)
SELECT oi.sku_id,
       so.order_id,
       'sale',
       -oi.quantity,
       'Venta sintética completada',
       so.ordered_at
FROM sales_order so
JOIN order_item oi ON oi.order_id = so.order_id
WHERE so.order_status = 'completed'
  AND so.payment_status = 'approved';

-- ---------------------------------------------------------------------------
-- Reseñas y recomendaciones sintéticas
-- ---------------------------------------------------------------------------

INSERT INTO review
    (customer_id, product_id, rating, review_text, moderation_status, created_at)
SELECT c.customer_id, p.product_id, 5,
       'Fragancia agradable y duradera.', 'approved',
       TIMESTAMPTZ '2026-08-18 10:00:00-03'
FROM customer c
CROSS JOIN product p
WHERE c.email = 'ana.torres@example.test'
  AND p.name = 'Perfume Floral Lumière';

INSERT INTO review
    (customer_id, product_id, rating, review_text, moderation_status, created_at)
SELECT c.customer_id, p.product_id, 4,
       'Buena hidratación y textura liviana.', 'approved',
       TIMESTAMPTZ '2026-08-19 11:00:00-03'
FROM customer c
CROSS JOIN product p
WHERE c.email = 'carla.mendez@example.test'
  AND p.name = 'Crema Hidratante Rosa';

INSERT INTO recommendation
    (customer_id, session_id, generated_at, method, model_version, context)
SELECT c.customer_id,
       '00000000-0000-0000-0000-000000000101'::UUID,
       TIMESTAMPTZ '2026-08-23 10:30:00-03',
       'synthetic_cross_sell',
       'demo-v1',
       '{"page":"home"}'::JSONB
FROM customer c
WHERE c.email = 'ana.torres@example.test';

INSERT INTO recommendation
    (session_id, generated_at, method, model_version, context)
VALUES
    ('00000000-0000-0000-0000-000000000199',
     TIMESTAMPTZ '2026-08-24 20:10:00-03',
     'synthetic_session_context',
     'demo-v1',
     '{"page":"search_results"}'::JSONB);

INSERT INTO recommendation_item
    (recommendation_id, sku_id, position, score, reason)
SELECT r.recommendation_id, s.sku_id, 1, 0.920000,
       'Producto visto recientemente'
FROM recommendation r
JOIN sku s ON s.sku_code = 'DER-SOL-050'
WHERE r.generated_at = TIMESTAMPTZ '2026-08-23 10:30:00-03';

INSERT INTO recommendation_item
    (recommendation_id, sku_id, position, score, reason)
SELECT r.recommendation_id, s.sku_id, 2, 0.850000,
       'Interés en fragancias'
FROM recommendation r
JOIN sku s ON s.sku_code = 'AUR-NOC-050'
WHERE r.generated_at = TIMESTAMPTZ '2026-08-23 10:30:00-03';

INSERT INTO recommendation_item
    (recommendation_id, sku_id, position, score, reason)
SELECT r.recommendation_id, s.sku_id, 1, 0.900000,
       'Coincide con la búsqueda de la sesión'
FROM recommendation r
JOIN sku s ON s.sku_code = 'NAT-SHA-300'
WHERE r.generated_at = TIMESTAMPTZ '2026-08-24 20:10:00-03';

INSERT INTO recommendation_item
    (recommendation_id, sku_id, position, score, reason)
SELECT r.recommendation_id, s.sku_id, 2, 0.820000,
       'Producto complementario'
FROM recommendation r
JOIN sku s ON s.sku_code = 'NAT-ACO-300'
WHERE r.generated_at = TIMESTAMPTZ '2026-08-24 20:10:00-03';

COMMIT;
