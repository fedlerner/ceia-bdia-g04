# Catálogo canónico de datos ficticios

PostgreSQL es la fuente principal del catálogo. MongoDB y Redis deben referenciar
los productos mediante `product_code` y las variantes mediante `sku_code`; las
claves numéricas `product_id` y `sku_id` son internas de PostgreSQL.

El mismo contrato se aplica a clientes, sesiones y pedidos: `customer_code`,
`session_code` y `order_code` son compartidos; sus claves internas no salen de PostgreSQL. El evento
de compra de ejemplo referencia `order-321`.

| product_code | Producto | Marca | Categoría principal | SKU |
| --- | --- | --- | --- | --- |
| `product-001` | Perfume Floral Lumière | Aurelia | Perfumes | `AUR-LUM-050`, `AUR-LUM-100` |
| `product-002` | Eau de Parfum Nocturne | Aurelia | Perfumes | `AUR-NOC-050` |
| `product-003` | Crema Hidratante Rosa | Dermabelle | Cuidado facial | `DER-ROS-050` |
| `product-004` | Protector Solar Facial FPS50 | Dermabelle | Cuidado facial | `DER-SOL-050` |
| `product-005` | Labial Mate Carmín | Chromia | Maquillaje | `CHR-LAB-CAR` |
| `product-006` | Base Fluida Natural | Chromia | Maquillaje | `CHR-BAS-030-N`, `CHR-BAS-030-C` |
| `product-007` | Shampoo Nutritivo Argán | Naturalis | Cuidado capilar | `NAT-SHA-300` |
| `product-008` | Acondicionador Nutritivo Argán | Naturalis | Cuidado capilar | `NAT-ACO-300` |

`product-004` también pertenece a la categoría secundaria `Solares`. Los tonos
neutral y cálido de `product-006` son atributos de sus SKU, no del producto.

Los ocho productos constituyen datos mínimos de demostración y no un límite del
modelo.

## Sesiones y pedidos compartidos

PostgreSQL es también el dueño de las sesiones y de los pedidos, y MongoDB los referencia. Para que
esa referencia sea verificable, cada evento debe caer dentro de la ventana que `customer_session`
declara para su sesión y corresponder a su mismo cliente.

| `session_code` | Cliente | Ventana (UTC) | Eventos en `user_events` |
| --- | --- | --- | --- |
| `session-461` | `user-123` | 08-18 15:55 a 16:10 | 4 |
| `session-456` | `user-123` | 08-19 15:28 a 15:45 | 6, cierra con la compra de `order-321` |
| `session-457` | `user-124` | 08-23 15:00 a 15:25 | 6, cierra con la compra de `order-322` |
| `session-458` | `user-125` | 08-24 21:00 a 21:40 | 3 |
| `session-459` | `user-127` | 08-25 11:00, abierta | ninguno |
| `session-460` | anónima | 08-24 23:00 a 23:30 | 3 |

Dos decisiones sobre estos datos merecen quedar escritas, porque no son evidentes al leer el seed.

`session-461` existe porque `user-123` navega en dos momentos distintos. El cliente que vuelve es el
caso que motiva la recomendación personalizada, así que preferimos completar PostgreSQL con esa
segunda sesión antes que recortar el historial que registra MongoDB.

`order-322` se registra dentro de la ventana de `session-457`, igual que `order-321` dentro de la de
`session-456`. Las dos compras que modela MongoDB ocurren en el instante exacto de su pedido. Los
otros tres pedidos del seed quedan fuera de toda sesión a propósito: no toda compra nace de una
sesión de navegación registrada, y el esquema no impone esa relación.

`session-459` no registra eventos, que también es válido: no toda sesión genera interacciones
seguidas.
