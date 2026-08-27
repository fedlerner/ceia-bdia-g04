# Informe técnico

**Diseño de una capa de datos para recomendaciones personalizadas**
Tienda online de cosmética y perfumería

Carrera de Especialización en Inteligencia Artificial, FIUBA
Bases de Datos para Inteligencia Artificial
Año 2026, Grupo 04

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
verdad de ningún dato del modelo. Las recomendaciones, las sesiones y los rankings son **reconstruibles**: se derivan de PostgreSQL,
MongoDB y el motor. Los contadores operativos y la cuota de rate limit en curso **no lo son**, porque
son acumulados propios de Redis. Lo que comparten las cuatro estructuras es que su contenido es
**descartable**: perderlo es aceptable.

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

Se aceptan dos redundancias controladas: `unit_price_applied` preserva el precio de cada compra y
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

PostgreSQL se selecciona porque el núcleo contiene datos estructurados y fuertemente relacionados:
productos, variantes, precios, stock, clientes, pedidos e ítems. Las operaciones necesitan claves
foráneas, restricciones, transacciones ACID e integridad inmediata. Los patrones principales combinan
relaciones, filtros, agregaciones e historial temporal.

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
0,60 ms desde Redis. **Sólo el segundo número es una medición**: el lado del MISS no ejecuta
PostgreSQL, MongoDB ni el motor, porque ninguno está implementado todavía, sino que los sustituye por
una espera fija de 250 ms elegida como valor plausible. Lo que la corrida demuestra es el mecanismo y
el costo real de resolver desde Redis, no un benchmark del camino completo. La magnitud de la mejora
dependerá de cuánto tarde el motor cuando exista.

**Alternativas evaluadas:**

| Alternativa | Por qué se descartó |
| --- | --- |
| Cache en memoria del proceso backend | No se comparte entre instancias: cada réplica ejecutaría el motor por su cuenta y la tasa de aciertos caería al escalar horizontalmente. Tampoco sobrevive a un reinicio del proceso. |
| Vista materializada en PostgreSQL | Sirve para el ranking agregado, pero no para recomendaciones personalizadas por cliente y contexto. Además cargaría de escrituras la base transaccional y no ofrece expiración automática. |
| Memcached | Cubre la cache pura y también el rate limit, porque dispone de incremento atómico y de expiración. Lo que no ofrece son estructuras más allá del String: no resolvería la sesión como Hash ni el ranking como Sorted Set, que tendrían que serializarse y reescribirse enteros en cada actualización. |
| No usar cache | Cada solicitud ejecutaría el motor y el modelo de IA, que son los componentes más costosos de la arquitectura. |

**Complejidad operativa:** baja. La capa de datos es **un único servidor**, sin esquema que migrar y
sin persistencia que administrar. El compose levanta además dos contenedores auxiliares que no forman
parte del despliegue: RedisInsight, que es el visor web, y `demo`, que solo ejecuta el script de
medición.

**Limitaciones asumidas:** los datos viven en memoria y se pierden al reiniciar; con
`allkeys-lru` cualquier clave puede ser descartada bajo presión de memoria; y Redis no ofrece control
de acceso por clave comparable al Row Level Security de PostgreSQL. Las tres son aceptables porque
ningún dato de esta capa es fuente de verdad.

---

## 8. Implementación mínima realizada

La implementación mínima de PostgreSQL quedó ejecutada y validada. MongoDB continúa pendiente de
implementación.

| Componente | Estado |
| --- | --- |
| DDL PostgreSQL | Implementado y validado, en [`../db/estructura/`](../db/estructura/) |
| Carga de datos de ejemplo | Implementada y validada, en [`../db/datos/`](../db/datos/) |
| Índices y vistas | Implementados y validados, en [`../db/indices_vistas/`](../db/indices_vistas/) |
| Consultas SQL representativas | Cinco consultas implementadas y ejecutables, en [`../db/consultas/`](../db/consultas/) |
| Colección `user_events` en MongoDB | Modelo definido; creación y carga pendientes |
| **Redis** | **Implementado y verificado**, en [`../nosql/redis/`](../nosql/redis/) |

La capa relacional PostgreSQL se validó nuevamente con Docker Compose después de la revisión de la
PR: el contenedor alcanzó estado saludable y devolvieron `OK` veinte controles de estado, dos
controles de comportamiento, diez pruebas negativas de integridad y una prueba concurrente. El
procedimiento y la evidencia se encuentran en
[`../db/validacion/README.md`](../db/validacion/README.md).

La capa clave-valor está implementada por completo: `docker-compose.yml` con Redis 8.2 y
RedisInsight, script de carga con autovalidación, cinco archivos de comandos representativos y dos
demostraciones con evidencia medida (cache-aside y descarte por límite de memoria).

---

## 9. Datos de ejemplo utilizados

Disponibles en [`../data/ejemplos/`](../data/ejemplos/):

- `user_events.json`: documentos de ejemplo de los cuatro tipos de evento (`product_view`, `search`,
  `add_to_cart`, `purchase`).
- `redis_recommendations.json`: valor de ejemplo de la cache.

Los ocho productos del catálogo, clientes, pedidos, ítems y reseñas sintéticos están disponibles en
[`../db/datos/`](../db/datos/) y fueron utilizados en la validación de PostgreSQL.

