# Informe técnico

**Diseño de una capa de datos para recomendaciones personalizadas**
Tienda online de cosmética y perfumería

Carrera de Especialización en Inteligencia Artificial, FIUBA
Bases de Datos para Inteligencia Artificial
Año 2026, Grupo 04

> Este informe sigue el índice de 15 puntos exigido por la consigna.

Los diagramas viven en archivos propios dentro de `docs/` y de `nosql/`, siguiendo la estructura que
sugiere la consigna. Están escritos en Mermaid dentro del Markdown, de modo que se versionan como
texto y se renderizan en el repositorio. Esta es su ubicación:

| Diagrama | Dónde | Punto |
| --- | --- | --- |
| Entidad-relación del dominio | [`modelo_conceptual.md`](modelo_conceptual.md), sección 7 | 3 |
| Clases UML del modelo lógico | [`modelo_logico_relacional.md`](modelo_logico_relacional.md) | 4 |
| Modelo físico de PostgreSQL | [`modelo_fisico.md`](modelo_fisico.md), sección 1 | 7 |
| Colecciones de MongoDB, integración con PostgreSQL y capa clave-valor | [`../nosql/modelo_nosql.md`](../nosql/modelo_nosql.md), secciones 1.1, 1.6 y 2 | 4 y 7 |
| Integración entre motores y flujo de recomendación | [`arquitectura.md`](arquitectura.md), secciones 2 y 3 | 10 |

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
cada evento deberá tener al menos uno de los dos identificadores. El modelo admite asociar una sesión
con un cliente cuando la identidad ya es conocida; automatizar esa vinculación después del registro
queda como ampliación opcional.

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
interacción y su `metadata` variable. JSONB en PostgreSQL se utiliza de manera acotada para atributos
variables de productos y SKU. Quedan fuera de esta versión el procesamiento de imágenes,
la generación de embeddings y la búsqueda vectorial (ver
[`../vectorial/modelo_vectorial.md`](../vectorial/modelo_vectorial.md)).

### 3.2 Datos operacionales, analíticos, sensibles y de auditoría

| Tipo | Ejemplos | Uso |
| --- | --- | --- |
| Operacionales | Catálogo, SKU, precios vigentes, stock, clientes, sesiones, pedidos e ítems, y los eventos de interacción. | Sostienen la operación diaria de la tienda y son la fuente de la que derivan los demás. Viven en PostgreSQL, salvo los eventos, que van a MongoDB. |
| Analíticos o derivados | Unidades vendidas, ingresos, productos más vistos, conversión y compras conjuntas. | Indicadores y generación futura de recomendaciones. |
| Sensibles | Correo, teléfono, historial de compras, navegación, preferencias y credenciales. | Protección, control de acceso y minimización. |
| Auditoría | Cambios de precio/stock, estados del pedido, moderación y generación de recomendaciones. | Trazabilidad y control de operaciones. |

---

## 4. Modelo conceptual

El dominio se organiza en once entidades: cliente y sesión; marca, categoría, producto y SKU;
inventario; pedido con sus ítems; evento de interacción; reseña; y recomendación con sus ítems. El
detalle de atributos está en [`modelo_conceptual.md`](modelo_conceptual.md), junto con el diagrama.

La distinción que ordena el resto es la de **producto y SKU**. El producto es el concepto comercial,
"Perfume Floral"; el SKU es la presentación vendible, "Perfume Floral de 50 ml". El precio y el stock
se controlan por SKU, no por producto, porque son dos variantes del mismo producto las que pueden
tener precios y existencias distintos.

Las cardinalidades que definen la forma del modelo son estas: una marca tiene muchos productos y un
producto tiene muchos SKU, ambas 1:N; producto y categoría es N:M, porque un producto puede
clasificarse en más de una, con una marcada como principal para no contar dos veces una misma venta;
cada SKU tiene obligatoriamente una fila de inventario, 1:1, creada automáticamente y protegida
contra eliminación o reasignación mientras el SKU exista; y un cliente tiene muchos pedidos y muchas reseñas. Los
eventos y las recomendaciones cuelgan del cliente **o de la sesión**, que es lo que permite atender
también al visitante anónimo.

Cinco reglas del dominio condicionan el diseño más que las demás. El código de SKU es único. El precio
aplicado se conserva en el ítem de pedido aunque después cambie el precio vigente, porque perderlo
sería perder la historia comercial. Un producto inactivo o sin stock no se recomienda para compra
inmediata. Los pedidos cancelados no cuentan como compras efectivas. Y todo evento conserva fecha y
hora y se asocia a un cliente o a una sesión. Las doce reglas completas están en el documento del
modelo.

Resumen de la lógica general:

```text
CATÁLOGO            →  PRODUCTO / SKU  →  PRECIO / STOCK  →  PEDIDOS
CLIENTES / SESIONES →  EVENTOS         →  RECOMENDACIONES
```

El diagrama entidad-relación está incorporado como Mermaid en
[`modelo_conceptual.md`](modelo_conceptual.md), sección 7, de modo que se versiona como texto y
se renderiza en el repositorio sin depender de una imagen exportada.

---

## 5. Modelo de implementación según la tecnología elegida

La solución combina tres motores:

