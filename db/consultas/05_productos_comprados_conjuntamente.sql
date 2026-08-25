-- Consulta 5. Productos comprados conjuntamente
--
-- Pregunta de negocio: ¿Qué productos suelen comprarse junto con un producto determinado?
-- Objetivo: generar recomendaciones de venta cruzada basadas en compras reales.
-- Datos y entidades: pedidos, ítems de pedido, SKU, producto e inventario.
-- Relaciones, filtros y métricas: usa una CTE, relaciones entre pedidos e ítems, agregación COUNT y
--           una subconsulta EXISTS para validar disponibilidad.
-- Resultado esperado: productos activos y disponibles que aparecen con mayor frecuencia en los
--           mismos pedidos que el producto base.
-- Justificación: es especialmente representativa porque utiliza datos transaccionales, relaciona
--           productos mediante pedidos, filtra disponibilidad y apoya recomendaciones de venta
--           cruzada.

SET search_path TO bdia, public;

WITH target_product AS (
  SELECT product_id
  FROM product
  WHERE product_code = 'product-001'
), order_products AS (
  SELECT DISTINCT
    o.order_id,
    s.product_id
  FROM sales_order o
  JOIN order_item oi ON oi.order_id = o.order_id
  JOIN sku s ON s.sku_id = oi.sku_id
  WHERE o.order_status = 'completed'
    AND o.payment_status = 'approved'
)
SELECT
  p2.product_code,
  p2.product_id,
  p2.name AS producto_recomendado,
  COUNT(*) AS pedidos_conjuntos
FROM order_products op1
JOIN order_products op2
  ON op1.order_id = op2.order_id
 AND op1.product_id <> op2.product_id
JOIN product p2 ON p2.product_id = op2.product_id
WHERE op1.product_id = (SELECT product_id FROM target_product)
  AND p2.active = TRUE
  AND EXISTS (
    SELECT 1
    FROM sku s2
    JOIN inventory i2 ON i2.sku_id = s2.sku_id
    WHERE s2.product_id = p2.product_id
      AND s2.active = TRUE
      AND i2.available_qty > 0
  )
GROUP BY p2.product_id, p2.product_code, p2.name
ORDER BY pedidos_conjuntos DESC
LIMIT 10;
