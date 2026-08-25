# Datos de ejemplo

| Archivo | Contenido |
| --- | --- |
| [`user_events.json`](user_events.json) | Documentos de ejemplo de la colección `user_events` de MongoDB: `product_view`, `search`, `add_to_cart` y `purchase`. |
| [`redis_recommendations.json`](redis_recommendations.json) | Valor de ejemplo de la cache de Redis, almacenado bajo la clave `reco:user:user-123:home` con un TTL de 600 segundos. |

## Pendiente

- [ ] Catálogo de ejemplo con los ocho productos ficticios (marcas, categorías, SKU, precios y stock).
- [ ] Clientes, pedidos e ítems de pedido sintéticos.
- [ ] Reseñas de ejemplo.

Los identificadores de producto de `redis_recommendations.json` siguen el catálogo ficticio de ocho
productos definido en
[`../../nosql/redis/datos/estado_inicial.redis`](../../nosql/redis/datos/estado_inicial.redis).

`user_events.json` todavía usa `product-789`, el identificador de los ejemplos originales del modelo
documental, que no pertenece a ese catálogo. Unificar los identificadores entre los ejemplos de
MongoDB y el catálogo queda pendiente; está anotado en [`../../docs/ESTADO.md`](../../docs/ESTADO.md).

Los scripts de carga a PostgreSQL van en [`../../db/datos/`](../../db/datos/); el estado inicial de
Redis se carga desde [`../../nosql/redis/`](../../nosql/redis/).