| Componente | Modelo | Documentación |
| --- | --- | --- |
| PostgreSQL | Modelo lógico relacional (15 tablas, claves, restricciones y relaciones 1:1, 1:N y N:M) | [`modelo_logico_relacional.md`](modelo_logico_relacional.md) e implementación en [`../db/`](../db/) |
| MongoDB | Modelo documental: colección `user_events` como Time Series Collection | [`../nosql/modelo_nosql.md`](../nosql/modelo_nosql.md) |
| Redis | Modelo clave-valor: cuatro estructuras (String, Hash, Sorted Set y contadores) con tres políticas de expiración | [`../nosql/modelo_nosql.md`](../nosql/modelo_nosql.md) §2, implementación en [`../nosql/redis/`](../nosql/redis/) |

### 5.1 Qué datos se almacenan en cada componente y por qué

PostgreSQL aporta principalmente información sobre el **estado actual del negocio** (catálogo, SKU,
inventario, pedidos, reseñas), donde importan las relaciones y las restricciones de integridad.
MongoDB aporta información sobre el **comportamiento observado del usuario**, que se genera con mucha
frecuencia, es inmutable y presenta metadatos variables según el tipo de evento. Redis guarda
únicamente datos temporales, descartables y sensibles a la latencia: recomendaciones ya calculadas,
estado de sesiones anónimas, rankings precalculados y contadores de rate limit. Redis no es fuente de
verdad de ningún dato del modelo. Las recomendaciones, las sesiones y los rankings son
**reconstruibles**: se derivan de PostgreSQL, MongoDB y el motor. Los contadores operativos y la
cuota de rate limit en curso **no lo son**, porque son acumulados propios de Redis. Lo que comparten
las cuatro estructuras es que su contenido es **descartable**: perderlo es aceptable.

Esta separación evita duplicar innecesariamente los datos transaccionales en MongoDB y permite que
cada tecnología se utilice para el tipo de información para el que resulta más adecuada.

Los códigos externos `product_code`, `customer_code`, `session_code`, `order_code` y `sku_code`
conectan los motores sin exponer las claves internas de PostgreSQL.

---

## 6. Decisiones de normalización, embebido, referencia o desnormalización

El modelo relacional se mantiene en tercera forma normal: marca, categoría, producto, SKU, precio,
inventario, pedido e ítem se separan según sus dependencias. La relación N:M entre productos y
categorías utiliza `product_category`. Esto evita repetir marcas y categorías, mezclar variantes con
productos y sobrescribir precios históricos.

Aceptamos dos redundancias controladas: `unit_price_applied` preserva el precio de cada compra y
`sales_order.total_amount` se mantiene por trigger mediante deltas atómicos desde los ítems. JSONB
queda limitado a atributos variables no estructurales; precio, stock y relaciones no se guardan como
documentos.

MongoDB mantiene una única colección `user_events` con `event_type` y `metadata`, en lugar de una
colección por evento. Los documentos referencian códigos externos y no embeben datos transaccionales.

### 6.1 Duplicación deliberada en la capa clave-valor

Redis **duplica** a propósito información que ya existe en PostgreSQL y MongoDB. Es una
desnormalización asumida, con tres decisiones asociadas:

| Decisión | Alternativa descartada | Compromiso aceptado |
| --- | --- | --- |
| Cachear el resultado ya calculado por el motor | Reejecutar el motor en cada solicitud | La recomendación servida puede haber dejado de reflejar los últimos eventos del usuario; la obsolescencia se acota con el TTL |
| Materializar el ranking de productos más vistos | Ejecutar la agregación de MongoDB en cada visita | El ranking tiene hasta una hora de retraso |
| TTL como mecanismo de consistencia | Invalidar en cada evento del usuario | Consistencia eventual de hasta 10 minutos, a cambio de conservar el beneficio de la cache |

En los tres casos el compromiso es el mismo: **se cambia exactitud instantánea por latencia**. Es
aceptable porque ningún dato de Redis es fuente de verdad; el precio aplicado, el stock y el pedido
se leen siempre de PostgreSQL.

El valor cacheado conserva `model_version` para poder determinar qué versión del modelo produjo una
recomendación servida desde cache, según lo exige la regla de negocio 9.

---

## 7. Justificación de la tecnología seleccionada

### 7.1 PostgreSQL: datos transaccionales

Seleccionamos PostgreSQL porque el núcleo contiene datos estructurados y fuertemente relacionados:
productos, variantes, precios, stock, clientes, pedidos e ítems. Su estructura es estable, y la
variabilidad que existe se concentra en atributos descriptivos que cambian según la categoría del
producto; para esos casos el esquema usa columnas `jsonb` con índices GIN, de modo que admitir un
atributo nuevo no exige migrar la tabla. Las operaciones necesitan claves foráneas, restricciones,
transacciones ACID e integridad inmediata. Los patrones principales combinan relaciones, filtros,
agregaciones e historial temporal.

El volumen del caso académico no exige distribución y PostgreSQL reduce la complejidad operativa. Su
madurez, roles, permisos, copias de seguridad e índices B-tree, parciales y GIN cubren seguridad y
rendimiento. Frente a MongoDB evita trasladar a la aplicación la consistencia de pedidos, precios y
stock. Como limitación, una única instancia no escala escrituras indefinidamente, pero admite
réplicas de lectura y particionamiento futuro sin cambiar el modelo inicial.

### 7.2 MongoDB: eventos de interacción

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

### 7.3 Redis: capa clave-valor

**Tipo de datos y variabilidad:** datos temporales, descartables y de estructura simple, a los que
siempre se accede por un identificador conocido de antemano (cliente, sesión, producto, ventana
temporal). No requieren relaciones, integridad referencial ni consultas por atributos internos.

**Patrones de consulta:** acceso directo por clave. No hay una sola consulta de esta capa que
necesite filtrar por el contenido del valor, que es la condición bajo la cual un modelo clave-valor
resulta apropiado.

