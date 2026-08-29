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
├── Makefile                        # Atajos make para levantar, cargar y validar
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
│   ├── seguridad/                  # Roles y privilegios mínimos
│   ├── validacion/                 # Controles automáticos
│   └── scripts/                    # Validación reproducible con Docker
├── nosql/
│   ├── modelo_nosql.md             # Modelo MongoDB (eventos) y Redis (clave-valor)
│   ├── mongodb/                    # Implementación de la capa documental
│   │   ├── README.md               #   puesta en marcha del componente
│   │   ├── docker-compose.yml      #   MongoDB 8.0 + mongo-express
│   │   ├── Makefile                #   make generar-datos y make shell
│   │   ├── generar_datos.js        #   crea user_events, valida el seed y carga
│   │   ├── seed_data.json          #   22 eventos de ejemplo
│   │   └── consultas/              #   8 consultas representativas
│   └── redis/                      # Implementación de la capa clave-valor
│       ├── README.md               #   puesta en marcha del componente
│       ├── docker-compose.yml      #   Redis 8.2 + RedisInsight + demo
│       ├── comandos/               #   5 archivos de comandos representativos
│       ├── scripts/                #   carga, reinicio y demos con medición
│       └── datos/                  #   estado inicial
├── vectorial/
│   └── modelo_vectorial.md         # Análisis de la necesidad de búsqueda por similitud
└── anexos/
    └── material_complementario.md  # Fuentes, consigna y nuestro material de trabajo
