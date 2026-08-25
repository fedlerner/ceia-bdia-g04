-- Consulta 3. Frecuencia y valor de compra por cliente
--
-- Pregunta de negocio: ¿Qué clientes concentran mayor frecuencia y valor de
-- compra y cuándo realizaron su última operación efectiva?
-- Objetivo: obtener señales transaccionales útiles para segmentación y futuras
-- recomendaciones sin duplicar en PostgreSQL los eventos que pertenecen a MongoDB.
-- Resultado esperado: clientes ordenados por gasto total, con cantidad de
-- pedidos, unidades compradas y fecha de última compra.

SET search_path TO bdia, public;

SELECT
  c.customer_id,
  c.customer_code,
  c.full_name,
  so.currency,
  COUNT(DISTINCT so.order_id) AS pedidos_completados,
  SUM(oi.quantity) AS unidades_compradas,
  SUM(oi.quantity * oi.unit_price_applied) AS valor_total,
  MAX(so.ordered_at) AS ultima_compra
FROM customer c
JOIN sales_order so ON so.customer_id = c.customer_id
JOIN order_item oi ON oi.order_id = so.order_id
WHERE c.active = TRUE
  AND so.order_status = 'completed'
  AND so.payment_status = 'approved'
GROUP BY c.customer_id, c.customer_code, c.full_name, so.currency
ORDER BY valor_total DESC, ultima_compra DESC;
