# Informe técnico

**Diseño de una capa de datos para recomendaciones personalizadas**
Tienda online de cosmética y perfumería

Carrera de Especialización en Inteligencia Artificial — FIUBA
Bases de Datos para Inteligencia Artificial — 2026 — Grupo 04

> Este informe sigue el índice de 15 puntos exigido por la consigna. Las secciones 1, 2, 3, 8, 9 y
> parte de la 12 provienen de la bajada general del grupo; las secciones 5, 7 y 12 incorporan la
> primera bajada de modelado (MongoDB y Redis). Las secciones marcadas como **pendiente** todavía no
> fueron desarrolladas por el grupo.
>
> El entregable final debe exportarse como `docs/informe.pdf`.

---

## Resumen ejecutivo

Este trabajo presenta el diseño preliminar de la capa de datos de una única tienda online de
cosmética y perfumería que desea mejorar la experiencia de compra mediante recomendaciones
personalizadas. La propuesta se concentra en la organización, consulta, protección y escalabilidad de
los datos que una solución de IA necesitaría utilizar.

El catálogo se validará inicialmente con ocho productos ficticios, pero el modelo deberá admitir una
cantidad mayor y flexible de productos, marcas, categorías y variantes sin modificar su estructura.
Se diferencian el producto comercial y el SKU o variante vendible; el precio y el stock se controlan
por SKU.

La primera versión se limita a datos estructurados y a cinco consultas representativas sobre el
modelo relacional, más el modelado documental de los eventos de interacción en MongoDB y una cache de
recomendaciones en Redis.

El trabajo no incluye entrenar un modelo de recomendación ni desarrollar una aplicación completa. Su
objetivo es diseñar una base de datos robusta, segura y escalable que pueda servir como soporte para
una solución posterior.

---

## 1. Descripción del caso de uso

### 1.1 Caso de uso seleccionado

El caso de uso seleccionado es una tienda online de cosmética y perfumería que registra su catálogo,
disponibilidad, ventas, comportamiento de navegación y opiniones de clientes para generar
recomendaciones personalizadas y apoyar decisiones comerciales.

Corresponde al caso 2 propuesto por la cátedra (sistema de recomendación para comercio electrónico),
con la impronta propia del rubro cosmética y perfumería.

### 1.2 Problema y objetivo

La tienda necesita integrar información que puede encontrarse dispersa entre el catálogo, el
inventario, los pedidos, las interacciones digitales y las reseñas. Si esos datos no están
relacionados de manera consistente, resulta difícil ofrecer productos disponibles, conservar el
precio histórico de las compras, analizar el comportamiento de los clientes y producir
recomendaciones trazables.

**Objetivo general:** diseñar una solución de datos que permita almacenar, consultar, organizar,
proteger y escalar la información necesaria para que una futura solución de recomendaciones
personalizadas opere de manera robusta.

### 1.3 Alcance mínimo

- Una única tienda online.
- Catálogo extensible de marcas, categorías, productos y SKU o variantes.
- Precios vigentes y stock disponible por SKU.
- Clientes, pedidos e ítems de pedido.
- Estados simples del pedido, del pago y del envío.
- Eventos de navegación y búsqueda asociados a clientes identificados o a sesiones anónimas.
- Reseñas y calificaciones.
- Consultas comerciales y de personalización.
- Roles, permisos básicos y datos sintéticos para validar el modelo.

### 1.4 Usuarios principales

Clientes que compran, administradores que gestionan el catálogo, operadores que actualizan precios o
stock, y analistas que consultan indicadores comerciales. También se contemplan visitantes anónimos
que interactúan con la tienda sin haberse registrado.

### 1.5 Pagos y envíos

Los pagos y los envíos se representarán únicamente mediante estados simples asociados al pedido. Por
ejemplo, el pago podrá registrar los estados *pendiente*, *aprobado*, *rechazado* o *reembolsado*; el
envío podrá registrar *pendiente*, *preparado*, *enviado*, *entregado* o *cancelado*. No se
almacenarán datos completos de tarjetas ni se implementarán integraciones bancarias o logísticas
reales.

### 1.6 Supuestos de trabajo

1. Los ocho productos iniciales son datos de prueba y no constituyen el límite del catálogo.
2. Cada producto puede tener uno o más SKU; cada SKU identifica una presentación concreta vendible.
3. El precio y el stock se controlan por SKU.
4. El precio aplicado se conserva en cada ítem de pedido aunque luego cambie el precio vigente.
5. Un evento debe asociarse a un cliente identificado o a una sesión anónima.
6. Los pedidos cancelados no se consideran compras efectivas para los indicadores.
7. Los productos inactivos o sin stock no deben ofrecerse en recomendaciones de compra inmediata.
8. No se almacenan datos completos de tarjetas ni credenciales en texto plano.

