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
| 5 | Normalización y decisiones de diseño | Parcial | [`informe.md` §6](informe.md) | La duplicación en Redis está justificada en §6.1. Falta justificar la normalización relacional y las decisiones de embebido/referencia en MongoDB |
| 6 | Selección tecnológica | Parcial | [`informe.md` §7](informe.md) | Redis está justificado en §7.3, con sus alternativas descartadas. Falta la justificación de PostgreSQL según los 10 criterios de la consigna |
| 7 | Modelo físico e implementación mínima | Parcial | [`../nosql/redis/`](../nosql/redis/), [`../db/`](../db/), diagrama en [`modelo_fisico.md`](modelo_fisico.md) | PostgreSQL y Redis están implementados y verificados. Falta crear `user_events` en MongoDB |
| 8 | Consultas representativas | Parcial | [`../db/consultas/`](../db/consultas/), [`../nosql/redis/comandos/`](../nosql/redis/comandos/) | Las cinco consultas PostgreSQL están implementadas y se ejecutan durante la inicialización; faltan las consultas ejecutables de MongoDB |
| 9 | Semiestructurados, no estructurados y vectorial | Parcial | [`../vectorial/modelo_vectorial.md`](../vectorial/modelo_vectorial.md) | Cerrar los cinco ítems que pide la consigna, en especial los riesgos |
| 10 | Arquitectura de datos | Parcial | [`arquitectura.md`](arquitectura.md) | Ingesta, capa analítica, justificación del enfoque arquitectónico, `arquitectura.png` |
| 11 | Seguridad, permisos y aislamiento | Parcial | [`informe.md` §13](informe.md) | La capa clave-valor está cubierta en §13.1. Falta la matriz de roles y permisos, las restricciones en PostgreSQL y el riesgo de exposición vía IA |
| 12 | Escalabilidad y rendimiento | Parcial | [`informe.md` §14](informe.md) | La capa clave-valor está cubierta en §14.1, con mediciones. Falta el análisis de PostgreSQL y MongoDB: particionamiento, separación de componentes, compromisos |

## Entregables mínimos exigidos

| Entregable | Estado | Dónde |
| --- | --- | --- |
| Informe técnico | Parcial | [`informe.md`](informe.md) → exportar a `informe.pdf` |
| Modelo conceptual | Completo | [`modelo_conceptual.md`](modelo_conceptual.md) (incluye diagrama ER) |
| Modelo lógico relacional o equivalente | Completo | Relacional en [`../db/estructura/`](../db/estructura/) y su diagrama UML en [`modelo_logico_relacional.md`](modelo_logico_relacional.md); documental y clave-valor en [`../nosql/`](../nosql/) |
| Modelo físico o equivalente | Parcial | PostgreSQL en [`../db/`](../db/) (diagrama en [`modelo_fisico.md`](modelo_fisico.md)) y Redis en [`../nosql/redis/`](../nosql/redis/); MongoDB pendiente |
| Arquitectura general de datos | Parcial | [`arquitectura.md`](arquitectura.md) |
| Archivos de implementación mínima | Parcial | PostgreSQL y Redis implementados; MongoDB pendiente |
| Datos de ejemplo | Completo | Catálogo y transacciones en [`../db/datos/`](../db/datos/), eventos JSON en [`../data/ejemplos/`](../data/ejemplos/) y estado Redis en [`../nosql/redis/datos/`](../nosql/redis/datos/) |
| Consultas representativas | Parcial | [`../db/consultas/`](../db/consultas/) y [`../nosql/redis/comandos/`](../nosql/redis/comandos/) |
| README del proyecto | Parcial | [`../README.md`](../README.md), faltan los integrantes |

## Coherencia entre componentes

- [x] Unificados `product-001`–`product-008`, `user-123` y `session-456` entre PostgreSQL,
  los ejemplos de MongoDB y Redis. PostgreSQL conserva claves internas separadas.

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
| MongoDB (eventos) | Modelo definido, implementación pendiente | `../nosql/mongodb/` (a crear) |
| PostgreSQL (transaccional) | Implementado y validado: 20 controles de estado, 2 de comportamiento, 10 de integridad y 1 de concurrencia `OK` | [`../db/`](../db/) |

El [`docker-compose.yml`](../docker-compose.yml) de la raíz incorpora Redis y PostgreSQL mediante
`include:`. MongoDB continúa comentado hasta que exista su implementación.

Para que la inclusión funcione sin retoques, conviene que cada componente siga las mismas
convenciones que [`../nosql/redis/`](../nosql/redis/):

- compose propio con los puertos tomados de un `.env` local, nunca fijos;
- `container_name` con el prefijo `bdia_g04_`, para que no colisionen;
- red `bdia_g04_network`, la misma en los tres, en lugar de un nombre propio;
- `.env.example` versionado y `.env` ignorado por git;
- script de carga que verifique el estado y devuelva error si algo no cuadra.