```

## Dónde está cada punto de la consigna

| # | Punto | Dónde |
| --- | --- | --- |
| 1 | Análisis del caso de uso | [`docs/informe.md`](docs/informe.md) §1 |
| 2 | Relevamiento de datos necesarios | [`docs/informe.md`](docs/informe.md) §2 y §3 |
| 3 | Modelo conceptual | [`docs/modelo_conceptual.md`](docs/modelo_conceptual.md), con diagrama ER |
| 4 | Modelo lógico o equivalente | [`docs/modelo_logico_relacional.md`](docs/modelo_logico_relacional.md), [`db/estructura/`](db/estructura/), [`nosql/modelo_nosql.md`](nosql/modelo_nosql.md) |
| 5 | Normalización y decisiones de diseño | [`docs/informe.md`](docs/informe.md) §6 |
| 6 | Selección tecnológica | [`docs/informe.md`](docs/informe.md) §7 |
| 7 | Modelo físico e implementación mínima | [`docs/modelo_fisico.md`](docs/modelo_fisico.md), [`db/`](db/), [`nosql/mongodb/`](nosql/mongodb/), [`nosql/redis/`](nosql/redis/) |
| 8 | Consultas representativas | [`db/consultas/`](db/consultas/), [`nosql/mongodb/consultas/`](nosql/mongodb/consultas/), [`nosql/redis/comandos/`](nosql/redis/comandos/) |
| 9 | Semiestructurados, no estructurados y vectorial | [`vectorial/modelo_vectorial.md`](vectorial/modelo_vectorial.md), [`docs/informe.md`](docs/informe.md) §11 |
| 10 | Arquitectura de datos | [`docs/arquitectura.md`](docs/arquitectura.md), [`docs/informe.md`](docs/informe.md) §12 |
| 11 | Seguridad, permisos y aislamiento | [`docs/informe.md`](docs/informe.md) §13, [`db/seguridad/`](db/seguridad/) |
| 12 | Escalabilidad y rendimiento | [`docs/informe.md`](docs/informe.md) §14 |

## Cómo ejecutar o revisar la implementación mínima

### Levantar la solución

El [`docker-compose.yml`](docker-compose.yml) de la raíz incorpora el compose de cada componente
mediante `include:`, de modo que un solo comando levanta los que estén incorporados. Cada componente
conserva su propio archivo y su propio `.env`.

**Levanta los tres componentes**: PostgreSQL, Redis y MongoDB, cada uno incorporado desde el compose
de su propio directorio.

> `include:` requiere **Docker Compose 2.20 o posterior**. Con una versión anterior, el comando falla
> antes de levantar ningún servicio. La versión instalada se comprueba con `docker compose version`;
> si es más antigua, cada componente puede levantarse por separado desde su propio directorio.

El [`Makefile`](Makefile) de la raíz envuelve la puesta en marcha, la carga de datos de prueba y las
verificaciones de los tres motores. Con `make help` se listan todos los targets disponibles.

Para levantar la pila, crear los datos de prueba de las tres bases y validarlos de una vez:

```bash
make setup
```

Ese comando crea los `.env` faltantes, levanta los tres motores y, en orden, verifica PostgreSQL,
recrea y carga la colección de MongoDB y restaura y verifica el estado inicial de Redis.

Los targets individuales equivalentes son:

```bash
make env      # crea los .env a partir de los .env.example (solo si faltan)
make up       # docker compose up -d --wait
make down     # docker compose down
```

`up` deja los tres motores arriba, pero **solo PostgreSQL queda con datos**. Sus scripts se montan en
`/docker-entrypoint-initdb.d/` y el motor los ejecuta en el primer arranque, de modo que el healthcheck
no da la base por sana hasta que terminaron el esquema, los índices, los datos de ejemplo, los roles y
la validación. Redis y MongoDB arrancan vacíos a propósito, y cargarlos es un paso explícito
(`make setup` lo hace). Si falta algún `.env`, Compose corta e indica cuál.

Cada componente puede levantarse también por separado, desde su propio directorio. Conviene no correr
las dos formas a la vez: los nombres de contenedor son los mismos y entrarían en conflicto.

Para que las dos formas de arranque funcionen sin retoques, los tres componentes siguen las mismas
convenciones:

- compose propio, con los puertos tomados de un `.env` local y publicados solo en `127.0.0.1`;
- todas las variables interpoladas con `${VAR:?mensaje}`, para que un `.env` ausente o incompleto
  aborte Compose en lugar de levantar el motor mal configurado;
- `container_name` con el prefijo `bdia_g04_`, para que no colisionen;
- la red `bdia_g04_network`, la misma en los tres;
- volúmenes con `name:` explícito, para que levantar desde el directorio del componente y levantar
  desde la raíz compartan los datos en lugar de crear uno por proyecto;
- `.env.example` versionado y `.env` ignorado por git;
- una carga que verifique lo que dejó y devuelva error si algo no cuadra.

### Redis

Carga del estado inicial y verificación, y consola interactiva:

```bash
make redis.seed
make redis.shell
```

Demos con medición:

```bash
make redis.demo-cache    # latencia MISS vs HIT (patron cache-aside)
make redis.demo-memory   # eviccion al alcanzar el limite de memoria
```

Los comandos representativos están en [`nosql/redis/comandos/`](nosql/redis/comandos/) y el detalle
de la puesta en marcha en [nosql/redis/README.md](nosql/redis/README.md).

### MongoDB

Creación de la colección `user_events`, carga de los eventos de ejemplo y consola `mongosh`:

```bash
make mongo.seed
make mongo.shell
```

El script verifica lo que cargó y devuelve error si algo no cuadra. Las consultas representativas
están en [`nosql/mongodb/consultas/`](nosql/mongodb/consultas/) y el detalle de la puesta en marcha
en [nosql/mongodb/README.md](nosql/mongodb/README.md).

### PostgreSQL

PostgreSQL puede levantarse junto con el resto desde la raíz o de manera aislada desde `db/`.

El contenedor ejecuta en orden:

1. `db/estructura/`: creación de tablas, claves y restricciones.
2. `db/indices_vistas/`: creación de índices y vistas.
3. `db/datos/`: carga del catálogo y datos sintéticos.
4. `db/consultas/`: ejecución de las 6 consultas representativas.
5. `db/seguridad/`: creación de roles y privilegios mínimos.
6. `db/validacion/`: controles automáticos y marca de inicialización correcta.

Los datos se cargan en el primer arranque. Para re-ejecutar las consultas y las verificaciones sobre
un contenedor ya levantado:

```bash
make postgresql.shell        # consola psql
make postgresql.queries      # re-ejecuta las 6 consultas
make postgresql.checks       # 24 controles de estado
make postgresql.integrity    # 17 pruebas de integridad
make postgresql.concurrency  # 1 prueba de concurrencia
make postgresql.verify       # las cuatro anteriores juntas
```

La validación empírica actualizada se ejecutó correctamente el 29/08/2026 mediante Docker Compose
con PostgreSQL 16. El contenedor quedó `Up (healthy)` y finalizaron correctamente las seis
consultas, veinticuatro controles de estado, cuatro controles de comportamiento, diecisiete pruebas de
integridad y una prueba de concurrencia. El procedimiento reproducible está documentado en
[`db/validacion/README.md`](db/validacion/README.md).

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
| 6 | ¿En qué posición queda cada producto por ingresos dentro de su moneda? | PostgreSQL |
| 7 | ¿Qué hizo un usuario en los últimos siete días? | MongoDB |
| 8 | ¿Qué productos concentran el interés reciente de un usuario? | MongoDB |
| 9 | ¿Qué recorrido hizo el usuario dentro de una sesión? | MongoDB |
| 10 | ¿Qué productos reciben más visualizaciones? | MongoDB |
| 11 | ¿Qué categorías concentran la atención de los usuarios? | MongoDB |
| 12 | ¿Cuántas búsquedas realiza cada usuario? | MongoDB |
| 13 | ¿Qué productos se ven mucho pero se agregan poco al carrito? | MongoDB |
| 14 | ¿Cuánta actividad concentra cada sesión y cuánto dura? | MongoDB |
| 15 | Servir e invalidar la cache de recomendaciones | Redis |
| 16 | Sostener el estado de una sesión anónima | Redis |
| 17 | Top de productos más vistos precalculado | Redis |
| 18 | Acotar invocaciones al motor por cliente y ventana | Redis |
| 19 | Patrones de búsqueda, memoria y descarte por límite | Redis |

Las consultas SQL están en [db/consultas/](db/consultas/), las de MongoDB en
[nosql/mongodb/consultas/](nosql/mongodb/consultas/) y los comandos de Redis en
[nosql/redis/comandos/](nosql/redis/comandos/).

## Limitaciones y posibles mejoras

Limitaciones asumidas en esta versión:

- Alcance de una única tienda online.
- Pagos y envíos solo como estados simples del pedido.
- Sin procesamiento de imágenes, embeddings ni búsqueda vectorial.
- Sin un flujo automático para vincular una sesión anónima con un cliente que se registra después.
- Sin modelado de carritos ni promociones.
- Las consultas analíticas se resuelven contra la misma instancia que atiende la operación.

JSONB en PostgreSQL no figura entre las extensiones porque ya está en uso: `product.attributes`,
`sku.attributes` y `recommendation.context` guardan los atributos variables, con índices GIN que los
hacen consultables.

Extensiones posibles:

| Extensión | Posible uso |
| --- | --- |
| Embeddings y búsqueda vectorial | Similitud semántica entre descripciones, reseñas y preferencias |
| Modelo de recomendación | Generación automática de puntuaciones a partir de compras, navegación o contenido |
| Pagos y envíos detallados | Integración con proveedores, facturación, transportistas y seguimiento |
| Carritos y promociones | Etapas previas a la compra y reglas comerciales más complejas |
| Réplica de solo lectura de PostgreSQL | Atender las consultas del analista sin competir con la operación; analizada en [`docs/informe.md`](docs/informe.md) §14.3 |