---

## 10. Consultas representativas

Cinco consultas SQL sobre el modelo relacional, en [`../db/consultas/`](../db/consultas/):

1. **Catálogo activo con disponibilidad.** ¿Qué productos activos están disponibles, indicando
   marca, precio y stock? Consulta operativa central; podría implementarse como vista
   `v_active_catalog`.
2. **Ventas e ingresos por categoría y período.** ¿Qué categorías generan más unidades vendidas e
   ingresos? La categoría principal evita contar dos veces una misma venta.
3. **Frecuencia y valor de compra por cliente.** Señales transaccionales para segmentación y futuras
   recomendaciones, sin duplicar en PostgreSQL los eventos que pertenecen a MongoDB.
4. **Productos y SKU con stock bajo.** Reposición y exclusión de recomendaciones. Podría justificar
   un índice sobre `inventory(available_qty)`.
5. **Productos comprados conjuntamente.** Venta cruzada basada en compras reales; usa CTE,
   agregación y subconsulta `EXISTS` para validar disponibilidad.

Cuatro consultas sobre MongoDB, en [`../nosql/modelo_nosql.md`](../nosql/modelo_nosql.md): historial
reciente de un usuario, productos más interactuados, eventos de una sesión y productos más
visualizados.

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

### 13.1 Seguridad de la capa clave-valor (implementado)

| Aspecto | Decisión |
| --- | --- |
| Minimización | La sesión anónima guarda comportamiento, no identidad: `started_at`, `last_seen_at`, `events_count`, `last_product_id` y `preferred_category`. **No** almacena dirección IP, user agent, correo ni teléfono. |
| Retención | El TTL actúa como política de retención automática: la sesión desaparece sola a los 30 minutos de inactividad, sin proceso de purga. |
| Qué se guarda del cliente | El valor está minimizado por atributos: sólo identificadores de producto y puntuaciones, sin nombre, correo ni teléfono. La clave sí incorpora el código externo seudónimo (`reco:user:{customer_code}:...`), acotado por el TTL como retención máxima y protegido por el control de acceso del backend. |
| Aislamiento | El prefijo de la clave separa los espacios de nombres, y el discriminador `user` / `sess` evita que una sesión anónima resuelva contra la entrada de un cliente registrado. |
| Acceso | `requirepass` activo y puerto publicado únicamente en `127.0.0.1`. |
| Protección del motor de IA | El rate limit por cliente y ventana acota cuántas veces puede invocarse el motor de recomendaciones y el modelo, que son los recursos más costosos. |

**Limitación reconocida del rate limit.** Los contadores `ratelimit:*` están sujetos a la política de
descarte igual que el resto de las claves. Bajo presión de memoria, `allkeys-lru` puede desalojarlos y
el siguiente `INCR` los recrea en 1, con lo que el límite **falla abierto durante una sobrecarga**.
Se verificó forzando el límite de memoria con un contador en 30 de 30: la clave fue descartada y el
`INCR` siguiente devolvió 1. Redis no permite asignar prioridad de desalojo por clave, de modo que
protegerlos exigiría una instancia o base independiente. Se acepta dentro de este alcance porque la
función del límite es acotar el uso normal y no resistir un abuso deliberado.

**Limitación reconocida:** Redis no ofrece roles ni permisos por clave comparables al Row Level
Security de PostgreSQL. El control de acceso real vive en el backend, que debe ser el único
componente que hable con Redis. Exponer Redis directamente a un cliente permitiría leer las claves de
cualquier otro usuario, ya que basta conocer el identificador para construir la clave.

---

## 14. Consideraciones de escalabilidad y rendimiento

**Pendiente de desarrollar.** Elementos ya definidos que deben servir de base:

- Las estructuras que más crecerían son la colección `user_events` y las tablas de pedidos e ítems.
- Los eventos se mantienen separados del modelo transaccional para no sobrecargarlo con un volumen que
  crece continuamente y tiene propósito principalmente analítico.
- La Time Series Collection organiza eficientemente datos que se agregan continuamente y se consultan
  por rangos temporales.
- Redis precalcula y reutiliza las recomendaciones ya generadas, con TTL de 5 a 15 minutos.
- Índices candidatos: `(customer_id, event_type, occurred_at)` sobre eventos e
  `inventory(available_qty)`.
- Vista candidata: `v_active_catalog`.

Falta desarrollar: qué datos podrían particionarse, qué componentes podrían separarse y qué
compromisos existen entre simplicidad, rendimiento, consistencia y costo.

### 14.1 Escalabilidad de la capa clave-valor (implementado)

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
resolver la solicitud desde memoria. El costo del acierto está medido en 0,60 ms; el del fallo
todavía no puede medirse, porque el motor no está implementado y el demo lo sustituye por una espera
fija de 250 ms. La relación entre ambos ilustra el orden de magnitud esperable, no un resultado
verificado del camino completo.

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

La implementación mínima de PostgreSQL quedó validada con datos sintéticos, cinco consultas
representativas, veinte controles de estado, dos controles de comportamiento, diez pruebas
negativas y una prueba de concurrencia. MongoDB continúa como componente pendiente de
implementación; por eso la solución
multi-motor todavía no debe considerarse cerrada.

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