**Consistencia requerida:** baja. Servir una recomendación con hasta diez minutos de antigüedad es
aceptable; servir un precio o un stock desactualizado no lo es, y por eso esos datos no pasan por
Redis.

El problema que resuelve es de latencia. El demo lo ilustra con 258 ms por el camino del motor contra
0,60 ms desde Redis. **Solo el segundo número es una medición**: el lado del MISS no ejecuta el motor
de recomendaciones, que queda fuera del alcance del trabajo, sino que lo sustituye por una espera fija
de 250 ms elegida como valor plausible. Lo que la corrida demuestra es el mecanismo y el costo real de
resolver desde Redis, que es lo que corresponde a esta capa. La magnitud de la mejora en un sistema
real dependerá de cuánto tarde el motor que se construya sobre ella.

**Alternativas evaluadas:**

| Alternativa | Por qué la descartamos |
| --- | --- |
| Cache en memoria del proceso backend | No se comparte entre instancias: cada réplica ejecutaría el motor por su cuenta y la tasa de aciertos caería al escalar horizontalmente. Tampoco sobrevive a un reinicio del proceso. |
| Vista materializada en PostgreSQL | Sirve para el ranking agregado, pero no para recomendaciones personalizadas por cliente y contexto. Además cargaría de escrituras la base transaccional y no ofrece expiración automática. |
| Memcached | Cubre la cache pura y también el rate limit, porque dispone de incremento atómico y de expiración. No ofrece estructuras más allá del String: no resolvería la sesión como Hash ni el ranking como Sorted Set, que tendrían que serializarse y reescribirse enteros en cada actualización. |
| No usar cache | Cada solicitud ejecutaría el motor y el modelo de IA, que son los componentes más costosos de la arquitectura. |

**Complejidad operativa:** baja. La capa de datos es **un único servidor**, sin esquema que migrar y
sin persistencia que administrar. El compose levanta además dos contenedores auxiliares que no forman
parte del despliegue: RedisInsight, que es el visor web, y `demo`, que solo ejecuta el script de
medición.

**Limitaciones asumidas:** los datos viven en memoria y se pierden al reiniciar; con
`allkeys-lru` cualquier clave puede ser descartada bajo presión de memoria; y el control de acceso
se delega en el backend, porque el ACL de Redis filtra por nombre de clave y no por contenido, de modo
que no equivale al Row Level Security de PostgreSQL (ver sección 13.1). Las tres son aceptables porque
ningún dato de esta capa es fuente de verdad.

---

## 8. Implementación mínima realizada

Los tres motores tienen su implementación mínima ejecutada y verificada. El modelo físico que
describe cómo se concreta el diseño en cada tecnología, con nombres de tablas, columnas, tipos,
restricciones, índices y estructuras de acceso, está en [`modelo_fisico.md`](modelo_fisico.md).

| Componente | Estado |
| --- | --- |
| DDL PostgreSQL | Implementado y validado, en [`../db/estructura/`](../db/estructura/) |
| Carga de datos de ejemplo | Implementada y validada, en [`../db/datos/`](../db/datos/) |
| Índices y vistas | Implementados y validados, en [`../db/indices_vistas/`](../db/indices_vistas/) |
| Consultas SQL representativas | Cinco consultas implementadas y ejecutables, en [`../db/consultas/`](../db/consultas/) |
| Roles y permisos PostgreSQL | Implementados y validados con Docker, en [`../db/seguridad/`](../db/seguridad/) |
| **MongoDB** (`user_events`) | **Implementada y verificada**, en [`../nosql/mongodb/`](../nosql/mongodb/) |
| **Redis** | **Implementado y verificado**, en [`../nosql/redis/`](../nosql/redis/) |

La validación actualizada de la capa relacional se ejecutó correctamente el 29/08/2026 con Docker
Compose. El contenedor quedó `Up (healthy)` y pasaron veinticuatro controles de estado, cuatro
controles de comportamiento, diecisiete pruebas de integridad y una prueba concurrente. El procedimiento
y la evidencia se encuentran en
[`../db/validacion/README.md`](../db/validacion/README.md).

La capa clave-valor está implementada por completo: `docker-compose.yml` con Redis 8.2 y
RedisInsight, script de carga con autovalidación, cinco archivos de comandos representativos y dos
demostraciones con evidencia medida (cache-aside y descarte por límite de memoria).

La capa documental también: `docker-compose.yml` con MongoDB 8.0 y mongo-express, creación de
`user_events` como Time Series Collection con retención de 90 días, carga de 22 eventos con
validación previa del archivo de datos y siete comprobaciones sobre lo cargado, y ocho consultas
representativas ejecutadas contra la base.

---

## 9. Datos de ejemplo utilizados

Documentos de muestra en [`../data/ejemplos/`](../data/ejemplos/):

- `user_events.json`: documentos de ejemplo de los cuatro tipos de evento (`product_view`, `search`,
  `add_to_cart`, `purchase`).
- `redis_recommendations.json`: valor de ejemplo de la cache.

Conjuntos que se cargan efectivamente en cada motor:

- [`../db/datos/`](../db/datos/): los ocho productos del catálogo, clientes, pedidos, ítems y reseñas
  sintéticos, utilizados en la validación de PostgreSQL.
- [`../nosql/mongodb/seed_data.json`](../nosql/mongodb/seed_data.json): 22 eventos de tres clientes
  identificados y un visitante anónimo, entre el 18 y el 24 de agosto de 2026.