### 1.7 Correspondencia con la consigna

| Exigencia de la consigna | Respuesta del proyecto |
| --- | --- |
| Seleccionar un caso de uso | Tienda online de cosmética y perfumería con recomendaciones personalizadas. |
| Analizar el dominio | Se analizan catálogo, SKU, stock, pedidos, interacciones, reseñas y recomendaciones. |
| Identificar los datos necesarios | Se definen datos operacionales, de comportamiento, analíticos, de seguridad y de auditoría. |
| Diseñar una solución robusta | Se conservan precios históricos, estados, fechas, reglas de integridad y trazabilidad. |
| Diseñar una solución segura | Se consideran roles, permisos, minimización de datos sensibles y sesiones anónimas. |
| Diseñar una solución escalable | El modelo admite más productos, clientes, pedidos y eventos sin rediseñarse. |
| Concentrarse en la capa de datos | No se entrena el modelo ni se desarrolla una aplicación completa; se diseña la base que los soportaría. |

### 1.8 Riesgos en relación con los datos

- Exposición indebida de datos personales de clientes (correo, teléfono, historial de compras y de
  navegación).
- Pérdida de la historia comercial si no se conserva el precio aplicado en el ítem de pedido.
- Recomendación de productos inactivos o sin stock.
- Crecimiento no controlado del volumen de eventos de interacción.

---

## 2. Relevamiento de datos necesarios

El relevamiento distingue los datos mínimos que deberán implementarse en la primera versión de
aquellos que se dejan previstos para futuras ampliaciones. Esta separación evita ampliar
innecesariamente el alcance y, al mismo tiempo, permite que el diseño sea compatible con una solución
de IA posterior.

### 2.1 Datos estructurados mínimos

| Grupo | Datos necesarios |
| --- | --- |
| Catálogo | Producto, SKU, marca, categoría, estado y fechas de alta/modificación. |
| Comercial | Precio vigente, stock disponible y umbral de stock bajo. |
| Usuarios | Identificador, nombre, correo, fecha de alta y estado. |
| Pedidos | Cliente, fecha, estado del pedido, estado de pago, estado de envío y total. |
| Ítems de pedido | Pedido, SKU, cantidad y precio aplicado. |
| Interacciones | Tipo de evento, cliente o sesión, producto/SKU, consulta y fecha-hora. |
| Reseñas | Cliente, producto, calificación, texto, fecha y estado de moderación. |
| Recomendaciones | Cliente o sesión, producto/SKU, posición, puntuación, método y fecha. |

### 2.2 Eventos de interacción

En este contexto, un evento es una acción registrada durante la interacción de una persona con la
tienda digital. Los eventos mínimos pueden ser la visualización de un producto, una búsqueda, la
aplicación de un filtro, la selección de una categoría o el clic en una recomendación.

Cada evento debería conservar, cuando corresponda, su tipo, fecha y hora, producto o SKU involucrado,
cliente identificado o identificador de sesión anónima y contexto de la acción. El pedido continúa
siendo la fuente principal de la operación comercial; un evento de compra podría registrarse para
análisis, pero no reemplaza al pedido ni a sus ítems.

### 2.3 Clientes identificados y visitantes anónimos

La inclusión de visitantes anónimos es coherente con el caso de uso. Una tienda digital puede recibir
interacciones de personas que todavía no se registraron o no iniciaron sesión. Esas interacciones
permiten personalizar la experiencia durante la sesión, analizar el comportamiento previo al registro
y abordar el problema de los usuarios nuevos sin exigir el almacenamiento de datos personales.

En el alcance mínimo, el identificador de cliente será opcional cuando exista una sesión anónima, y
cada evento deberá tener al menos uno de los dos identificadores. La vinculación posterior entre una
sesión anónima y un cliente registrado queda como ampliación opcional.

### 2.4 Datos de prueba

Los ocho productos iniciales funcionarán como muestra del catálogo. Para validar las consultas será
necesario generar también datos sintéticos de varios clientes, pedidos en distintas fechas,
visualizaciones, búsquedas, reseñas, productos vistos y no comprados, diferentes niveles de stock y
situaciones de compra conjunta. El número de registros podrá crecer sin modificar la estructura del
modelo.

---

## 3. Clasificación de los datos según su tipo

### 3.1 Estructurados, semiestructurados y no estructurados

