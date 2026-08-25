# Datos semiestructurados, no estructurados y búsqueda vectorial

> Corresponde al punto 9 de la consigna. La consigna aclara que **no es obligatorio implementar
> embeddings, pero sí justificar si el caso elegido requiere o no una solución vectorial**.

## 1. Decisión del grupo

**El procesamiento de imágenes, la generación de embeddings y la búsqueda vectorial quedan fuera del
alcance de esta versión.**

El alcance mínimo se concentra en datos estructurados (PostgreSQL) y en datos semiestructurados
resueltos mediante documentos en MongoDB. La búsqueda por similitud queda registrada como extensión
opcional, evaluable una vez validado el alcance mínimo.

## 2. Datos semiestructurados y no estructurados presentes en el caso

El diseño contempla la posibilidad de incorporar:

| Tipo | Ejemplos en este caso | Tratamiento en esta versión |
| --- | --- | --- |
| Semiestructurados | Atributos variables de productos, parámetros de búsqueda, contexto de eventos, metadatos de recomendaciones | `metadata` de los documentos de `user_events` en MongoDB. Como alternativa para el lado relacional se prevé JSONB en PostgreSQL. |
| No estructurados | Descripciones extensas de productos, textos de reseñas, imágenes, documentos de ingredientes | Se almacenan como texto en el modelo relacional; no se procesan semánticamente. |

La elección entre JSONB en PostgreSQL y una base documental como MongoDB debe justificarse según las
necesidades del caso. Para los **eventos**, el grupo ya optó por MongoDB (ver
[`../nosql/modelo_nosql.md`](../nosql/modelo_nosql.md)).

## 3. Si el caso se extendiera a búsqueda vectorial

Elementos que podrían vectorizarse y necesidad que resolverían:

- descripciones de productos: similitud semántica entre productos ("productos parecidos a este");
- textos de reseñas: agrupamiento de opiniones y detección de preferencias;
- consultas de búsqueda del usuario: recuperación de productos por lenguaje natural en lugar de
  coincidencia exacta de términos.

## 4. Pendiente de completar

La consigna pide indicar explícitamente, para el análisis vectorial:

- [ ] qué datos podrían vectorizarse (esbozado arriba, falta cerrarlo);
- [ ] qué necesidad resolvería la búsqueda por similitud;
- [ ] qué consultas podrían realizarse;
- [ ] qué metadatos deberían acompañar a los vectores;
- [ ] qué riesgos aparecen si se recupera información incorrecta, desactualizada o no autorizada
      (por ejemplo, recomendar un producto inactivo o sin stock, o exponer datos de otro cliente).
