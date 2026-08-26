# Datos de ejemplo

| Archivo | Contenido |
| --- | --- |
| [`user_events.json`](user_events.json) | Documentos de ejemplo de la colección `user_events` de MongoDB: `product_view`, `search`, `add_to_cart` y `purchase`. |
| [`redis_recommendations.json`](redis_recommendations.json) | Valor de ejemplo de la cache de Redis, almacenado bajo la clave `reco:user:user-123:home` con un TTL de 600 segundos. |

## Datos relacionales relacionados

- Catálogo de ocho productos con marcas, categorías, SKU, precios y stock.
- Clientes, sesiones, pedidos e ítems sintéticos.
- Reseñas y recomendaciones persistentes de ejemplo.

Los identificadores de producto de `redis_recommendations.json` siguen el catálogo ficticio de ocho
productos definido en
[`../../nosql/redis/datos/estado_inicial.redis`](../../nosql/redis/datos/estado_inicial.redis).

`user_events.json` usa `product-001`, el identificador canónico de Perfume Floral Lumière. Los
identificadores `user-123` y `session-456` también coinciden con los códigos externos de PostgreSQL
y con las claves de Redis. El evento `purchase` referencia `order-321`, código externo del pedido
completado y pagado de `user-123` en PostgreSQL.

Los scripts de carga a PostgreSQL van en [`../../db/datos/`](../../db/datos/); el estado inicial de
Redis se carga desde [`../../nosql/redis/`](../../nosql/redis/).