El alcance mínimo se concentrará en datos estructurados. No obstante, el diseño contempla la
incorporación de datos semiestructurados, como atributos variables de productos, parámetros de
búsqueda o contexto de eventos, y datos no estructurados, como descripciones extensas, textos de
reseñas, imágenes o documentos de ingredientes.

En esta primera versión, además del modelo relacional para los datos estructurados, se incorpora el
tratamiento de datos semiestructurados mediante una base documental (MongoDB) para los eventos de
interacción y su `metadata` variable. JSONB en PostgreSQL queda previsto como alternativa para
atributos variables del lado relacional. Quedan fuera de esta versión el procesamiento de imágenes,
la generación de embeddings y la búsqueda vectorial (ver
[`../vectorial/modelo_vectorial.md`](../vectorial/modelo_vectorial.md)).

### 3.2 Datos analíticos, sensibles y de auditoría

| Tipo | Ejemplos | Uso |
| --- | --- | --- |
| Analíticos o derivados | Unidades vendidas, ingresos, productos más vistos, conversión y compras conjuntas. | Indicadores y generación futura de recomendaciones. |
| Sensibles | Correo, teléfono, historial de compras, navegación, preferencias y credenciales. | Protección, control de acceso y minimización. |
| Auditoría | Cambios de precio/stock, estados del pedido, moderación y generación de recomendaciones. | Trazabilidad y control de operaciones. |

---

## 4. Modelo conceptual

Desarrollado en [`modelo_conceptual.md`](modelo_conceptual.md): entidades principales, atributos
representativos, relaciones y cardinalidades, y las diez reglas de negocio del dominio.

Resumen de la lógica general:

```text
CATÁLOGO            →  PRODUCTO / SKU  →  PRECIO / STOCK  →  PEDIDOS
CLIENTES / SESIONES →  EVENTOS         →  RECOMENDACIONES
```

**Pendiente:** exportar el diagrama entidad-relación como `docs/modelo_conceptual.png`.

---

## 5. Modelo de implementación según la tecnología elegida

La solución combina tres motores:

| Componente | Modelo | Documentación |
| --- | --- | --- |
| PostgreSQL | Modelo lógico relacional (tablas, columnas, claves primarias y foráneas, restricciones de integridad, relaciones 1:1, 1:N y N:M) | **Pendiente** — [`../db/estructura/`](../db/estructura/) |
| MongoDB | Modelo documental: colección `user_events` como Time Series Collection | [`../nosql/modelo_nosql.md`](../nosql/modelo_nosql.md) |
| Redis | Modelo clave-valor: `recommendations:{user_id}:{context}` con TTL | [`../nosql/modelo_nosql.md`](../nosql/modelo_nosql.md) |

### 5.1 Qué datos se almacenan en cada componente y por qué

PostgreSQL aporta principalmente información sobre el **estado actual del negocio** (catálogo, SKU,
inventario, pedidos, reseñas), donde importan las relaciones y las restricciones de integridad.
MongoDB aporta información sobre el **comportamiento observado del usuario**, que se genera con mucha
frecuencia, es inmutable y presenta metadatos variables según el tipo de evento. Redis guarda
únicamente el resultado ya calculado de las recomendaciones, con un TTL corto.

Esta separación evita duplicar innecesariamente los datos transaccionales en MongoDB y permite que
cada tecnología se utilice para el tipo de información para el que resulta más adecuada.

**Pendiente:** desarrollar el modelo lógico relacional completo (punto 4 de la consigna).

---

## 6. Decisiones de normalización, embebido, referencia o desnormalización

**Pendiente de desarrollar.** Deben justificarse:

- Del lado relacional: las decisiones de normalización y qué problemas buscan evitarse (redundancias,
  inconsistencias, anomalías de inserción, actualización y eliminación). Un caso a documentar es la
  desnormalización deliberada del `unit_price_applied` en el ítem de pedido, que duplica el precio
  para preservar la historia comercial.
- Del lado documental: la decisión de mantener una única colección `user_events` con `event_type` y
  `metadata` en lugar de una colección por tipo de evento, y la de no embeber datos transaccionales
  en los eventos (sólo se referencian `user_id`, `product_id` y `order_id`).

---

## 7. Justificación de la tecnología seleccionada

### 7.1 PostgreSQL — datos transaccionales

**Pendiente de desarrollar** siguiendo los criterios que pide la consigna (tipo de datos, estructura
y variabilidad, volumen esperado, patrones de consulta, relaciones entre entidades, consistencia
requerida, seguridad y control de acceso, escalabilidad, complejidad operativa, ventajas y
limitaciones frente a otras alternativas).

### 7.2 MongoDB — eventos de interacción

