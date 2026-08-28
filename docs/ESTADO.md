# Estado del trabajo por punto de la consigna

Mapa de qué está volcado al repositorio y qué falta desarrollar. Sirve para repartir el trabajo entre
los integrantes del grupo.

Estados posibles: **Completo**, **Parcial** y **Pendiente**.

## Actividades a realizar (12 puntos)

| # | Actividad | Estado | Dónde | Qué falta |
| --- | --- | --- | --- | --- |
| 1 | Análisis del caso de uso | Completo | [`informe.md` §1](informe.md) | Nada |
| 2 | Relevamiento de datos necesarios | Completo | [`informe.md` §2–3](informe.md) | Nada |
| 3 | Modelo conceptual | Completo | [`modelo_conceptual.md`](modelo_conceptual.md) | Nada (diagrama ER incorporado como Mermaid embebido; exportar a PNG es opcional para la entrega final) |
| 4 | Modelo lógico o equivalente | Completo | [`informe.md` §5](informe.md), [`../db/estructura/`](../db/estructura/), diagrama UML en [`modelo_logico_relacional.md`](modelo_logico_relacional.md), [`../nosql/modelo_nosql.md`](../nosql/modelo_nosql.md) | Nada |
| 5 | Normalización y decisiones de diseño | Completo | [`informe.md` §6](informe.md) | Nada. §6 cubre la tercera forma normal del modelo relacional con sus dos redundancias controladas, la colección única de MongoDB con referencias en lugar de embebido, y la duplicación deliberada de Redis en §6.1 |
| 6 | Selección tecnológica | Completo | [`informe.md` §7](informe.md) | Nada. Los tres motores están justificados: PostgreSQL en §7.1 contra los diez criterios que enumera la consigna, MongoDB en §7.2 y Redis en §7.3, este último con sus alternativas descartadas |
| 7 | Modelo físico e implementación mínima | Completo | [`../nosql/redis/`](../nosql/redis/), [`../nosql/mongodb/`](../nosql/mongodb/), [`../db/`](../db/), diagrama en [`modelo_fisico.md`](modelo_fisico.md) | Los tres motores están implementados y verificados |
| 8 | Consultas representativas | Completo | [`../db/consultas/`](../db/consultas/), [`../nosql/redis/comandos/`](../nosql/redis/comandos/), [`../nosql/mongodb/consultas/`](../nosql/mongodb/consultas/) | Las cinco consultas de PostgreSQL se ejecutan durante la inicialización; los comandos de Redis y las ocho consultas de MongoDB fueron ejecutados y verificados contra su estado inicial |
| 9 | Semiestructurados, no estructurados y vectorial | Parcial | [`../vectorial/modelo_vectorial.md`](../vectorial/modelo_vectorial.md) | Cerrar los cinco ítems que pide la consigna, en especial los riesgos |
| 10 | Arquitectura de datos | Parcial | [`arquitectura.md`](arquitectura.md) | Ingesta, capa analítica, justificación del enfoque arquitectónico, `arquitectura.png` |
| 11 | Seguridad, permisos y aislamiento | Completo | [`informe.md` §13](informe.md), [`../db/seguridad/`](../db/seguridad/) | Los tres motores están cubiertos: PostgreSQL en §13.1, la capa clave-valor en §13.2 y la documental en §13.3. Las medidas para una futura aplicación conectada a IA quedan como propuesta porque esa aplicación está fuera del alcance |
| 12 | Escalabilidad y rendimiento | Completo | [`informe.md` §14](informe.md) | Los tres motores tienen su análisis con evidencia medida: clave-valor en §14.1, documental en §14.2 y relacional en §14.3, cada uno con qué crece, qué lo acota, qué haría falta al escalar y el compromiso asumido |

## Entregables mínimos exigidos