- [`../nosql/redis/datos/estado_inicial.redis`](../nosql/redis/datos/estado_inicial.redis): las seis
  claves del estado inicial de la capa clave-valor.

El conjunto es deliberadamente pequeño, pero está construido para que cada decisión de diseño pueda
comprobarse sobre él. Los ocho productos con diez SKU permiten verificar la separación entre producto
y variante, y que el precio y el stock se controlan por SKU. Los cinco pedidos con diez ítems permiten
comprobar que el precio aplicado se conserva, y uno de ellos está cancelado justamente para verificar
que no cuenta como compra efectiva. Los 22 eventos, repartidos en cinco sesiones de tres clientes y un
visitante anónimo, permiten ejecutar las consultas por ventana temporal y comprobar que el evento sin
`user_id` sigue siendo consultable. Las seis claves de Redis cubren las cuatro estructuras del diseño
con sus tres regímenes de expiración: TTL fijo, TTL deslizante y sin vencimiento.

---

## 10. Consultas representativas

Cinco consultas SQL sobre el modelo relacional, en [`../db/consultas/`](../db/consultas/):

1. **Catálogo activo con disponibilidad.** ¿Qué productos activos están disponibles, indicando
   marca, precio y stock? Consulta operativa central. Se escribe con los `JOIN` explícitos para
   mostrar el recorrido del modelo relacional; la vista `v_active_catalog` resuelve ese mismo acceso y
   está creada en [`../db/indices_vistas/`](../db/indices_vistas/), otorgada a los dos roles
   funcionales y consumida por la consulta 5 y por la validación.
2. **Ventas e ingresos por categoría y período.** ¿Qué categorías generan más unidades vendidas e
   ingresos? La categoría principal evita contar dos veces una misma venta.
3. **Frecuencia y valor de compra por cliente.** Señales transaccionales para segmentación y futuras
   recomendaciones, sin duplicar en PostgreSQL los eventos que pertenecen a MongoDB.
4. **Productos y SKU con stock bajo.** Reposición y exclusión de recomendaciones. Podría justificar
   un índice sobre `inventory(available_qty)`.
5. **Productos comprados conjuntamente.** Venta cruzada basada en compras reales; usa CTE,
   agregación y subconsulta `EXISTS` para validar disponibilidad.

Ocho consultas sobre MongoDB, en [`../nosql/mongodb/consultas/`](../nosql/mongodb/consultas/), cada
una con su pregunta de negocio, su justificación y el resultado esperado contra el estado inicial:

| Archivo | Qué resuelve |
| --- | --- |
| `01_contexto_recomendacion.md` | Historial reciente de un usuario, productos más interactuados y reconstrucción de una sesión |
| `02_analiticas_productos.md` | Productos más visualizados y categorías con mayor interés |
| `03_analiticas_comportamiento.md` | Búsquedas por usuario, relación entre vistas y carrito, y actividad por sesión |

Comandos representativos sobre Redis, en [`../nosql/redis/comandos/`](../nosql/redis/comandos/), cada
uno con la pregunta que responde y su comparación con el equivalente SQL:

| Archivo | Qué resuelve | Comandos centrales |
| --- | --- | --- |
| `01_cache_recomendaciones.md` | Servir recomendaciones sin ejecutar el motor; invalidar antes del vencimiento | `GET`, `SET ... EX`, `TTL`, `DEL`, `INFO stats` |
| `02_sesiones_anonimas.md` | Sostener el estado de un visitante no registrado con expiración deslizante | `HGETALL`, `HGET`, `HINCRBY`, `EXPIRE` |
| `03_rankings_precalculados.md` | Top de productos más vistos sin recorrer `user_events` | `ZREVRANGE`, `ZINCRBY`, `ZREVRANK`, `ZCOUNT`, `ZADD` |
| `04_rate_limit_y_contadores.md` | Acotar invocaciones al motor por cliente y ventana | `INCR`, `EXPIRE ... NX`, `MGET` |
| `05_expiracion_memoria_y_patrones.md` | Patrones de búsqueda, tamaño en memoria y descarte por límite | `SCAN ... MATCH`, `OBJECT ENCODING`, `MEMORY USAGE`, `CONFIG GET` |

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

Desarrollado en [`../vectorial/modelo_vectorial.md`](../vectorial/modelo_vectorial.md), que recorre
los once tipos de dato que enumera la consigna y dice cuáles aparecen en el caso y cuáles no. En
síntesis, cada tipo va a la tecnología que resuelve su patrón de acceso: los atributos variables del
catálogo viven en columnas `jsonb` de PostgreSQL con índices GIN, porque se consultan junto al precio
y al stock en la misma transacción; los eventos, con su `metadata` variable por tipo, en la colección
documental de MongoDB; las descripciones y las reseñas, como texto en el modelo relacional. El caso no
presenta relaciones altamente conectadas, de modo que no se justifica una base de grafos.

**La búsqueda vectorial queda fuera del alcance de esta versión**, con su diseño documentado: qué
datos se vectorizarían, qué necesidades resolvería, qué consultas permitiría, qué metadatos debe
llevar cada vector y qué riesgos aparecen al recuperar información incorrecta, desactualizada o no
autorizada. Justificamos la decisión: las consultas que hoy alimentan al motor se resuelven por
identificador y por rango temporal, donde un vector no aporta; la similitud haría falta para
"productos parecidos a este", para la búsqueda en lenguaje natural que ya registran los eventos
`search`, y para el arranque en frío de un cliente sin historial.

---

## 12. Propuesta de arquitectura de datos

