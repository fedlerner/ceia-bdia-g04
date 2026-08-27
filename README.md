# Trabajo Práctico Integrador: Bases de Datos para Inteligencia Artificial

**Diseño de una capa de datos para recomendaciones personalizadas**
Tienda online de cosmética y perfumería

Carrera de Especialización en Inteligencia Artificial (CEIA), FIUBA
Materia: Bases de Datos para Inteligencia Artificial
Docente: Martín Lacheski
Año: 2026
Grupo 04

---

## Integrantes del grupo

| Integrante | N° SIU |
| --- | --- |
| Abdon, Juan Bautista | a2601 |
| Lerner, Federico Ezequiel | a2619 |
| Paredes Ramirez, Luis Jose | a2627 |
| Ruggeri, César Hernán | a2413 |

---

## Caso de uso elegido

**Caso 2 de la consigna: sistema de recomendación para comercio electrónico**, con la impronta
propia del grupo: una **única tienda online de cosmética y perfumería** que registra su catálogo,
disponibilidad, ventas, comportamiento de navegación y opiniones de clientes para generar
recomendaciones personalizadas y apoyar decisiones comerciales.

## Descripción breve de la solución

El trabajo diseña la **capa de datos** que permitiría almacenar, consultar, organizar, proteger y
escalar la información que usaría una futura solución de recomendaciones personalizadas. No incluye
entrenar un modelo de recomendación ni desarrollar una aplicación completa.

Elementos centrales del diseño:

- Separación entre **producto** (concepto comercial) y **SKU / variante** (unidad concreta vendible);
  el precio y el stock se controlan por SKU.
- Conservación del **precio aplicado** en cada ítem de pedido, para no perder la historia comercial
  cuando cambian los precios vigentes.
- Registro de **eventos de interacción** asociados a un cliente identificado o a una sesión anónima.
- **Pagos y envíos** representados únicamente mediante estados simples del pedido (sin datos de
  tarjetas ni integraciones reales).
- Catálogo validado con ocho productos ficticios, pero **extensible** sin modificar la estructura.

## Datos principales identificados

| Grupo | Datos |
| --- | --- |
| Catálogo | Producto, SKU, marca, categoría, estado, fechas de alta/modificación |
| Comercial | Precio vigente, stock disponible, umbral de stock bajo |
| Usuarios | Identificador, nombre, correo, fecha de alta, estado |
| Pedidos | Cliente, fecha, estado de pedido, de pago y de envío, total |
| Ítems de pedido | Pedido, SKU, cantidad, precio aplicado |
| Interacciones | Tipo de evento, cliente o sesión, producto/SKU, consulta, fecha-hora |
| Reseñas | Cliente, producto, calificación, texto, fecha, estado de moderación |
| Recomendaciones | Cliente o sesión, producto/SKU, posición, puntuación, método, fecha |

El detalle por tipo de dato (estructurado, semiestructurado, no estructurado, operacional, analítico,
sensible y de auditoría) está en [docs/informe.md](docs/informe.md).

## Tecnologías propuestas

| Tecnología | Rol en la solución |
| --- | --- |
| **PostgreSQL** | Datos transaccionales y de catálogo: productos, SKU, precios, inventario, clientes, pedidos, reseñas y recomendaciones persistentes. **Implementado** en [`db/`](db/). |
| **MongoDB** (Time Series Collection) | Eventos de comportamiento del usuario (`user_events`): alto volumen de escritura, esquema flexible, consulta por rangos temporales. |
| **Redis** | Capa clave-valor: cache de recomendaciones, sesiones de visitantes anónimos, rankings precalculados y rate limit del motor. **Implementado** en [`nosql/redis/`](nosql/redis/). |

La justificación de cada elección está en [docs/informe.md](docs/informe.md) y en
[nosql/modelo_nosql.md](nosql/modelo_nosql.md).

La **búsqueda vectorial y los embeddings quedan fuera del alcance de esta versión**; la justificación
está en [vectorial/modelo_vectorial.md](vectorial/modelo_vectorial.md).

## Estructura del repositorio