| Entregable | Estado | Dónde |
| --- | --- | --- |
| Informe técnico | Parcial | [`informe.md`](informe.md) → exportar a `informe.pdf` |
| Modelo conceptual | Completo | [`modelo_conceptual.md`](modelo_conceptual.md) (incluye diagrama ER) |
| Modelo lógico relacional o equivalente | Completo | Relacional en [`../db/estructura/`](../db/estructura/) y su diagrama UML en [`modelo_logico_relacional.md`](modelo_logico_relacional.md); documental y clave-valor en [`../nosql/`](../nosql/) |
| Modelo físico o equivalente | Completo | PostgreSQL en [`../db/`](../db/) (diagrama en [`modelo_fisico.md`](modelo_fisico.md)), MongoDB en [`../nosql/mongodb/`](../nosql/mongodb/) y Redis en [`../nosql/redis/`](../nosql/redis/) |
| Arquitectura general de datos | Parcial | [`arquitectura.md`](arquitectura.md) |
| Archivos de implementación mínima | Completo | PostgreSQL en [`../db/`](../db/), MongoDB en [`../nosql/mongodb/`](../nosql/mongodb/) y Redis en [`../nosql/redis/`](../nosql/redis/) |
| Datos de ejemplo | Completo | Catálogo y transacciones en [`../db/datos/`](../db/datos/), eventos en [`../data/ejemplos/`](../data/ejemplos/) y [`../nosql/mongodb/seed_data.json`](../nosql/mongodb/seed_data.json), y estado Redis en [`../nosql/redis/datos/`](../nosql/redis/datos/) |
| Consultas representativas | Completo | [`../db/consultas/`](../db/consultas/), [`../nosql/redis/comandos/`](../nosql/redis/comandos/) y [`../nosql/mongodb/consultas/`](../nosql/mongodb/consultas/) |
| README del proyecto | Parcial | [`../README.md`](../README.md), faltan los integrantes |

## Coherencia entre componentes

- [x] Unificados `product-001`–`product-008`, `user-123` y `session-456` entre PostgreSQL,
  los ejemplos de MongoDB y Redis. PostgreSQL conserva claves internas separadas. También los códigos
  de pedido: los eventos `purchase` usaban `order-1001` y `order-1002`, que no existían en
  `sales_order`; ahora usan `order-321` y `order-322`, que son los pedidos completados de `user-123` y
  `user-124` en PostgreSQL, en su mismo instante.

  También las categorías. Tres productos estaban clasificados de otra forma en el seed de MongoDB que
  en [`../db/datos/CATALOGO_CANONICO.md`](../db/datos/CATALOGO_CANONICO.md): `product-005` figuraba
  como capilar en lugar de maquillaje, `product-007` como maquillaje en lugar de capilar y
  `product-008` como skincare en lugar de capilar. La correspondencia entre el vocabulario de
  `metadata.category_id` y las categorías principales de PostgreSQL quedó documentada en la sección
  1.2 del modelo, para que no vuelva a desviarse al agregar eventos.

- [x] **Alineadas las sesiones entre PostgreSQL y MongoDB.** PostgreSQL es el dueño de las sesiones y
  MongoDB las referencia, según la sección 1.6 del modelo, de modo que los eventos deben caer dentro de
  la ventana de su sesión y corresponder a su mismo cliente. Estado verificado sobre la pila levantada:

  | Sesión | `customer_session` (UTC) | Eventos en `user_events` |
  | --- | --- | --- |
  | `session-461` | `user-123`, 08-18 15:55 a 16:10 | `user-123`, 08-18 16:00 a 16:05 |
  | `session-456` | `user-123`, 08-19 15:28 a 15:45 | `user-123`, 08-19 15:35 a 15:42 |
  | `session-457` | `user-124`, 08-23 15:00 a 15:25 | `user-124`, 08-23 15:00 a 15:10 |
  | `session-458` | `user-125`, 08-24 21:00 a 21:40 | `user-125`, 08-24 21:00 a 21:03 |
  | `session-460` | anónima, 08-24 23:00 a 23:30 | anónima, 08-24 23:00 a 23:03 |

  El desajuste de fondo era que PostgreSQL definía una sola sesión por cliente y MongoDB registraba dos
  para `user-123`, que es justamente el caso del cliente que vuelve y el que motiva la recomendación
  personalizada. Se resolvió completando PostgreSQL con `session-461` en lugar de recortar el
  historial documental. Los códigos inventados `session-502` y `session-901` desaparecieron: pasaron a
  ser `session-457` y `session-458`, que sí existen.

  Las dos compras quedaron dentro de la sesión que las origina y en el instante de su pedido:
  `order-321` a las 08-19 15:42 en `session-456` y `order-322` a las 08-23 15:10 en `session-457`. Para
  esto último se movió `order-322`, que estaba fuera de toda sesión de su cliente. `session-459` no
  registra eventos, que es válido: no toda sesión genera interacciones seguidas.