Desarrollado en [`arquitectura.md`](arquitectura.md): componentes, integración entre PostgreSQL,
MongoDB y Redis, y flujo completo de recomendación con resolución de cache HIT o MISS. El documento
recorre además la circulación del dato desde su generación hasta su uso por el motor, con los diez
elementos que enumera la consigna, y justifica la elección de una **arquitectura simple multi-motor**
frente a un Data Warehouse, un Data Lake, un Lakehouse o una arquitectura por capas.

La razón de fondo es que la fuente es una sola tienda, el horizonte útil son los 90 días de retención
de `user_events` y las consultas analíticas se responden con agregaciones sobre los motores
operacionales. Una capa analítica separada es el camino de evolución previsto, con dos señales
concretas para construirla: necesitar un horizonte más largo que la retención, o que las agregaciones
empiecen a competir con la operación. Ante esa segunda señal, el primer paso previsto no es una capa
nueva sino una réplica de solo lectura de PostgreSQL dedicada a las consultas del analista, que se
analiza en la sección 14.3.

---

## 13. Estrategia de seguridad, permisos y aislamiento

La estrategia aplica privilegio mínimo, separación entre administración y operación, minimización de
datos personales y ausencia de acceso directo desde clientes finales. No se almacenan datos completos
de tarjetas ni credenciales de clientes en el modelo. Las credenciales locales de demostración se
toman de un `.env` ignorado por Git y los puertos de PostgreSQL y Redis se publican únicamente en
`127.0.0.1`.

### 13.1 Seguridad de PostgreSQL

La matriz se implementa en
[`../db/seguridad/01_roles_permisos.sql`](../db/seguridad/01_roles_permisos.sql).
Los roles funcionales son `NOLOGIN`: una aplicación real debe usar una credencial propia, almacenada
fuera del repositorio, y heredar únicamente el rol necesario.

| Actor o rol | Permisos | Restricciones principales |
| --- | --- | --- |
| Administrador (`POSTGRES_USER`) | Propiedad de objetos, migraciones, carga y validación. | No debe utilizarse como identidad normal del backend ni compartirse con clientes o analistas. |
| Backend u operador (`bdia_app`) | Lectura operativa y escritura explícita por tabla y columna; inserta pedidos, ítems y movimientos. | No escribe directamente stock ni total, no modifica ni borra movimientos y no altera identificadores externos mediante permisos normales. |
| Analista (`bdia_analyst`) | Solo lectura sobre catálogo y datos comerciales agregables. | Sin acceso directo a `customer`, `customer_session` ni `review`, que contienen datos identificatorios o texto libre. |
| Cliente o visitante | Ningún rol ni conexión directa a PostgreSQL. | Accede únicamente a través de una futura aplicación que aplique autorización y consultas parametrizadas. |

`inventory.available_qty` se deriva de `inventory_movement` y
`sales_order.total_amount` se deriva de `order_item`. `bdia_app` carece de permisos `INSERT` y
`UPDATE` sobre esas columnas. Los triggers pueden mantenerlas porque
`apply_inventory_movement` y `apply_order_total_delta` son `SECURITY DEFINER`, tienen un
`search_path` fijo en esquemas confiables, con `pg_temp` al final, y pertenecen
al administrador, y **todas las funciones disparadoras que consultan tablas fijan también su
`search_path`**, aunque no sean `SECURITY DEFINER`: sin eso, una sesión podía crear una tabla temporal
que sombreara `order_item` y burlar la validación de ventas. Se revocó de `PUBLIC` el acceso al
esquema, a tablas, secuencias y funciones, y se definieron privilegios predeterminados restrictivos
para las funciones que se creen más adelante. El esquema define diez funciones; el DDL revoca de
`PUBLIC` las funciones elevadas y el script de seguridad restringe nuevamente el conjunto completo,
incluidas las funciones que se creen después mediante sus privilegios predeterminados.

Los movimientos de inventario son además inmutables: el rol operativo solo puede insertarlos y el
DDL rechaza su modificación o borrado. Las pruebas ejecutan `SET ROLE` y verifican tanto los accesos
denegados como los caminos autorizados que actualizan stock y total mediante los triggers.

**Aislamiento entre clientes, y por qué no se usa Row Level Security.** El caso es una única tienda,
así que no hay múltiples empresas ni espacios de trabajo que aislar entre sí. La separación que sí
importa es que un cliente no vea los pedidos ni las reseñas de otro. Hoy esa separación la aplica la
aplicación: `bdia_app` tiene `SELECT` sobre `customer` y `sales_order` a nivel tabla, y es el backend
el que acota cada consulta al cliente de la sesión. Es una frontera única, y por eso conviene decir
qué la reforzaría.

PostgreSQL permite una segunda capa con Row Level Security: una política por tabla que filtre las
filas según el cliente de la sesión, para que una consulta mal construida en la aplicación no
alcance para ver de más. Verificado sobre la base: hoy **ninguna tabla tiene RLS habilitado y no hay
políticas definidas**, pero el terreno está preparado, porque los cuatro roles se crean `NOBYPASSRLS`
y la validación comprueba esa propiedad como un control más. Queda fuera de esta entrega porque no
existe la aplicación que establecería el cliente de la sesión, que es lo que una política necesita
para decidir; lo documentamos como el primer refuerzo a incorporar cuando esa aplicación exista.

**Riesgo de exposición mediante una futura aplicación de IA.** El modelo o agente no debe recibir
credenciales de base ni generar SQL con privilegios administrativos. El backend debe usar consultas
parametrizadas, limitar cada solicitud a los campos necesarios, preferir códigos seudónimos en lugar
de nombre, correo o teléfono y evitar registrar datos personales en prompts o logs. Estas son reglas
de integración documentadas; su ejecución queda fuera de esta entrega porque no se desarrolla una
aplicación ni un modelo de IA.

