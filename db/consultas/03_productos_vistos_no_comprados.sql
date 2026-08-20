-- Consulta 3. Productos vistos pero todavía no comprados
--
-- Pregunta de negocio: ¿Qué productos visitó recientemente un cliente y todavía no compró?
-- Objetivo: identificar candidatos para recomendaciones personalizadas.
-- Datos y entidades: cliente, eventos, producto, pedidos e ítems de pedido.
-- Relaciones, filtros y métricas: filtra cliente, tipo y fecha; utiliza una subconsulta NOT EXISTS
--           para excluir productos ya comprados.
-- Resultado esperado: productos activos visitados durante los últimos 30 días que no aparecen en
--           compras completadas del cliente.
-- Justificación: justifica un índice sobre (customer_id, event_type, occurred_at) en la tabla de
--           eventos. La variante para sesiones anónimas queda como ampliación.
--
-- Nota: esta versión asume los eventos en PostgreSQL (tabla interaction_event). La variante sobre
--       MongoDB está documentada en nosql/modelo_nosql.md.

SELECT DISTINCT
  p.product_id,
  p.name AS producto,
  MAX(e.occurred_at) AS ultima_visita
FROM interaction_event e
JOIN product p ON p.product_id = e.product_id
WHERE e.customer_id = :customer_id
  AND e.event_type = 'product_view'
  AND e.occurred_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
  AND p.active = TRUE
  AND NOT EXISTS (
    SELECT 1
    FROM sales_order o
    JOIN order_item oi ON oi.order_id = o.order_id
    JOIN sku s ON s.sku_id = oi.sku_id
    WHERE o.customer_id = :customer_id
      AND o.order_status = 'completed'
      AND s.product_id = p.product_id
  )
GROUP BY p.product_id, p.name
ORDER BY ultima_visita DESC
LIMIT 10;