- [x] Resuelta la consulta SQL 3, que antes asumía los eventos en PostgreSQL. Consultaba una tabla
  `interaction_event` que el modelo asigna a MongoDB y que el esquema relacional no define. Quedó
  reemplazada por [`../db/consultas/03_clientes_frecuencia_valor.sql`](../db/consultas/03_clientes_frecuencia_valor.sql),
  sobre datos transaccionales, y las listas de [`informe.md` §10](informe.md) y de
  [`../README.md`](../README.md) ya la nombran.

- [x] Unificado el criterio de red. PostgreSQL no declaraba ninguna y quedaba aislado en la red
  predeterminada del proyecto, sin resolver los nombres de los otros motores. Ahora los tres declaran
  `bdia_g04_network`, y su volumen lleva `name:` explícito como los otros dos. Comprobado sobre la
  pila levantada desde la raíz: los seis contenedores quedan en `bdia_g04_tp_bdia_g04_network` y
  `redis` resuelve `postgres` y `mongodb`.

- [x] Resuelto el caso de `session-502` y `session-901`, los dos códigos que MongoDB usaba sin
  respaldo en `customer_session`. Quedaron reemplazados por `session-457` y `session-458` al alinear
  las sesiones, de modo que hoy todos los `session_code` del seed documental existen en PostgreSQL.

## Otros pendientes de entrega

- [ ] Completar la tabla de integrantes del grupo en el README.
- [ ] Evidenciar la participación de todos los integrantes mediante commits (o documentar en el README
  los aportes realizados fuera del repositorio).
- [ ] Definir si el repositorio se entrega público o privado; si es privado, dar acceso de lectura al
  usuario que indique la cátedra.

## Reparto de trabajo

| Componente | Estado | Ubicación |
| --- | --- | --- |
| **Redis (capa clave-valor)** | Terminado y verificado | [`../nosql/redis/`](../nosql/redis/) |
| MongoDB (eventos) | Terminado | [`../nosql/mongodb/`](../nosql/mongodb/) |
| PostgreSQL (transaccional) | Implementado y validado con Docker (23 controles de estado, 4 de comportamiento, 15 de integridad y 1 de concurrencia) | [`../db/`](../db/) |

El [`docker-compose.yml`](../docker-compose.yml) de la raíz incorpora los tres componentes mediante
`include:`.

Para que la inclusión funcione sin retoques, conviene que cada componente siga las mismas
convenciones que [`../nosql/redis/`](../nosql/redis/):

- compose propio con los puertos tomados de un `.env` local, nunca fijos;
- `container_name` con el prefijo `bdia_g04_`, para que no colisionen;
- red `bdia_g04_network`, la misma en los tres, en lugar de un nombre propio o de la red
  predeterminada del proyecto;
- `.env.example` versionado y `.env` ignorado por git;
- volúmenes con `name:` explícito, para que levantar desde el directorio del componente y levantar
  desde la raíz compartan los datos en lugar de crear uno por proyecto;
- script de carga que verifique el estado y devuelva error si algo no cuadra.
