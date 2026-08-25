# Índices y vistas PostgreSQL

[`01_indices_vistas.sql`](01_indices_vistas.sql) crea índices asociados a los
patrones de consulta del trabajo y la vista `v_active_catalog`.

Incluye índices para catálogo, precios, stock, pedidos, movimientos, reseñas,
recomendaciones y atributos JSONB. No crea índices de eventos porque esos datos
pertenecen a MongoDB.
