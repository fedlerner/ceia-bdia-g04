-- Consulta 2. Ventas e ingresos por categoría y período
--
-- Pregunta de negocio: ¿Qué categorías generan más unidades vendidas e ingresos durante un período
--           determinado?
-- Objetivo: apoyar decisiones sobre catálogo, reposición y promoción.
-- Datos y entidades: pedido, ítem de pedido, SKU, producto y categoría.
-- Relaciones, filtros y métricas: filtra pedidos completados y fechas; relaciona entidades y utiliza
--           agregaciones.
-- Resultado esperado: ranking de categorías por unidades vendidas e ingresos en el período.
-- Justificación: la categoría principal evita contar dos veces una misma venta cuando un producto
--           pertenece a varias categorías.

SELECT
  c.category_id,
  c.name AS categoria,
  SUM(oi.quantity) AS unidades_vendidas,
  SUM(oi.quantity * oi.unit_price_applied) AS ingresos
FROM sales_order o
JOIN order_item oi ON oi.order_id = o.order_id
JOIN sku s ON s.sku_id = oi.sku_id
JOIN product_category pc
  ON pc.product_id = s.product_id
 AND pc.is_primary = TRUE
JOIN category c ON c.category_id = pc.category_id
WHERE o.order_status = 'completed'
  AND o.ordered_at >= :from_date
  AND o.ordered_at < :to_date
GROUP BY c.category_id, c.name
ORDER BY ingresos DESC;