Los eventos de navegación presentan características diferentes a los datos transaccionales: se
generan con mucha frecuencia, el volumen acumulado crece continuamente, son principalmente
operaciones de escritura, son independientes entre sí, distintos tipos pueden poseer metadatos
diferentes, no requieren las relaciones y restricciones de integridad propias del modelo
transaccional y, una vez registrados, son principalmente inmutables.

El modelo documental permite representar cada evento como un documento independiente y flexible,
evitando modificar un esquema rígido cada vez que se incorpora información adicional a un determinado
tipo de evento. Además, MongoDB dispone de **Time Series Collections**, apropiadas para información
que se genera continuamente y se consulta principalmente por rangos temporales.

**Alternativa evaluada:** Cassandra presenta excelentes características para cargas de escritura
masivas y distribuidas, pero introduce una mayor complejidad de modelado y operación. MongoDB ofrece
suficiente escalabilidad para el volumen esperado y mayor flexibilidad para este sistema.

### 7.3 Redis — cache de recomendaciones

Evita ejecutar repetidamente el mismo proceso cuando un usuario solicita recomendaciones varias veces
en un período reducido, reduciendo las consultas a PostgreSQL y MongoDB y, principalmente, la
cantidad de veces que debe ejecutarse el motor de recomendaciones y el modelo de IA.

---

## 8. Implementación mínima realizada

**Pendiente.** Estado actual:

| Componente | Estado |
| --- | --- |
| DDL PostgreSQL | Pendiente — [`../db/estructura/`](../db/estructura/) |
| Carga de datos de ejemplo | Pendiente — [`../db/datos/`](../db/datos/) |
| Índices y vistas | Pendiente — [`../db/indices_vistas/`](../db/indices_vistas/) |
| Consultas SQL representativas | Escritas como propuesta lógica, sin ejecutar — [`../db/consultas/`](../db/consultas/) |
| Colección `user_events` en MongoDB | Modelo definido; creación y carga pendientes |
| Cache Redis | Modelo de clave y valor definidos; implementación pendiente |

---

## 9. Datos de ejemplo utilizados

Disponibles en [`../data/ejemplos/`](../data/ejemplos/):

- `user_events.json` — documentos de ejemplo de los cuatro tipos de evento (`product_view`, `search`,
  `add_to_cart`, `purchase`).
- `redis_recommendations.json` — valor de ejemplo de la cache.

**Pendiente:** los ocho productos del catálogo, clientes, pedidos, ítems y reseñas sintéticos.

---

## 10. Consultas representativas

Cinco consultas SQL sobre el modelo relacional, en [`../db/consultas/`](../db/consultas/):

1. **Catálogo activo con disponibilidad** — ¿Qué productos activos están disponibles, indicando
   marca, precio y stock? Consulta operativa central; podría implementarse como vista
   `v_active_catalog`.
2. **Ventas e ingresos por categoría y período** — ¿Qué categorías generan más unidades vendidas e
   ingresos? La categoría principal evita contar dos veces una misma venta.
3. **Productos vistos pero todavía no comprados** — candidatos para recomendaciones personalizadas.
   Justifica un índice sobre `(customer_id, event_type, occurred_at)`.
4. **Productos y SKU con stock bajo** — reposición y exclusión de recomendaciones. Podría justificar
   un índice sobre `inventory(available_qty)`.
5. **Productos comprados conjuntamente** — venta cruzada basada en compras reales; usa CTE,
   agregación y subconsulta `EXISTS` para validar disponibilidad.

Cuatro consultas sobre MongoDB, en [`../nosql/modelo_nosql.md`](../nosql/modelo_nosql.md): historial
reciente de un usuario, productos más interactuados, eventos de una sesión y productos más
visualizados.

### Cobertura de los requisitos del punto 8

| Requisito | Consultas que lo cubren |
| --- | --- |
| Selección y filtrado | 1, 3 y 4 |
| Relaciones entre entidades | Todas |
| Agregaciones | 1, 2 y 5 |
| Indicadores comerciales | 2 y 4 |
| Personalización | 3 y 5 |
| Subconsulta o CTE | 3, 4 y 5 |
| Justificación de índices o vistas | 1, 3 y 4 |
| Apoyo a decisiones | 2, 4 y 5 |

---

## 11. Propuesta para datos semiestructurados, no estructurados o vectoriales

Desarrollado en [`../vectorial/modelo_vectorial.md`](../vectorial/modelo_vectorial.md). En síntesis:
los datos semiestructurados se resuelven mediante el campo `metadata` de los documentos de
`user_events` (con JSONB en PostgreSQL previsto como alternativa del lado relacional), y **la
búsqueda vectorial queda fuera del alcance de esta versión**, registrada como extensión opcional.

