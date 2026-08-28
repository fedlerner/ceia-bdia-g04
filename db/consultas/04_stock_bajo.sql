-- Consulta 4. Productos y SKU con stock bajo
--
-- Pregunta de negocio: ¿Qué productos requieren reposición o deberían excluirse temporalmente de las
--           recomendaciones?
-- Objetivo: apoyar decisiones de reposición y control de disponibilidad.
-- Datos y entidades: inventario, SKU, producto y marca.
-- Relaciones, filtros y métricas: relaciona inventario, SKU, producto y marca; filtra por estado y
--           umbral; ordena por disponibilidad.
-- Resultado esperado: lista ordenada de SKU con stock igual o inferior al umbral definido.
-- Justificación: es una consulta de decisión operativa y puede ayudar a evitar recomendaciones de
--           productos próximos a agotarse. Podría justificar un índice sobre
--           inventory(available_qty) si el volumen lo requiriera.

SET search_path TO bdia, public;

SELECT
  s.sku_id,
  s.sku_code,
  p.product_code,
  p.name AS producto,
  b.name AS marca,
  i.available_qty,
  i.low_stock_threshold
FROM inventory i
JOIN sku s ON s.sku_id = i.sku_id
JOIN product p ON p.product_id = s.product_id
JOIN brand b ON b.brand_id = p.brand_id
WHERE p.active = TRUE
  AND b.active = TRUE
  AND s.active = TRUE
  AND i.available_qty <= i.low_stock_threshold
ORDER BY i.available_qty ASC, p.name;
