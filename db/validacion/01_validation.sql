-- Controles automáticos de la implementación mínima.

SET search_path TO bdia, public;

\echo 'VALIDACIÓN AUTOMÁTICA - Todos los controles deben devolver OK'

WITH validations AS (
    SELECT 1 AS sort_order,
           'Ocho productos de prueba' AS control,
           COUNT(*) = 8 AS passed
    FROM product

    UNION ALL

    SELECT 2,
           'Diez SKU de prueba',
           COUNT(*) = 10
    FROM sku

    UNION ALL

    SELECT 3,
           'Cinco clientes sintéticos',
           COUNT(*) = 5
    FROM customer

    UNION ALL

    SELECT 4,
           'Todos los productos tienen exactamente una categoría principal',
           NOT EXISTS (
               SELECT p.product_id
               FROM product p
               LEFT JOIN product_category pc
                 ON pc.product_id = p.product_id
                AND pc.is_primary = TRUE
               GROUP BY p.product_id
               HAVING COUNT(pc.category_id) <> 1
           )

    UNION ALL

    SELECT 5,
           'Cada SKU tiene exactamente un precio vigente',
           NOT EXISTS (
               SELECT s.sku_id
               FROM sku s
               LEFT JOIN sku_price sp
                 ON sp.sku_id = s.sku_id
                AND sp.valid_from <= CURRENT_TIMESTAMP
                AND (sp.valid_to IS NULL OR sp.valid_to > CURRENT_TIMESTAMP)
               GROUP BY s.sku_id
               HAVING COUNT(sp.price_id) <> 1
           )

    UNION ALL

    SELECT 6,
           'No existe inventario negativo',
           NOT EXISTS (
               SELECT 1 FROM inventory WHERE available_qty < 0
           )

    UNION ALL

    SELECT 7,
           'El stock coincide con la suma de movimientos',
           NOT EXISTS (
               SELECT i.sku_id
               FROM inventory i
               LEFT JOIN inventory_movement im ON im.sku_id = i.sku_id
               GROUP BY i.sku_id, i.available_qty
               HAVING i.available_qty <> COALESCE(SUM(im.quantity_change), 0)
           )

    UNION ALL

    SELECT 8,
           'Los totales de pedidos coinciden con sus ítems',
           NOT EXISTS (
               SELECT so.order_id
               FROM sales_order so
               LEFT JOIN order_item oi ON oi.order_id = so.order_id
               GROUP BY so.order_id, so.total_amount
               HAVING so.total_amount <> COALESCE(SUM(oi.quantity * oi.unit_price_applied), 0)
           )

    UNION ALL

    SELECT 9,
           'Existen cuatro pedidos completados',
           COUNT(*) = 4
    FROM sales_order
    WHERE order_status = 'completed' AND payment_status = 'approved'

    UNION ALL

    SELECT 10,
           'Las recomendaciones tienen cliente o sesión',
           NOT EXISTS (
               SELECT 1
               FROM recommendation
               WHERE customer_id IS NULL AND session_id IS NULL
           )

    UNION ALL

    SELECT 11,
           'La vista de catálogo activo devuelve los diez SKU disponibles',
           COUNT(*) = 10
    FROM v_active_catalog

    UNION ALL

    SELECT 12,
           'El catálogo usa los ocho códigos externos canónicos',
           COUNT(*) = 8
           AND MIN(product_code) = 'product-001'
           AND MAX(product_code) = 'product-008'
    FROM product

    UNION ALL

    SELECT 13,
           'Las variantes de Base Fluida conservan el tono a nivel de SKU',
           COUNT(*) = 2
           AND COUNT(*) FILTER (WHERE attributes ? 'tono') = 2
    FROM sku
    WHERE sku_code IN ('CHR-BAS-030-N', 'CHR-BAS-030-C')

    UNION ALL

    SELECT 14,
           'Clientes y sesiones usan códigos externos canónicos',
           COUNT(*) = 5
           AND COUNT(*) FILTER (WHERE customer_code ~ '^user-[0-9]+$') = 5
           AND (SELECT COUNT(*) FROM customer_session
                WHERE session_code ~ '^session-[0-9]+$') = 5
    FROM customer

    UNION ALL

    SELECT 15,
           'Los movimientos de inventario respetan el signo de su tipo',
           NOT EXISTS (
               SELECT 1
               FROM inventory_movement
               WHERE NOT (
                   (movement_type = 'sale' AND quantity_change < 0)
                   OR (movement_type IN ('receipt', 'return', 'cancellation')
                       AND quantity_change > 0)
                   OR (movement_type = 'adjustment' AND quantity_change <> 0)
               )
           )

    UNION ALL

    SELECT 16,
           'Cliente y sesión de cada recomendación son consistentes',
           NOT EXISTS (
               SELECT 1
               FROM recommendation r
               JOIN customer_session cs ON cs.session_id = r.session_id
               WHERE r.customer_id IS NOT NULL
                 AND cs.customer_id IS DISTINCT FROM r.customer_id
           )

    UNION ALL

    SELECT 17,
           'Las recomendaciones se generan dentro de su sesión',
           NOT EXISTS (
               SELECT 1
               FROM recommendation r
               JOIN customer_session cs ON cs.session_id = r.session_id
               WHERE r.generated_at < cs.started_at
                  OR (cs.ended_at IS NOT NULL AND r.generated_at > cs.ended_at)
           )

    UNION ALL

    SELECT 18,
           'session-456 coincide con la línea temporal canónica',
           COUNT(*) = 1
           AND BOOL_AND(c.customer_code = 'user-123')
           AND BOOL_AND(cs.started_at = TIMESTAMPTZ '2026-08-19 12:28:00-03')
           AND BOOL_AND(cs.ended_at = TIMESTAMPTZ '2026-08-19 12:45:00-03')
    FROM customer_session cs
    JOIN customer c ON c.customer_id = cs.customer_id
    WHERE cs.session_code = 'session-456'

    UNION ALL

    SELECT 19,
           'La vista selecciona el precio efectivo y no el precio futuro',
           COUNT(*) = 1
           AND BOOL_AND(current_price = 95000)
    FROM v_active_catalog
    WHERE sku_code = 'AUR-LUM-050'

    UNION ALL

    SELECT 20,
           'order-321 identifica la compra efectiva de user-123',
           COUNT(*) = 1
           AND BOOL_AND(c.customer_code = 'user-123')
           AND BOOL_AND(so.order_status = 'completed')
           AND BOOL_AND(so.payment_status = 'approved')
           AND BOOL_AND(so.ordered_at = TIMESTAMPTZ '2026-08-19 12:42:00-03')
    FROM sales_order so
    JOIN customer c ON c.customer_id = so.customer_id
    WHERE so.order_code = 'order-321'
)
SELECT
    sort_order,
    control,
    CASE WHEN passed THEN 'OK' ELSE 'ERROR' END AS result
FROM validations
ORDER BY sort_order;

\echo 'RESUMEN DE REGISTROS'
SELECT 'brand' AS entity, COUNT(*) AS records FROM brand
UNION ALL SELECT 'category', COUNT(*) FROM category
UNION ALL SELECT 'product', COUNT(*) FROM product
UNION ALL SELECT 'sku', COUNT(*) FROM sku
UNION ALL SELECT 'customer', COUNT(*) FROM customer
UNION ALL SELECT 'customer_session', COUNT(*) FROM customer_session
UNION ALL SELECT 'sales_order', COUNT(*) FROM sales_order
UNION ALL SELECT 'order_item', COUNT(*) FROM order_item
UNION ALL SELECT 'review', COUNT(*) FROM review
UNION ALL SELECT 'recommendation', COUNT(*) FROM recommendation
UNION ALL SELECT 'recommendation_item', COUNT(*) FROM recommendation_item
ORDER BY entity;
