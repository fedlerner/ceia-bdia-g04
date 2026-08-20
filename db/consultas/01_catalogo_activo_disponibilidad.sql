-- Consulta 1. Catálogo activo con disponibilidad
--
-- Pregunta de negocio: ¿Qué productos activos están disponibles, indicando marca, precio y stock?
-- Objetivo: construir el catálogo que puede mostrarse al cliente y evitar ofrecer productos
--           inactivos o sin disponibilidad.
-- Datos y entidades: producto, marca, SKU e inventario.
-- Relaciones, filtros y métricas: relaciona producto, marca, SKU e inventario; filtra estados
--           activos y agrega precio y stock.
-- Resultado esperado: lista de productos activos con disponibilidad, precio mínimo y stock total.
-- Justificación: es una consulta operativa central. Podría implementarse como una vista, por
--           ejemplo v_active_catalog, si se consultara con frecuencia.

SELECT
  p.product_id,
  p.name AS producto,
  b.name AS marca,
  MIN(s.unit_price) AS precio_desde,
  SUM(i.available_qty) AS stock_total
FROM product p
JOIN brand b ON b.brand_id = p.brand_id
JOIN sku s ON s.product_id = p.product_id
JOIN inventory i ON i.sku_id = s.sku_id
WHERE p.active = TRUE
  AND s.active = TRUE
GROUP BY p.product_id, p.name, b.name
HAVING SUM(i.available_qty) > 0
ORDER BY p.name;
