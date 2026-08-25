# Estado del trabajo por punto de la consigna

Mapa de qué está volcado al repositorio y qué falta desarrollar. Sirve para repartir el trabajo entre
los integrantes del grupo.

Estados posibles: **Completo**, **Parcial** y **Pendiente**.

## Actividades a realizar (12 puntos)

| # | Actividad | Estado | Dónde | Qué falta |
| --- | --- | --- | --- | --- |
| 1 | Análisis del caso de uso | Completo | [`informe.md` §1](informe.md) | — |
| 2 | Relevamiento de datos necesarios | Completo | [`informe.md` §2–3](informe.md) | — |
| 3 | Modelo conceptual | Parcial | [`modelo_conceptual.md`](modelo_conceptual.md) | Diagrama ER/UML exportado como `modelo_conceptual.png` |
| 4 | Modelo lógico o equivalente | Parcial | [`informe.md` §5](informe.md), [`../nosql/modelo_nosql.md`](../nosql/modelo_nosql.md) | El modelo clave-valor y el documental están definidos. Falta el modelo lógico **relacional**: tablas, columnas, PK, FK, restricciones, N:M, criterios de normalización |
| 5 | Normalización y decisiones de diseño | Parcial | [`informe.md` §6](informe.md) | La duplicación en Redis está justificada en §6.1. Falta justificar la normalización relacional y las decisiones de embebido/referencia en MongoDB |
| 6 | Selección tecnológica | Parcial | [`informe.md` §7](informe.md) | Redis está justificado en §7.3, con sus alternativas descartadas. Falta la justificación de PostgreSQL según los 10 criterios de la consigna |
| 7 | Modelo físico e implementación mínima | Parcial | [`../nosql/redis/`](../nosql/redis/), [`../db/`](../db/) | Redis está implementado y verificado. Falta DDL, carga de datos, índices y vistas en PostgreSQL, y la creación de `user_events` en MongoDB |
| 8 | Consultas representativas | Parcial | [`../db/consultas/`](../db/consultas/), [`../nosql/redis/comandos/`](../nosql/redis/comandos/) | Los comandos de Redis fueron ejecutados y verificados. Falta ajustar las SQL al modelo físico y ejecutarlas sobre datos reales |
| 9 | Semiestructurados, no estructurados y vectorial | Parcial | [`../vectorial/modelo_vectorial.md`](../vectorial/modelo_vectorial.md) | Cerrar los cinco ítems que pide la consigna, en especial los riesgos |
| 10 | Arquitectura de datos | Parcial | [`arquitectura.md`](arquitectura.md) | Ingesta, capa analítica, justificación del enfoque arquitectónico, `arquitectura.png` |
| 11 | Seguridad, permisos y aislamiento | Parcial | [`informe.md` §13](informe.md) | La capa clave-valor está cubierta en §13.1. Falta la matriz de roles y permisos, las restricciones en PostgreSQL y el riesgo de exposición vía IA |
| 12 | Escalabilidad y rendimiento | Parcial | [`informe.md` §14](informe.md) | La capa clave-valor está cubierta en §14.1, con mediciones. Falta el análisis de PostgreSQL y MongoDB: particionamiento, separación de componentes, compromisos |

## Entregables mínimos exigidos

| Entregable | Estado | Dónde |
| --- | --- | --- |
| Informe técnico | Parcial | [`informe.md`](informe.md) → exportar a `informe.pdf` |
| Modelo conceptual | Parcial | [`modelo_conceptual.md`](modelo_conceptual.md) + diagrama pendiente |
| Modelo lógico relacional o equivalente | Parcial | Relacional pendiente; documental y clave-valor en [`../nosql/`](../nosql/) |
| Modelo físico o equivalente | Parcial | Redis en [`../nosql/redis/`](../nosql/redis/); relacional pendiente en [`../db/estructura/`](../db/estructura/) |
| Arquitectura general de datos | Parcial | [`arquitectura.md`](arquitectura.md) |
| Archivos de implementación mínima | Parcial | Redis en [`../nosql/redis/`](../nosql/redis/); PostgreSQL y MongoDB pendientes |
| Datos de ejemplo | Parcial | [`../data/ejemplos/`](../data/ejemplos/) y [`../nosql/redis/datos/`](../nosql/redis/datos/) — falta el catálogo relacional |
| Consultas representativas | Parcial | [`../db/consultas/`](../db/consultas/) y [`../nosql/redis/comandos/`](../nosql/redis/comandos/) |
| README del proyecto | Parcial | [`../README.md`](../README.md) — faltan los integrantes |

## Coherencia entre componentes

- [ ] Unificar los identificadores de producto entre los ejemplos de MongoDB
  (`data/ejemplos/user_events.json` y `nosql/modelo_nosql.md`, que usan `product-789`) y el catálogo
  ficticio de ocho productos `product-001`–`product-008` que utilizan Redis y las consultas SQL.
  Corresponde definirlo junto con quien implemente MongoDB.

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
| PostgreSQL (transaccional) | Pendiente | [`../db/`](../db/) |

El [`docker-compose.yml`](../docker-compose.yml) de la raíz ya está armado e incorpora Redis con
`include:`. Los bloques de PostgreSQL y MongoDB están escritos y comentados: cuando exista el archivo
de cada uno, alcanza con descomentar su bloque.

Para que la inclusión funcione sin retoques, conviene que cada componente siga las mismas
convenciones que [`../nosql/redis/`](../nosql/redis/):

- compose propio con los puertos tomados de un `.env` local, nunca fijos;
- `container_name` con el prefijo `bdia_g04_`, para que no colisionen;
- red `bdia_g04_network`, la misma en los tres, en lugar de un nombre propio;
- `.env.example` versionado y `.env` ignorado por git;
- script de carga que verifique el estado y devuelva error si algo no cuadra.