```text
.
├── README.md                       # Este archivo
├── docker-compose.yml              # Compose unificado (include de cada componente)
├── docs/
│   ├── informe.md                  # Informe técnico (15 puntos de la consigna)
│   ├── modelo_conceptual.md        # Entidades, atributos, relaciones, reglas y diagrama ER
│   ├── modelo_logico_relacional.md # Tablas, claves, normalización, integración y diagrama UML
│   ├── modelo_fisico.md            # Diagrama físico PostgreSQL, índices, triggers y notas NoSQL
│   └── arquitectura.md             # Arquitectura de datos y flujo de recomendación
├── data/
│   └── ejemplos/                   # Documentos y registros de ejemplo
├── db/                             # PostgreSQL
│   ├── docker-compose.yml           #   PostgreSQL 16
│   ├── .env.example                 #   configuración local sin secretos reales
│   ├── estructura/                 # Scripts DDL
│   ├── datos/                      # Carga de datos de ejemplo
│   ├── consultas/                  # Consultas representativas (punto 8)
│   ├── indices_vistas/             # Índices y vistas
│   └── validacion/                 # Controles automáticos
├── nosql/
│   ├── modelo_nosql.md             # Modelo MongoDB (eventos) y Redis (clave-valor)
│   └── redis/                      # Implementación de la capa clave-valor
│       ├── docker-compose.yml      #   Redis 8.2 + RedisInsight + demo
│       ├── comandos/               #   5 archivos de comandos representativos
│       ├── scripts/                #   carga, reinicio y demos con medición
│       └── datos/                  #   estado inicial
├── vectorial/
│   └── modelo_vectorial.md         # Análisis de la necesidad de búsqueda por similitud
└── anexos/
    └── material_complementario.md  # Fuentes, consigna y material de trabajo del grupo
```

## Cómo ejecutar o revisar la implementación mínima

### Levantar la solución

El [`docker-compose.yml`](docker-compose.yml) de la raíz incorpora el compose de cada componente
mediante `include:`, de modo que un solo comando levanta los que estén incorporados. Cada componente
conserva su propio archivo y su propio `.env`.

**Hoy levanta PostgreSQL y Redis**, que son los componentes implementados. El bloque de MongoDB está
escrito y comentado en el compose de la raíz, a la espera de que exista su archivo: cuando se
incorpore, descomentarlo lo suma sin tocar nada más. El estado de cada componente está en
[docs/ESTADO.md](docs/ESTADO.md).

> `include:` requiere **Docker Compose 2.20 o posterior**. Con una versión anterior, el comando falla
> antes de levantar ningún servicio. La versión instalada se comprueba con `docker compose version`;
> si es más antigua, cada componente puede levantarse por separado desde su propio directorio.

Antes de levantar la pila, cada componente necesita su `.env` creado a partir de su `.env.example`:

```bash
cp nosql/redis/.env.example nosql/redis/.env
cp db/.env.example db/.env
```

```bash
docker compose up -d --wait
```

Si falta algún `.env`, Compose corta e indica cuál. MongoDB se incorporará al compose cuando exista
su implementación.

Cada componente puede levantarse también por separado, desde su propio directorio. Conviene no correr
las dos formas a la vez: los nombres de contenedor son los mismos y entrarían en conflicto.

### Redis (implementado)

Carga del estado inicial y verificación:

```bash
docker compose exec redis sh /scripts/00_cargar_datos.sh
```

Los comandos representativos están en [`nosql/redis/comandos/`](nosql/redis/comandos/) y el detalle
de la puesta en marcha en [nosql/redis/README.md](nosql/redis/README.md).

### PostgreSQL (implementado y validado)

PostgreSQL puede levantarse junto con Redis desde la raíz o de manera aislada desde `db/`:

```bash
cd db
cp .env.example .env
docker compose up -d --wait
docker compose logs postgres
```

El contenedor ejecuta en orden:

1. `db/estructura/`: creación de tablas, claves y restricciones.
2. `db/indices_vistas/`: creación de índices y vistas.
3. `db/datos/`: carga del catálogo y datos sintéticos.
4. `db/consultas/`: ejecución de las 5 consultas representativas.
5. `db/validacion/`: controles automáticos.