---

## 12. Propuesta de arquitectura de datos

Desarrollado en [`arquitectura.md`](arquitectura.md): componentes, integración entre PostgreSQL,
MongoDB y Redis, y flujo completo de recomendación con resolución de cache HIT / MISS.

---

## 13. Estrategia de seguridad, permisos y aislamiento

**Pendiente de desarrollar.** Elementos ya definidos en el relevamiento que deben servir de base:

- El acceso a los datos personales debe restringirse según el rol (regla de negocio 10).
- Tipos de usuario identificados: clientes, administradores, operadores y analistas.
- Datos sensibles identificados: correo, teléfono, historial de compras, navegación, preferencias y
  credenciales.
- No se almacenan datos completos de tarjetas ni credenciales en texto plano (supuesto 8).
- Las sesiones anónimas permiten analizar comportamiento previo al registro sin exigir el
  almacenamiento de datos personales.
- Auditoría prevista sobre cambios de precio/stock, estados del pedido, moderación de reseñas y
  generación de recomendaciones.

Falta desarrollar: matriz de roles y permisos, restricciones de acceso concretas por motor, y el
riesgo de exposición indebida de datos en aplicaciones conectadas a modelos de IA.

---

## 14. Consideraciones de escalabilidad y rendimiento

**Pendiente de desarrollar.** Elementos ya definidos que deben servir de base:

- Las estructuras que más crecerían son la colección `user_events` y las tablas de pedidos e ítems.
- Los eventos se mantienen separados del modelo transaccional justamente para no sobrecargarlo con un
  volumen que crece continuamente y tiene propósito principalmente analítico.
- La Time Series Collection organiza eficientemente datos que se agregan continuamente y se consultan
  por rangos temporales.
- Redis precalcula y reutiliza las recomendaciones ya generadas, con TTL de 5 a 15 minutos.
- Índices candidatos: `(customer_id, event_type, occurred_at)` sobre eventos e
  `inventory(available_qty)`.
- Vista candidata: `v_active_catalog`.

Falta desarrollar: qué datos podrían particionarse, qué componentes podrían separarse y qué
compromisos existen entre simplicidad, rendimiento, consistencia y costo.

---

## 15. Conclusiones

La propuesta responde al caso de uso de una tienda online que busca mejorar la experiencia de compra
mediante recomendaciones personalizadas, concentrándose en el diseño de la capa de datos. El alcance
es suficientemente acotado para ser implementable y, al mismo tiempo, admite el crecimiento del
catálogo, de los clientes, de los pedidos y de los eventos.

La separación entre producto y SKU, la conservación del precio histórico, el control de
disponibilidad, el registro de interacciones y las cinco consultas representativas constituyen la
base mínima para una solución robusta. El modelado documental de los eventos en MongoDB y la cache en
Redis completan la propuesta multi-motor, asignando cada tipo de información a la tecnología más
adecuada.

**Pendiente:** cerrar las conclusiones una vez completada la implementación mínima.

---

## Anexo — Decisiones para la primera versión y extensiones opcionales

### Decisiones para la primera versión

- Trabajar sobre una única tienda online.
- Implementar un modelo relacional para los datos estructurados y un modelo documental para los
  eventos.
- Utilizar ocho productos como datos iniciales, sin limitar el crecimiento del catálogo.
- Separar producto y SKU; administrar precio y stock por SKU.
- Representar pagos y envíos mediante estados simples del pedido.
- Registrar eventos de clientes identificados o sesiones anónimas.
- Validar el modelo mediante datos sintéticos y las consultas propuestas.
- No entrenar un modelo de IA ni desarrollar una aplicación completa en esta etapa.

### Extensiones opcionales

Una vez validado el alcance mínimo, el grupo podrá evaluar la incorporación de algunos elementos
opcionales. Estas alternativas no son necesarias para que la primera versión responda a la consigna.

| Extensión | Posible uso |
| --- | --- |
| JSONB en PostgreSQL | Atributos variables de productos, parámetros de búsqueda, contexto de eventos o metadatos de recomendaciones. |
| Embeddings y búsqueda vectorial | Similitud semántica entre descripciones, reseñas y preferencias. |
| Modelo de recomendación | Generación automática de puntuaciones a partir de compras, navegación o contenido. |
| Pagos y envíos detallados | Integración con proveedores, facturación, transportistas y seguimiento. |
| Carritos y promociones | Modelado de etapas previas a la compra y reglas comerciales más complejas. |
| Vinculación sesión anónima – cliente | Continuidad del comportamiento previo al registro. |