### 13.2 Seguridad de la capa clave-valor

| Aspecto | Decisión |
| --- | --- |
| Minimización | La sesión anónima guarda comportamiento, no identidad: `started_at`, `last_seen_at`, `events_count`, `last_product_id` y `preferred_category`. **No** almacena dirección IP, user agent, correo ni teléfono. |
| Retención | El TTL actúa como política de retención automática: la sesión desaparece sola a los 30 minutos de inactividad, sin proceso de purga. |
| Qué se guarda del cliente | El valor está minimizado por atributos: solo identificadores de producto y puntuaciones, sin nombre, correo ni teléfono. La clave sí incorpora el código externo seudónimo (`reco:user:{customer_code}:...`), acotado por el TTL como retención máxima y protegido por el control de acceso del backend. |
| Aislamiento | El prefijo de la clave separa los espacios de nombres, y el discriminador `user` / `sess` evita que una sesión anónima resuelva contra la entrada de un cliente registrado. |
| Acceso | `requirepass` activo y puerto publicado únicamente en `127.0.0.1`. |
| Protección del motor de IA | El rate limit por cliente y ventana acota cuántas veces puede invocarse el motor de recomendaciones y el modelo, que son los recursos más costosos. |

**Limitación reconocida del rate limit.** Los contadores `ratelimit:*` están sujetos a la política de
descarte igual que el resto de las claves. Bajo presión de memoria, `allkeys-lru` puede desalojarlos y
el siguiente `INCR` los recrea en 1, con lo que el límite **falla abierto durante una sobrecarga**.
Lo verificamos forzando el límite de memoria con un contador en 30 de 30: la clave fue descartada y el
`INCR` siguiente devolvió 1. Redis no permite asignar prioridad de desalojo por clave, y
protegerlos exigiría una instancia o base independiente. Lo aceptamos dentro de este alcance porque la
función del límite es acotar el uso normal y no resistir un abuso deliberado.

**Limitación reconocida:** el control de acceso real vive en el backend, que debe ser el único
componente que hable con Redis. Conviene precisar el alcance de esa limitación. Redis 8.2 sí dispone
de ACL, con usuarios y permisos por patrón de clave y por comando: comprobamos que un usuario acotado
a `~reco:user:user-123:*` con `+get` lee esa entrada, y recibe `NOPERM` tanto al pedir la clave de
otro sujeto como al intentar escribir. Ese mecanismo no ofrece un filtrado por contenido
equivalente al Row Level Security de PostgreSQL, que decide fila por fila según el resultado de la
consulta: el ACL alcanza al nombre de la clave, no a lo que hay dentro del valor. En este alcance no
se definen usuarios ACL porque el único cliente es el backend. Exponer Redis directamente a un cliente
sin ACL le permitiría leer las claves de cualquier otro usuario, ya que basta conocer el identificador
para construir la clave.

---

### 13.3 Seguridad de la capa documental

| Aspecto | Decisión |
| --- | --- |
| Autenticación | El usuario administrador se crea a partir de `MONGO_INITDB_ROOT_USERNAME` y `MONGO_INITDB_ROOT_PASSWORD`, tomados del `.env` del componente. Las siete variables del componente se interpolan con la sintaxis `${VAR:?mensaje}`, de modo que un `.env` ausente o incompleto aborta Compose en lugar de levantar el motor sin credenciales. |
| Acceso | El puerto se publica únicamente en `127.0.0.1`, con el valor de `MONGO_LISTEN_PORT`. |
| Visor web | `mongo-express` exige autenticación básica con credenciales propias, distintas de las del motor. Comprobado: sin credenciales responde `401`, con credenciales incorrectas también, y solo con las correctas responde `200`. |
| Minimización | El evento de un visitante anónimo se identifica solo por `session_id`. La colección no almacena dirección IP, user agent, correo ni teléfono; los datos personales viven en PostgreSQL, protegidos por sus roles. |
| Retención | `expireAfterSeconds` de 90 días actúa como política de borrado automático: MongoDB elimina los buckets vencidos sin necesidad de un proceso de purga. |

**Sobre el control de acceso.** MongoDB 8.0 dispone de roles por base de datos y por colección. Se
comprobó creando un usuario con rol `read` sobre la base del componente: lee los 22 documentos y
cualquier escritura devuelve `Unauthorized`. En este alcance solo se define el usuario administrador,
porque el único cliente es el script de carga del propio componente. Un despliegue real separaría al
menos dos roles: uno de solo lectura para el motor de recomendaciones y uno de escritura para la
ingesta de eventos, para que el motor no pueda alterar el historial que consume.

**Limitación reconocida.** Las credenciales solo se aplican al inicializar `/data/db`. Comprobado:
tras cambiar la contraseña en `.env` y recrear el contenedor, la contraseña nueva falla, la anterior
sigue siendo válida y el healthcheck deja el contenedor `unhealthy`. Rotarlas exige reinicializar el
volumen, con la pérdida de los eventos cargados que eso implica. El procedimiento está documentado en
[`../nosql/mongodb/README.md`](../nosql/mongodb/README.md).

Una restricción operativa se deriva del visor: `mongo-express` concatena usuario y contraseña dentro
de la URI de conexión sin aplicar percent-encoding, así que la contraseña debe ser URL-safe.
Comprobado con `pa@ss:word`: el contenedor termina con `ERR_INVALID_URL` y código 1. La restricción
queda escrita en `nosql/mongodb/.env.example`, junto a las variables que afecta.