La validación empírica se repitió el 25/08/2026 con PostgreSQL 16 mediante Docker Compose después de
la revisión de la PR. El contenedor quedó `Up (healthy)` y finalizaron correctamente veinte
controles de estado, nueve pruebas negativas y una prueba de concurrencia; su procedimiento
reproducible está documentado en
[`db/validacion/README.md`](db/validacion/README.md).

### MongoDB (pendiente)

Falta crear la colección `user_events`, cargar los eventos de ejemplo y registrar la ejecución de
sus consultas.

## Principales decisiones de diseño

1. Una única tienda online; modelo relacional para los datos estructurados.
2. Separar producto y SKU; administrar precio y stock por SKU.
3. Conservar el precio aplicado en el ítem de pedido.
4. Representar pagos y envíos mediante estados simples del pedido.
5. Registrar eventos de clientes identificados **o** de sesiones anónimas (al menos uno de los dos).
6. Almacenar los eventos en MongoDB, separados del modelo transaccional, por volumen, frecuencia de
   escritura, inmutabilidad y variabilidad de sus metadatos.
7. Usar Redis como capa clave-valor para los datos temporales, descartables y sensibles a la
   latencia: cache de recomendaciones, sesiones anónimas, rankings precalculados y rate limit. Redis
   no es fuente de verdad de ningún dato del modelo. La cache, las sesiones y los rankings además se
   reconstruyen desde los otros motores; los contadores y la cuota en curso no, pero perderlos es
   aceptable.
8. No entrenar un modelo de IA ni desarrollar una aplicación completa en esta etapa.

## Consultas incluidas

| # | Pregunta de negocio | Motor |
| --- | --- | --- |
| 1 | ¿Qué productos activos están disponibles, indicando marca, precio y stock? | PostgreSQL |
| 2 | ¿Qué categorías generan más unidades vendidas e ingresos en un período? | PostgreSQL |
| 3 | ¿Qué clientes concentran mayor frecuencia y valor de compra? | PostgreSQL |
| 4 | ¿Qué productos y SKU tienen stock bajo? | PostgreSQL |
| 5 | ¿Qué productos suelen comprarse junto con un producto determinado? | PostgreSQL |
| 6 | Historial reciente de eventos de un usuario | MongoDB |
| 7 | Productos más interactuados por un usuario | MongoDB |
| 8 | Eventos de una sesión | MongoDB |
| 9 | Productos más visualizados (analítica general) | MongoDB |
| 10 | Servir e invalidar la cache de recomendaciones | Redis |
| 11 | Sostener el estado de una sesión anónima | Redis |
| 12 | Top de productos más vistos precalculado | Redis |
| 13 | Acotar invocaciones al motor por cliente y ventana | Redis |
| 14 | Patrones de búsqueda, memoria y descarte por límite | Redis |

Las consultas SQL están en [db/consultas/](db/consultas/), las de MongoDB en
[nosql/modelo_nosql.md](nosql/modelo_nosql.md) y los comandos de Redis en
[nosql/redis/comandos/](nosql/redis/comandos/).

## Limitaciones y posibles mejoras

Limitaciones asumidas en esta versión:

- Alcance de una única tienda online.
- Pagos y envíos sólo como estados simples del pedido.
- Sin procesamiento de imágenes, embeddings ni búsqueda vectorial.
- Sin un flujo automático para vincular una sesión anónima con un cliente que se registra después.
- Sin modelado de carritos ni promociones.

Extensiones posibles:

| Extensión | Posible uso |
| --- | --- |
| JSONB en PostgreSQL | Atributos variables de productos, parámetros de búsqueda, metadatos de recomendaciones |
| Embeddings y búsqueda vectorial | Similitud semántica entre descripciones, reseñas y preferencias |
| Modelo de recomendación | Generación automática de puntuaciones a partir de compras, navegación o contenido |
| Pagos y envíos detallados | Integración con proveedores, facturación, transportistas y seguimiento |
| Carritos y promociones | Etapas previas a la compra y reglas comerciales más complejas |
