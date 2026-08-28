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
