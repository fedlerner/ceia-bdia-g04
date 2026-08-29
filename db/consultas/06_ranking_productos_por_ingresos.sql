-- Consulta 6. Ranking de productos por ingresos y moneda
--
-- Pregunta de negocio: ¿Qué productos generan más ingresos y en qué posición
--           queda cada uno dentro de su moneda?
-- Objetivo: ordenar los productos por ingresos y asignarles una posición con una
--           función de ventana, sin una segunda consulta ni una autounión.
-- Datos y entidades: pedido, ítem de pedido, SKU y producto.
-- Relaciones, filtros y métricas: agrega ingresos y unidades por producto sobre
--           pedidos completados y pagados en una CTE; RANK() OVER (PARTITION BY
--           moneda ORDER BY ingresos DESC) da la posición dentro de cada moneda.
-- Resultado esperado: productos de mayor a menor ingreso por moneda, con su
--           posición. Sobre los datos de ejemplo (todos en ARS): product-001 (1),
--           product-003 (2), product-005 (3), product-008 (4), product-007 (5).
-- Justificación: es una consulta de decisión —muestra dónde se concentra la
--           facturación— y justifica el uso de funciones de ventana: la posición
--           se calcula sobre el mismo conjunto agregado, sin recorrerlo de nuevo.

SET search_path TO bdia, public;

WITH product_revenue AS (
  SELECT
    p.product_code,
    p.name                                    AS producto,
    o.currency,
    SUM(oi.quantity)                          AS unidades_vendidas,
    SUM(oi.quantity * oi.unit_price_applied)  AS ingresos
  FROM sales_order o
  JOIN order_item oi ON oi.order_id = o.order_id
  JOIN sku s         ON s.sku_id = oi.sku_id
  JOIN product p     ON p.product_id = s.product_id
  WHERE o.order_status = 'completed'
    AND o.payment_status = 'approved'
  GROUP BY p.product_code, p.name, o.currency
)
SELECT
  product_code,
  producto,
  currency,
  unidades_vendidas,
  ingresos,
  RANK() OVER (
    PARTITION BY currency
    ORDER BY ingresos DESC
  ) AS ranking_ingresos
FROM product_revenue
ORDER BY currency, ingresos DESC, product_code;
