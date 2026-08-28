# 01. Contexto de recomendación

Estas consultas alimentan al motor de recomendaciones. Devuelven el comportamiento **reciente y
relevante** de un usuario, por eso acotan explícitamente una ventana temporal sobre `timestamp`.

Se ejecutan en `mongosh`, conectado a la base `bdia_g04_mongodb`.

Cada bloque se puede copiar y pegar tal cual. Las fechas son literales para que el resultado sea
reproducible contra el estado inicial de [`../seed_data.json`](../seed_data.json), cuyos eventos van
del 2026-08-12 al 2026-08-21. Las ventanas de siete días de esta página abarcan del 13 al 19 inclusive,
de modo que dejan fuera la sesión del 12 y los eventos del 20 y del 21.

## Consulta 1. Historial reciente de un usuario

**Pregunta de negocio:** ¿qué hizo este usuario en los últimos siete días?

**Objetivo:** recuperar los eventos recientes de un usuario ordenados del más nuevo al más viejo.

```javascript
db.user_events.find({
  user_id: "user-123",
  timestamp: {
    $gte: ISODate("2026-08-13T00:00:00Z"),
    $lt: ISODate("2026-08-20T00:00:00Z")
  }
}).sort({
  timestamp: -1
})
```

**Resultado esperado:** los 10 eventos de `user-123`, encabezados por los de la sesión del 19 de
agosto (`evt-0006` a `evt-0001`, del más nuevo al más viejo) y seguidos por los cuatro del 18 de
agosto (`evt-0010` a `evt-0007`).

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
        $lt: ISODate("2026-08-20T00:00:00Z")
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