---

## 14. Consideraciones de escalabilidad y rendimiento

Las estructuras que más crecen son la colección `user_events` y las tablas de pedidos e ítems. Los
eventos se mantienen separados del modelo transaccional para no sobrecargarlo con un volumen que
crece de forma continua y tiene propósito principalmente analítico. Cada capa se analiza por separado
en las tres subsecciones siguientes, con la evidencia medida sobre la implementación.

### 14.1 Escalabilidad de la capa clave-valor

**Qué crece:** las entradas de cache crecen con clientes activos × contextos; las sesiones, con
visitantes concurrentes, aunque se autolimitan por el TTL de 30 minutos; los rankings están acotados
por el tamaño del catálogo.

**Dimensionamiento medido:** `MEMORY USAGE` da 312 bytes para una entrada de cache con tres
recomendaciones, 208 para una sesión y 216 para el ranking de ocho productos. La estimación de RAM se
calcula sobre estos valores medidos, no sobre supuestos.

**Qué se precalcula:** el ranking de productos más vistos, que de otro modo exigiría recorrer
`user_events` en cada visita a la página principal.

**Límite y descarte:** con `maxmemory` de 256 MB y política `allkeys-lru`, Redis descarta las claves
menos usadas recientemente al alcanzar el límite. El demo lo verifica: partiendo de las 6 claves del
estado inicial, con el límite bajado a 4 MB e insertando 6000 claves de 1 KB, se descartaron 4768 y
quedaron 1238, incluidas entre las descartadas **las seis claves del estado inicial**. La corrida
completa está citada en [`../nosql/modelo_nosql.md`](../nosql/modelo_nosql.md), sección 2.7. De ahí la
restricción de diseño: ninguna información que deba sobrevivir puede residir únicamente en Redis.

**Si el volumen creciera:** réplicas de solo lectura para repartir las lecturas, o Redis Cluster
particionando por hash slot. Casi todas las operaciones son de clave única. La excepción es el `MGET`
sobre los dos contadores, que en Cluster fallaría con `CROSSSLOT` porque dos claves distintas no
tienen garantizado el mismo slot; se resuelve con un hash tag (`contador:{reco}:...`), que hace que
Redis calcule el slot solo sobre la porción entre llaves y ambas caigan en el mismo.

**Alcance de los contadores:** no expiran, pero tampoco son durables. Sin persistencia se pierden al
reiniciar y `allkeys-lru` los descarta bajo presión de memoria, como verifica el demo. Son acumulados
best-effort y no una fuente de métricas de negocio.

**Compromiso central:** el TTL introduce consistencia eventual de hasta 10 minutos a cambio de
resolver la solicitud desde memoria. El costo del acierto está medido en 0,60 ms; el del fallo no
corresponde a esta capa, porque depende del motor que queda fuera del alcance, y el demo lo sustituye
por una espera fija de 250 ms. La relación entre ambos ilustra el orden de magnitud esperable, no un
resultado verificado del camino completo.

### 14.2 Escalabilidad de la capa documental

**Qué crece:** `user_events` es la estructura de mayor crecimiento del diseño, porque los eventos se
agregan de forma continua y no se modifican.

**Qué lo acota:** la retención de 90 días declarada con `expireAfterSeconds`. MongoDB elimina los
buckets vencidos por su cuenta, y el volumen se estabiliza en la ventana útil en lugar de
crecer sin límite. Es la misma idea que el TTL de Redis, aplicada a un horizonte mucho más largo.

**Cómo agrupa:** con `metaField: user_id`, la Time Series Collection agrupa los eventos de un mismo
usuario y período en un bucket. Medido sobre el estado inicial: 22 documentos ocupan **5 buckets**,
5074 bytes de datos y 20480 de almacenamiento, con 40960 bytes de índices.

**Qué gana la consulta:** el filtro por usuario y ventana temporal descarta buckets enteros sin
abrirlos. Medido con `explain("executionStats")` sobre la consulta que alimenta al motor, la de
`user-123` en los últimos siete días: resuelve con `IXSCAN` y examina **3 de los 5 buckets**. Esa
poda es la razón de fondo por la que las consultas de la sección 10 acotan siempre la ventana.

**Si el volumen creciera:** sharding por `user_id`, que es el `metaField`. Las consultas que alimentan
al motor parten siempre del cliente, así que se dirigirían a un solo shard en lugar de consultar a
todos. El criterio de partición coincide con el de agrupamiento, así que la localidad de los buckets
se conserva.

**Compromiso asumido:** `session_id` es un campo medido y no lleva índice propio. Reconstruir una
sesión exige acotar además la ventana temporal, y las consultas del modelo la acotan siempre. Un
índice adicional sobre `session_id` aceleraría ese acceso a cambio de encarecer cada escritura, que es
la operación dominante en esta colección.

### 14.3 Escalabilidad de la capa relacional

**Qué crece:** `sales_order`, `order_item` e `inventory_movement`, que acumulan una fila por operación
y no se depuran.

**Qué hay hoy:** las 15 tablas del modelo más `deployment_validation`, que es la marca de
inicialización que exige el healthcheck, una vista, 12 triggers y 48 índices. De esos índices, 16 se
declaran explícitamente para los patrones de acceso y los 32 restantes respaldan claves primarias,
restricciones únicas y la de exclusión. El esquema no delega en el orden de llegada de las consultas:
los accesos previstos tienen su índice declarado.

