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

**Resultado esperado:** `user-123` con 2 búsquedas, `user-124` y `user-125` con 1 cada uno, más un
grupo con `_id: null` y 1 búsqueda.

**Justificación:** el `$match` por `event_type` se apoya en el índice secundario `{ event_type: 1 }`.
La intensidad de búsqueda es una señal de intención que puede alimentar el modelo.

El grupo `null` no es un error: corresponde a los eventos de visitantes anónimos, que el modelo
identifica solo por `session_id` y que por lo tanto no tienen `user_id`. Agrupar por usuario los
reúne a todos bajo `null`. Para analizarlos por separado hay que agrupar por `session_id`, como hace
la consulta 3 de este archivo.

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

**Resultado esperado:** `product-001` con 3 vistas y 2 carritos (ratio 1.5); `product-004`,
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

**Resultado esperado:** cinco sesiones. `session-456` y `session-457` con 6 eventos, `session-461`
con 4, y `session-458` y `session-460` con 3 cada una, todas con su primer y último evento.
`session-460` es la del visitante anónimo y aparece sin `user_id`. El orden entre esas dos últimas no
está determinado: el `$sort` es por cantidad de eventos y ambas tienen la misma.

**Justificación:** complementa la reconstrucción detallada de una sesión (ver
[`01_contexto_recomendacion.md`](01_contexto_recomendacion.md), consulta 3) con una vista agregada
de todas las sesiones. `$min` y `$max` sobre `timestamp` aprovechan el orden temporal de la serie.
