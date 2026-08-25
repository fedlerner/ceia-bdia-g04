# 03. Analíticas de comportamiento

Consultas sobre `user_events` para analizar el comportamiento general de los usuarios: búsquedas,
relación entre visualizaciones y carrito, y actividad por sesión.

Se ejecutan en `mongosh`, conectado a la base `bdia_g04_mongodb`.

Cada bloque se puede copiar y pegar tal cual.

## Consulta 1. Cantidad de búsquedas por usuario

**Pregunta de negocio:** ¿cuántas búsquedas realiza cada usuario?

**Objetivo:** contar los eventos `search` agrupados por usuario, de mayor a menor.

```javascript
db.user_events.aggregate([
  {
    $match: {
      event_type: "search"
    }
  },
  {
    $group: {
      _id: "$user_id",
      searches: { $sum: 1 }
    }
  },
  {
    $sort: {
      searches: -1
    }
  }
])
```

**Resultado esperado:** `user-123` con 2 búsquedas, `user-124` y `user-125` con 1 cada uno.

**Justificación:** el `$match` por `event_type` se apoya en el índice secundario `{ event_type: 1 }`.
La intensidad de búsqueda es una señal de intención que puede alimentar el modelo.

## Consulta 2. Relación entre visualizaciones y agregados al carrito

**Pregunta de negocio:** ¿qué productos se ven mucho pero se agregan poco al carrito?

**Objetivo:** comparar, por producto, la cantidad de visualizaciones contra la de agregados al
carrito, calculando la relación entre ambas.

```javascript
db.user_events.aggregate([
  {
    $match: {
      event_type: { $in: ["product_view", "add_to_cart"] }
    }
  },
  {
    $group: {
      _id: "$product_id",
      views: { $sum: { $cond: [{ $eq: ["$event_type", "product_view"] }, 1, 0] } },
      carts: { $sum: { $cond: [{ $eq: ["$event_type", "add_to_cart"] }, 1, 0] } }
    }
  },
  {
    $addFields: {
      ratio: { $cond: [{ $eq: ["$carts", 0] }, null, { $divide: ["$views", "$carts"] }] }
    }
  },
  {
    $sort: {
      views: -1
    }
  }
])
```

**Resultado esperado:** `product-001` con 2 vistas y 1 carrito (ratio 2.0); `product-004`,
`product-007` y `product-008` con 1 y 1 (ratio 1.0); los demás solo con vistas (ratio `null`).

**Justificación:** los `$cond` dentro del `$group` cuentan cada tipo de evento por separado sin
necesidad de recorrer la colección dos veces. Un ratio alto identifica productos que generan
curiosidad pero poca conversión.

## Consulta 3. Comportamiento durante una sesión

**Pregunta de negocio:** ¿cuánta actividad concentra cada sesión y cuánto dura?

**Objetivo:** resumir, por sesión, la cantidad de eventos y su primer y último instante.

```javascript
db.user_events.aggregate([
  {
    $group: {
      _id: { user_id: "$user_id", session_id: "$session_id" },
      events: { $sum: 1 },
      first_event: { $min: "$timestamp" },
      last_event: { $max: "$timestamp" }
    }
  },
  {
    $sort: {
      events: -1
    }
  }
])
```

**Resultado esperado:** `session-456` y `session-502` con 6 eventos, `session-457` con 4 y
`session-901` con 3, cada una con su primer y último evento.

**Justificación:** complementa la reconstrucción detallada de una sesión (ver
[`01_contexto_recomendacion.md`](01_contexto_recomendacion.md), consulta 3) con una vista agregada
de todas las sesiones. `$min` y `$max` sobre `timestamp` aprovechan el orden temporal de la serie.
