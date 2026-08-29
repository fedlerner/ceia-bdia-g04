# Datos semiestructurados, no estructurados y búsqueda vectorial

> Corresponde al punto 9 de la consigna, que pide analizar si el caso tiene datos de este tipo, cómo
> conviene representarlos y si requiere búsqueda por similitud. La consigna aclara que **no es
> obligatorio implementar embeddings, pero sí justificar si el caso los requiere o no**.

## 1. Qué aparece en el caso

La consigna enumera once tipos de dato a considerar. En el caso, una tienda de cosmética y
perfumería, aparecen estos:

| Tipo | ¿Aparece? | Dónde, en la implementación |
| --- | --- | --- |
| Documentos | No | El caso no maneja contratos, manuales ni fichas extensas. Si más adelante se incorporaran fichas de ingredientes, serían el candidato natural a vectorizar. |
| Fragmentos de texto | Sí | `product.description` (`Fragancia floral de uso diario`) y `review.review_text` (`Fragancia agradable y duradera.`) en PostgreSQL. |
| Configuraciones variables | Sí | `product.attributes` y `sku.attributes`, `jsonb`. Por ejemplo `{"genero": "unisex", "familia_olfativa": "floral"}`. |
| Eventos | Sí | La colección `user_events` de MongoDB, 22 eventos de cuatro tipos. |
| Logs | No como tal | No se modela una bitácora técnica. `inventory_movement` es una bitácora **de negocio**: inmutable, auditable y con su propia validación. |
| Comentarios | Sí | El texto libre de las reseñas, la misma columna que la fila de fragmentos de texto. |
| Reseñas | Sí | La tabla `review`, con calificación acotada por `review_rating_ck` y texto libre. |
| Metadatos | Sí | `metadata` en los eventos de MongoDB, distinta según el tipo, y `recommendation.context` (`{"page": "home"}`) en PostgreSQL. |
| Atributos cambiantes | Sí | Los mismos `attributes` en `jsonb`, que admiten un atributo nuevo sin migrar la tabla. |
| Relaciones jerárquicas | Sí | Producto a SKU, y producto a categoría como N:M con una principal. `product_category` la garantiza con un índice único **parcial**, `product_one_primary_category_uq`, sobre `product_id` con `WHERE is_primary`. |
| Relaciones altamente conectadas | No | No hay red social, ni recomendación entre usuarios, ni grafo de navegación que justifique una base de grafos. |

## 2. Cómo se representa cada uno, y por qué

La decisión no es única para todos: cada tipo va a la tecnología que resuelve su patrón de acceso.

- **`jsonb` dentro de PostgreSQL** para los atributos variables del catálogo. Conviven en la misma
  fila que el precio y el stock, se consultan junto con ellos en una sola transacción y no justifican
  una base aparte. Llevan índices GIN (`product_attributes_gin_idx`, `sku_attributes_gin_idx`), de
  modo que la flexibilidad no cuesta un recorrido completo de la tabla.
- **Colección documental en MongoDB** para los eventos. Su volumen crece de forma continua, su
  `metadata` cambia según el tipo y las consultas son por usuario y ventana temporal. El detalle está
  en [`../nosql/modelo_nosql.md`](../nosql/modelo_nosql.md), sección 1.
- **Texto en columnas relacionales** para descripciones y reseñas. Hoy se leen y se muestran, no se
  procesan semánticamente.
- **Nada en una base de grafos**, porque el caso no presenta relaciones altamente conectadas.

## 3. ¿El caso requiere búsqueda vectorial?

Para el alcance mínimo, no. Las consultas que hoy alimentan al motor se resuelven por identificador y
por rango temporal: qué vio un cliente, qué compró, qué productos se ven más. Un índice B-tree y el
índice automático de la Time Series Collection alcanzan para eso, y un vector no aportaría nada.

Para lo que el caso dice querer resolver, sí. Hay tres necesidades que el alcance mínimo no cubre:

1. **Producto parecido a este.** Hoy la única noción de parecido es compartir categoría, que es
   demasiado gruesa: `product-001` y `product-002` son ambos perfumes, pero uno es floral de uso
   diario y el otro amaderado de noche. Eso está en la descripción y en `attributes`, no en la
   categoría.
2. **Búsqueda en lenguaje natural.** Los eventos `search` guardan la consulta escrita por la persona,
   por ejemplo `{"query": "perfume floral", "results_count": 18}`. Resolverla por coincidencia de
   términos falla con sinónimos y con descripciones que no repiten la palabra buscada.
3. **Arranque en frío.** Un cliente sin historial no tiene eventos de los que derivar
   recomendaciones. La similitud entre el producto que está mirando y el resto del catálogo permite
   recomendar sin historial.

Decidimos dejarlo fuera de esta entrega y documentar el diseño. Incorporar embeddings exigiría
elegir un modelo de representación, montar el proceso que los genera y reindexar ante cada cambio del
catálogo. Eso es trabajo de una versión siguiente, no del diseño de la capa de datos que pide el
trabajo.

## 4. Qué datos se vectorizarían

| Fuente | Unidad a vectorizar | Volumen esperado |
| --- | --- | --- |
| `product.description` más los valores de `product.attributes` | Un vector por producto, con la descripción y los atributos concatenados en un texto breve | Del orden del catálogo: ocho hoy, miles en producción |
| `review.review_text` | Un vector por reseña | Crece con las ventas; es el conjunto que más crece |
| `metadata.query` de los eventos `search` de MongoDB | Un vector por consulta distinta, no por evento | Acotado por la cantidad de búsquedas distintas |

