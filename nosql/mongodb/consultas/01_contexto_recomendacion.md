# 01. Contexto de recomendación

Estas consultas alimentan al motor de recomendaciones. Devuelven el comportamiento **reciente y
relevante** de un usuario, por eso acotan explícitamente una ventana temporal sobre `timestamp`.

Se ejecutan en `mongosh`, conectado a la base `bdia_g04_mongodb`:

Cada bloque se puede copiar y pegar tal cual. Las fechas son literales para que el resultado sea
reproducible contra el estado inicial de [`../seed_data.json`](../seed_data.json) (eventos entre el
2026-08-13 y el 2026-08-20).

## Consulta 1. Historial reciente de un usuario

**Pregunta de negocio:** ¿qué hizo este usuario en los últimos siete días?

**Objetivo:** recuperar los eventos recientes de un usuario ordenados del más nuevo al más viejo.

```javascript
db.user_events.find({
  user_id: "user-123",
  timestamp: {
    $gte: ISODate("2026-08-13T00:00:00Z"),
    $lt: ISODate("2026-08-21T00:00:00Z")
  }
}).sort({
  timestamp: -1
})
```

**Resultado esperado:** los 10 eventos de `user-123`, encabezados por los del 18 de agosto
(`evt-0010`, `evt-0009`, `evt-0008`, `evt-0007`) y luego los del 13 de agosto.

**Justificación:** el filtro por rango sobre `timestamp` aprovecha la Time Series Collection: el
`$match` recorre únicamente los buckets dentro de la ventana pedida, y el índice automático
`{ user_id: 1, timestamp: 1 }` resuelve "usuario + rango temporal" sin escanear toda la colección.

## Consulta 2. Productos más interactuados por un usuario

**Pregunta de negocio:** ¿qué productos concentran el interés reciente de un usuario?

**Objetivo:** contar, en la ventana de los últimos siete días, las visualizaciones y agregados al
carrito por producto, ordenando por cantidad de interacciones.

```javascript
db.user_events.aggregate([
  {
    $match: {
      user_id: "user-123",
      event_type: {
        $in: ["product_view", "add_to_cart"]
      },
      timestamp: {
        $gte: ISODate("2026-08-13T00:00:00Z"),
        $lt: ISODate("2026-08-21T00:00:00Z")
      }
    }
  },
  {
    $group: {
      _id: "$product_id",
      interactions: { $sum: 1 }
    }
  },
  {
    $sort: {
      interactions: -1
    }
  }
])
```

**Resultado esperado:** `product-001` con 3 interacciones, `product-004` con 2, y `product-002` y
`product-003` con 1 cada uno.

**Justificación:** la ventana temporal en el `$match` es lo que convierte esta agregación en una
señal de comportamiento **reciente**; sin ella se mezclarían interacciones de todo el historial.
El resultado alimenta directamente las características del modelo.

## Consulta 3. Eventos de una sesión

**Pregunta de negocio:** ¿qué recorrido hizo el usuario dentro de una sesión concreta?

**Objetivo:** reconstruir, en orden cronológico, los eventos de una sesión determinada.

```javascript
db.user_events.find({
  user_id: "user-123",
  session_id: "session-456",
  timestamp: {
    $gte: ISODate("2026-08-13T00:00:00Z")
  }
}).sort({
  timestamp: 1
})
```

**Resultado esperado:** los 6 eventos de `session-456` en orden cronológico, de `evt-0001` a
`evt-0006`.

**Justificación:** una sesión es por naturaleza una ventana temporal corta. El `$gte` acota la
búsqueda a la franja de la sesión, y el orden ascendente por `timestamp` reconstruye el recorrido.
`session_id` se conserva como campo medido para este tipo de analíticas, sin índice propio.
