# 02. Analíticas de productos

Consultas analíticas generales sobre `user_events`, para entender el comportamiento agregado de los
usuarios y detectar oportunidades comerciales.

Se ejecutan en `mongosh`, conectado a la base `bdia_g04_mongodb`.

Cada bloque se puede copiar y pegar tal cual.

## Consulta 1. Productos más visualizados

**Pregunta de negocio:** ¿qué productos reciben más visualizaciones?

**Objetivo:** contar las visualizaciones por producto en toda la colección, de mayor a menor.

```javascript
db.user_events.aggregate([
  {
    $match: {
      event_type: "product_view"
    }
  },
  {
    $group: {
      _id: "$product_id",
      views: { $sum: 1 }
    }
  },
  {
    $sort: {
      views: -1
    }
  }
])
```

**Resultado esperado:** `product-001` con 3 visualizaciones, seguido de los demás productos del
catálogo con 1 cada uno.

**Justificación:** el índice secundario `{ event_type: 1 }` sirve el `$match` sobre el tipo de
evento.

## Consulta 2. Categorías con mayor interés

**Pregunta de negocio:** ¿qué categorías concentran la atención de los usuarios?

**Objetivo:** agrupar las visualizaciones por la categoría del producto, registrada en
`metadata.category_id`.

```javascript
db.user_events.aggregate([
  {
    $match: {
      event_type: "product_view"
    }
  },
  {
    $group: {
      _id: "$metadata.category_id",
      views: { $sum: 1 }
    }
  },
  {
    $sort: {
      views: -1
    }
  }
])
```

**Resultado esperado:** `perfumes` con 4, `skincare` con 3, `maquillaje` con 2 y `capilar` con 1.

**Justificación:** `metadata.category_id` permite responder esta pregunta sin unir con el catálogo
de PostgreSQL; el evento lleva la categoría relevante en el momento de la interacción. El modelo
documental admite esta flexibilidad de metadatos por tipo de evento (ver
[`../../modelo_nosql.md`](../../modelo_nosql.md), sección 1.2).