Las descripciones del caso son breves, de una o dos oraciones, así que **no requieren fragmentación**:
cada producto entra en un solo vector. La fragmentación sería necesaria recién si se incorporaran
fichas de ingredientes o manuales, que hoy no existen en el caso.

## 5. Qué consultas se podrían hacer

- Los `k` productos más cercanos a un producto dado, para la sección "productos similares".
- Los `k` productos más cercanos al vector de la consulta escrita por la persona, para la búsqueda en
  lenguaje natural.
- Las reseñas más cercanas a una consulta, para responder "qué opinan de la duración de este perfume"
  sin leer todas.
- La misma búsqueda **filtrada** por las condiciones del negocio: solo productos activos y con stock,
  que es lo que ya expresa la vista `v_active_catalog`.

Ese último punto es el que determina dónde vivirían los vectores. Como toda consulta útil combina
similitud con una condición relacional, conviene que el vector esté **en PostgreSQL, junto al dato que
lo filtra**, y no en un motor vectorial aparte que obligaría a resolver el filtro en la aplicación.
La extensión `pgvector` cubre el caso: una columna `vector(n)` con la dimensión del modelo elegido y
un índice HNSW con `vector_cosine_ops` para la distancia coseno, que es la habitual en modelos de
texto. A modo de referencia, un modelo de la familia E5 produce vectores de 384 dimensiones.

## 6. Qué metadatos deben acompañar a cada vector

El vector por sí solo no permite decidir si un resultado es utilizable. Cada uno debe guardarse con:

- **El código compartido de la entidad de origen**: `product_code`, `sku_code` o el identificador de
  la reseña, siguiendo la convención de
  [`../docs/modelo_logico_relacional.md`](../docs/modelo_logico_relacional.md).
- **El tipo de fuente**, para no mezclar un vector de descripción con uno de reseña en el mismo
  ranking.
- **La versión del modelo de embeddings y la dimensión.** Sin esto no se puede saber si dos vectores
  son comparables, y un cambio de modelo obliga a regenerar todo el conjunto.
- **La fecha de generación y un resumen del texto de origen**, para detectar vectores que quedaron
  atrás respecto del texto que representan.
- **El idioma**, porque un mismo catálogo puede tener descripciones en más de uno.
- **El estado del negocio en el momento de la consulta**, que no se guarda en el vector sino que se
  resuelve por `JOIN` contra `product` e `inventory`. Guardarlo dentro del vector lo dejaría
  desactualizado en cuanto cambiara el stock.

## 7. Qué riesgos aparecen

| Riesgo | Cómo se manifestaría en este caso | Mitigación prevista |
| --- | --- | --- |
| Recuperar algo **no disponible** | Recomendar un producto inactivo o sin stock porque su vector sigue siendo el más cercano | Filtrar siempre por las condiciones del negocio en la misma consulta, como hace `v_active_catalog`. El vector ordena candidatos; no decide qué se puede vender. |
| Recuperar algo **desactualizado** | Cambia la descripción o la fórmula de un producto y su vector sigue representando el texto anterior | Registrar la fecha de generación y regenerar ante cada cambio del texto de origen. Un vector sin regenerar es una respuesta incorrecta con apariencia de correcta. |
| Recuperar algo **no autorizado** | Que una consulta devuelva el texto de una reseña junto con datos del cliente que la escribió | Los vectores de reseñas no deben incorporar ni el nombre ni el correo del cliente. El control de acceso sigue siendo el del motor: los roles de PostgreSQL, donde `bdia_analyst` no tiene ningún privilegio sobre `customer` ni `review`. |
| **Modelo desalineado** | Comparar vectores generados con modelos distintos produce un ranking sin sentido | La versión del modelo forma parte del metadato y de la clave de reindexado. |
| **Falsa confianza** | Presentar el resultado más cercano como si fuera el correcto | La similitud es una señal, no una verdad. El motor combina esa señal con el comportamiento observado en MongoDB y con el estado del negocio en PostgreSQL. |
| **Exposición vía una aplicación de IA** | Que un asistente reciba fragmentos recuperados y los repita sin filtrar | Es el mismo riesgo que registra la sección 13 del informe: el modelo no debe recibir credenciales de base, y la recuperación debe estar acotada por el mismo control de acceso que la consulta directa. |

## 8. Cómo se implementaría, si se incorporara

Un boceto mínimo, coherente con el modelo actual y sin abrir otro motor:

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE product_embedding (
    product_id     BIGINT PRIMARY KEY REFERENCES product (product_id),
    source_text    TEXT        NOT NULL,
    model_name     TEXT        NOT NULL,
    model_dim      INT         NOT NULL,
    language       TEXT        NOT NULL,
    generated_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    embedding      vector(384) NOT NULL
);

CREATE INDEX product_embedding_cosine_idx
    ON product_embedding USING hnsw (embedding vector_cosine_ops);
```

La consulta de "productos similares disponibles" combinaría similitud y estado en una sola
sentencia:

```sql
SELECT vac.product_code, vac.product_name, pe.embedding <=> :consulta AS distancia
FROM product_embedding pe
JOIN v_active_catalog vac ON vac.product_id = pe.product_id
ORDER BY pe.embedding <=> :consulta
LIMIT 5;
```

El operador `<=>` es la distancia coseno de `pgvector`. La vista aporta el filtro de negocio, de modo
que ningún producto inactivo o sin stock puede aparecer en el resultado por muy cercano que esté su
vector.
