# Trabajo Práctico Integrador — Bases de Datos para Inteligencia Artificial

**Diseño de una capa de datos para recomendaciones personalizadas**
Tienda online de cosmética y perfumería

Carrera de Especialización en Inteligencia Artificial (CEIA) — FIUBA
Materia: Bases de Datos para Inteligencia Artificial — Docente: Martín Lacheski — Año: 2026
Grupo 04

---

## Integrantes del grupo

> **Pendiente de completar.** La consigna exige evidenciar la participación de cada integrante
> mediante commits en el repositorio; si alguna parte se realizó fuera del repositorio, debe
> documentarse aquí qué aportes hizo cada uno.

| Integrante | Rol / aportes principales |
| --- | --- |
| _(completar)_ | _(completar)_ |

---

## Caso de uso elegido

**Caso 2 de la consigna — Sistema de recomendación para comercio electrónico**, con la impronta
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
| **PostgreSQL** | Datos transaccionales y de catálogo: productos, SKU, inventario, pedidos, reseñas. Fuente de verdad del estado del negocio. |
| **MongoDB** (Time Series Collection) | Eventos de comportamiento del usuario (`user_events`): alto volumen de escritura, esquema flexible, consulta por rangos temporales. |
| **Redis** | Cache de corto plazo (TTL de 5 a 15 minutos) de las recomendaciones generadas, por usuario y contexto. |

La justificación de cada elección está en [docs/informe.md](docs/informe.md) y en
[nosql/modelo_nosql.md](nosql/modelo_nosql.md).

La **búsqueda vectorial y los embeddings quedan fuera del alcance de esta versión**; la justificación
está en [vectorial/modelo_vectorial.md](vectorial/modelo_vectorial.md).

## Estructura del repositorio

```text
.
├── README.md                       # Este archivo
├── docs/
│   ├── informe.md                  # Informe técnico (15 puntos de la consigna)
│   ├── modelo_conceptual.md        # Entidades, atributos, relaciones y reglas de negocio
│   ├── arquitectura.md             # Arquitectura de datos y flujo de recomendación
│   └── (diagramas .png a exportar)
├── data/
│   └── ejemplos/                   # Documentos y registros de ejemplo
├── db/                             # PostgreSQL
│   ├── estructura/                 # Scripts DDL
│   ├── datos/                      # Carga de datos de ejemplo
│   ├── consultas/                  # Consultas representativas (punto 8)
│   └── indices_vistas/             # Índices y vistas
├── nosql/
│   └── modelo_nosql.md             # Modelo MongoDB (eventos) y Redis (cache)
├── vectorial/
│   └── modelo_vectorial.md         # Análisis de la necesidad de búsqueda por similitud
└── anexos/
    └── material_complementario.md  # Fuentes, consigna y material de trabajo del grupo
```

## Cómo ejecutar o revisar la implementación mínima

> **Pendiente.** Los scripts de `db/` y la carga de datos de ejemplo todavía no están implementados.
> Ver [docs/ESTADO.md](docs/ESTADO.md) para el detalle de lo que falta.

Orden previsto de ejecución una vez implementado:

1. `db/estructura/` — creación de tablas, claves y restricciones.
2. `db/datos/` — carga de datos de ejemplo (catálogo de 8 productos + datos sintéticos).
3. `db/indices_vistas/` — creación de índices y vistas.
4. `db/consultas/` — ejecución de las 5 consultas representativas.
5. `nosql/` — creación de la colección `user_events` y carga de eventos de ejemplo.

## Principales decisiones de diseño

1. Una única tienda online; modelo relacional para los datos estructurados.
2. Separar producto y SKU; administrar precio y stock por SKU.
3. Conservar el precio aplicado en el ítem de pedido.
4. Representar pagos y envíos mediante estados simples del pedido.
5. Registrar eventos de clientes identificados **o** de sesiones anónimas (al menos uno de los dos).
6. Almacenar los eventos en MongoDB, separados del modelo transaccional, por volumen, frecuencia de
   escritura, inmutabilidad y variabilidad de sus metadatos.
7. Usar Redis como cache de recomendaciones para evitar reejecutar el motor ante solicitudes
   repetidas en un período reducido.
8. No entrenar un modelo de IA ni desarrollar una aplicación completa en esta etapa.

## Consultas incluidas

| # | Pregunta de negocio | Motor |
| --- | --- | --- |
| 1 | ¿Qué productos activos están disponibles, indicando marca, precio y stock? | PostgreSQL |
| 2 | ¿Qué categorías generan más unidades vendidas e ingresos en un período? | PostgreSQL |
| 3 | ¿Qué productos visitó recientemente un cliente y todavía no compró? | PostgreSQL |
| 4 | ¿Qué productos y SKU tienen stock bajo? | PostgreSQL |
| 5 | ¿Qué productos suelen comprarse junto con un producto determinado? | PostgreSQL |
| 6 | Historial reciente de eventos de un usuario | MongoDB |
| 7 | Productos más interactuados por un usuario | MongoDB |
| 8 | Eventos de una sesión | MongoDB |
| 9 | Productos más visualizados (analítica general) | MongoDB |

Las consultas SQL están en [db/consultas/](db/consultas/) y las de MongoDB en
[nosql/modelo_nosql.md](nosql/modelo_nosql.md).

## Limitaciones y posibles mejoras

Limitaciones asumidas en esta versión:

- Alcance de una única tienda online.
- Pagos y envíos sólo como estados simples del pedido.
- Sin procesamiento de imágenes, embeddings ni búsqueda vectorial.
- Sin vinculación entre una sesión anónima y un cliente que se registra posteriormente.
- Sin modelado de carritos ni promociones.

Extensiones posibles:

| Extensión | Posible uso |
| --- | --- |
| JSONB en PostgreSQL | Atributos variables de productos, parámetros de búsqueda, metadatos de recomendaciones |
| Embeddings y búsqueda vectorial | Similitud semántica entre descripciones, reseñas y preferencias |
| Modelo de recomendación | Generación automática de puntuaciones a partir de compras, navegación o contenido |
| Pagos y envíos detallados | Integración con proveedores, facturación, transportistas y seguimiento |
| Carritos y promociones | Etapas previas a la compra y reglas comerciales más complejas |
