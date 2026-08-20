# Estado del trabajo por punto de la consigna

Mapa de qué está volcado al repositorio y qué falta desarrollar. Sirve para repartir el trabajo entre
los integrantes del grupo.

Leyenda: ✅ volcado · 🟡 parcial · ⬜ pendiente

## Actividades a realizar (12 puntos)

| # | Actividad | Estado | Dónde | Qué falta |
| --- | --- | --- | --- | --- |
| 1 | Análisis del caso de uso | ✅ | [`informe.md` §1](informe.md) | — |
| 2 | Relevamiento de datos necesarios | ✅ | [`informe.md` §2–3](informe.md) | — |
| 3 | Modelo conceptual | 🟡 | [`modelo_conceptual.md`](modelo_conceptual.md) | Diagrama ER/UML exportado como `modelo_conceptual.png` |
| 4 | Modelo lógico o equivalente | 🟡 | [`informe.md` §5](informe.md), [`../nosql/modelo_nosql.md`](../nosql/modelo_nosql.md) | Modelo lógico **relacional** completo: tablas, columnas, PK, FK, restricciones, N:M, criterios de normalización |
| 5 | Normalización y decisiones de diseño | ⬜ | [`informe.md` §6](informe.md) | Justificar normalización relacional y decisiones de embebido/referencia en MongoDB |
| 6 | Selección tecnológica | 🟡 | [`informe.md` §7](informe.md) | Justificación de PostgreSQL según los 10 criterios de la consigna |
| 7 | Modelo físico e implementación mínima | ⬜ | [`../db/`](../db/) | DDL, carga de datos, índices y vistas; creación de `user_events` en MongoDB |
| 8 | Consultas representativas | 🟡 | [`../db/consultas/`](../db/consultas/) | Ajustar nombres al modelo físico y ejecutarlas sobre datos reales |
| 9 | Semiestructurados, no estructurados y vectorial | 🟡 | [`../vectorial/modelo_vectorial.md`](../vectorial/modelo_vectorial.md) | Cerrar los cinco ítems que pide la consigna, en especial los riesgos |
| 10 | Arquitectura de datos | 🟡 | [`arquitectura.md`](arquitectura.md) | Ingesta, capa analítica, justificación del enfoque arquitectónico, `arquitectura.png` |
| 11 | Seguridad, permisos y aislamiento | ⬜ | [`informe.md` §13](informe.md) | Matriz de roles y permisos, restricciones por motor, riesgo de exposición vía IA |
| 12 | Escalabilidad y rendimiento | ⬜ | [`informe.md` §14](informe.md) | Particionamiento, separación de componentes, compromisos |

## Entregables mínimos exigidos

| Entregable | Estado | Dónde |
| --- | --- | --- |
| Informe técnico | 🟡 | [`informe.md`](informe.md) → exportar a `informe.pdf` |
| Modelo conceptual | 🟡 | [`modelo_conceptual.md`](modelo_conceptual.md) + diagrama pendiente |
| Modelo lógico relacional o equivalente | 🟡 | Relacional pendiente; documental en [`../nosql/`](../nosql/) |
| Modelo físico o equivalente | ⬜ | [`../db/estructura/`](../db/estructura/) |
| Arquitectura general de datos | 🟡 | [`arquitectura.md`](arquitectura.md) |
| Archivos de implementación mínima | ⬜ | [`../db/`](../db/) |
| Datos de ejemplo | 🟡 | [`../data/ejemplos/`](../data/ejemplos/) — falta el catálogo relacional |
| Consultas representativas | 🟡 | [`../db/consultas/`](../db/consultas/) |
| README del proyecto | 🟡 | [`../README.md`](../README.md) — faltan los integrantes |

## Otros pendientes de entrega

- ⬜ Completar la tabla de integrantes del grupo en el README.
- ⬜ Evidenciar la participación de todos los integrantes mediante commits (o documentar en el README
  los aportes realizados fuera del repositorio).
- ⬜ Definir si el repositorio se entrega público o privado; si es privado, dar acceso de lectura al
  usuario que indique la cátedra.