**Índices que responden a una consulta concreta:** `inventory_low_stock_idx` es parcial y sirve la
consulta de reposición. Medido con `EXPLAIN (ANALYZE)`, esa consulta resuelve con `Bitmap Index Scan`
sobre ese índice en lugar de recorrer la tabla. Los índices GIN `product_attributes_gin_idx` y
`sku_attributes_gin_idx` sostienen las búsquedas sobre los atributos flexibles en `jsonb`, que es
donde el modelo relacional admite datos semiestructurados.

**Consistencia bajo concurrencia:** los totales de pedido y el stock no se escriben directamente, sino
a través de funciones internas, y las escrituras directas están revocadas para el rol de aplicación.
La restricción de exclusión `sku_price_no_overlapping_periods_excl` impide que dos períodos de precio
del mismo SKU se superpongan, algo que un `CHECK` no puede expresar. La validación incluye una prueba
con dos inserciones concurrentes sobre el mismo pedido que comprueba que el total queda correcto.

**Si el volumen creciera:** particionar por tiempo `sales_order` e `inventory_movement`, que son las
tablas cuyo crecimiento es proporcional a la operación y cuyas consultas casi siempre acotan un
período.

**Réplica de solo lectura para la analítica:** la consigna distingue al analista que consulta
indicadores comerciales del resto de los usuarios, y le asignamos un rol propio, `bdia_analyst`, de
solo lectura. El paso siguiente es asignarle también una base propia: una réplica física por
replicación en streaming que atienda las consultas analíticas de la sección 10, mientras la primaria
queda dedicada al camino transaccional. No la implementamos en este alcance. La planteamos como la
primera evolución prevista y de costo menor al de una capa analítica separada, porque no agrega un
modelo nuevo ni un proceso de carga que mantener.

**Qué aporta y qué cuesta:** aporta aislamiento de recursos. Las agregaciones sobre `sales_order`,
`order_item` y `product_category` dejan de competir por CPU, memoria y buffers con el alta de pedidos
y los movimientos de stock, de modo que una consulta de reporte extensa no degrada la operación en
horario de mayor carga. El costo es la actualidad del dato: la réplica queda unos instantes por
detrás de la primaria y la analítica lee un estado levemente desactualizado. Resulta admisible para
indicadores comerciales y no lo sería para el stock disponible ni para el total de un pedido, que se
siguen leyendo de la primaria porque son los valores que el diseño mantiene exactos con triggers y
restricciones.

**Efecto sobre el modelo y los permisos:** ninguno. La réplica es una copia física y hereda el mismo
esquema y los mismos `GRANT`, de modo que la matriz de permisos de la sección 13 se mantiene sin
cambios y `bdia_analyst` tampoco accede allí a `customer`, `customer_session` ni `review`. Queda una
decisión de configuración: con `hot_standby_feedback` desactivado, la primaria se libera de la
presión que las consultas largas ejercen sobre el `VACUUM`, a costa de que una consulta extensa en la
réplica pueda cancelarse por conflicto con la aplicación de los cambios. Para un uso analítico, donde
reintentar una consulta no tiene costo operativo, el intercambio es favorable. La señal para
construirla es que las consultas de reporte aparezcan compitiendo con la operación en
`pg_stat_statements`, o que el tiempo de respuesta transaccional se degrade en las ventanas de
consulta de indicadores.

**Compromiso asumido:** los índices y los 12 triggers encarecen cada escritura para abaratar la
lectura y para sostener las invariantes dentro del motor. Es el intercambio que corresponde a un
catálogo que se lee mucho más de lo que se modifica, y traslada al motor una integridad que de otro
modo habría que confiar a la aplicación.

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

La implementación mínima de PostgreSQL dispone de datos sintéticos, cinco consultas representativas
y una validación Docker exitosa del 29/08/2026, con veinticuatro controles de estado, cuatro controles
de comportamiento, diecisiete pruebas de integridad y una prueba de concurrencia. MongoDB y Redis
tienen también su implementación mínima verificada, de modo que las tres capas del diseño están
cubiertas y la propuesta multi-motor queda demostrada de punta a punta.

El motor de recomendaciones y la aplicación que lo consumiría permanecen como contexto del problema.
Analizamos qué debe entregarles la capa de datos, con qué latencia y bajo qué controles de acceso, y
qué riesgos aparecen cuando un modelo consume esos datos, pero no los construimos: el trabajo diseña
la base que los soportaría. Por la misma razón, la arquitectura contempla componentes que no se
implementan, como la capa analítica separada o la búsqueda por similitud, cuyo diseño queda
documentado con las condiciones que dispararían construirlos.

---

## Anexo. Decisiones para la primera versión y extensiones opcionales

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

Una vez validado el alcance mínimo, podremos evaluar la incorporación de algunos elementos
opcionales. Estas alternativas no son necesarias para que la primera versión responda a la consigna.
JSONB no está entre ellas porque ya se usa: los atributos variables del catálogo viven en
`product.attributes` y `sku.attributes`, y el contexto de la recomendación en
`recommendation.context`, los tres con sus índices GIN.

| Extensión | Posible uso |
| --- | --- |
| Embeddings y búsqueda vectorial | Similitud semántica entre descripciones, reseñas y preferencias. |
| Modelo de recomendación | Generación automática de puntuaciones a partir de compras, navegación o contenido. |
| Pagos y envíos detallados | Integración con proveedores, facturación, transportistas y seguimiento. |
| Carritos y promociones | Modelado de etapas previas a la compra y reglas comerciales más complejas. |
| Vinculación sesión anónima – cliente | Continuidad del comportamiento previo al registro. |
