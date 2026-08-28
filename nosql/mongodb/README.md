# Eventos de usuario en MongoDB

Implementación de la capa documental de la solución: la colección `user_events`, que registra los
eventos de interacción del usuario (`product_view`, `search`, `add_to_cart`, `purchase`) como una
**Time Series Collection**.

El modelo y las justificaciones de diseño están en [`../modelo_nosql.md`](../modelo_nosql.md),
sección 1. Este directorio contiene la implementación y los datos de ejemplo.

## Puesta en marcha

Requiere Docker Desktop o Docker Engine con Docker Compose. Desde `nosql/mongodb`:

```bash
cp .env.example .env
```

```bash
docker compose up -d --wait
```

Una vez que el servicio `mongodb` figure como saludable, se genera la colección y se cargan los
datos de ejemplo:

```bash
make generar-datos
```

El script recrea `user_events` como serie de tiempo (`timeField: "timestamp"`,
`metaField: "user_id"`, `granularity: "seconds"`), crea el índice secundario `{ event_type: 1 }` y
carga los 22 eventos de [`seed_data.json`](seed_data.json), de los cuales 3 corresponden a un
visitante anónimo identificado solo por `session_id`.

El script valida el seed antes de escribir y, una vez cargado, comprueba contra la base el conteo, el
`timeField`, el `metaField`, la retención y los dos índices. Si algo no cuadra termina con código de
error y no modifica la colección existente.

En Windows PowerShell, el primer comando es `Copy-Item .env.example .env`.

## Makefile

El [`Makefile`](Makefile) envuelve los comandos de uso más frecuente. Se dirige al contenedor por
nombre (`bdia_g04_mongodb`), de modo que funciona igual si la pila se levanta desde este directorio
o desde la raíz del repositorio con el compose unificado. Las credenciales se toman de las variables
de entorno del contenedor, no del `.env` local.

| Objetivo | Acción |
| --- | --- |
| `make generar-datos` | Crea `user_events` y carga `seed_data.json`. Idempotente: al ejecutarlo de nuevo se recrea la colección desde cero. |
| `make shell` | Abre una consola interactiva de `mongosh` ya autenticada. |

Ejemplos:

```bash
make generar-datos
```

```bash
make shell
```

## Mongo Express

El visor web está disponible en <http://localhost:8081> (el puerto corresponde a
`MONGO_EXPRESS_LISTEN_PORT` en `.env`, publicado solo en `127.0.0.1`).

Al abrirlo pide las credenciales de autenticación básica definidas en `.env`
(`ME_CONFIG_BASICAUTH_USERNAME` / `ME_CONFIG_BASICAUTH_PASSWORD`; por defecto `admin` /
`admin_local`). Mongo Express se conecta a MongoDB por su cuenta con las credenciales de root, de
modo que desde el navegador pueden inspeccionarse la base `bdia_g04_mongodb` y su colección
`user_events` sin escribir credenciales adicionales.

## Servicios

| Servicio | Función | Acceso |
| --- | --- | --- |
| `mongodb` | Servidor MongoDB 8.0 y ejecución de `mongosh`. | `localhost:27017` |
| `mongo-express` | Visor web de la base. | <http://localhost:8081> |

## Configuración

`.env.example` define credenciales y puertos locales:

| Variable | Valor predeterminado | Función |
| --- | --- | --- |
| `MONGO_INITDB_ROOT_USERNAME` | `bdia_mongo_admin` | Usuario administrador creado al arrancar. |
| `MONGO_INITDB_ROOT_PASSWORD` | `bdia_mongo_pass` | Contraseña de ese usuario. |
| `MONGO_DATABASE` | `bdia_g04_mongodb` | Base donde se crea la colección `user_events`. |
| `MONGO_LISTEN_PORT` | `27017` | Puerto de MongoDB en el equipo local. |
| `ME_CONFIG_BASICAUTH_USERNAME` | `admin` | Usuario de acceso al visor web. |
| `ME_CONFIG_BASICAUTH_PASSWORD` | `admin_local` | Contraseña de acceso al visor web. |
| `MONGO_EXPRESS_LISTEN_PORT` | `8081` | Puerto web de Mongo Express. |

Los puertos se publican únicamente en `127.0.0.1`. Las credenciales corresponden al entorno local del
trabajo y no deben reutilizarse fuera de él.

## Consultas representativas

Las consultas más comunes sobre `user_events` están documentadas en [`consultas/`](consultas/), en
formato copiar-y-pegar para ejecutar en `mongosh`:

| Archivo | Contenido |
| --- | --- |
| [`01_contexto_recomendacion.md`](consultas/01_contexto_recomendacion.md) | Historial reciente de un usuario, productos más interactuados y eventos de una sesión (contexto para el motor). |
| [`02_analiticas_productos.md`](consultas/02_analiticas_productos.md) | Productos más visualizados y categorías con mayor interés. |
| [`03_analiticas_comportamiento.md`](consultas/03_analiticas_comportamiento.md) | Búsquedas por usuario, relación vistas/carrito y actividad por sesión. |

## Los dos modos de arranque comparten los datos

Este componente puede levantarse desde su propio directorio o junto al resto desde la raíz del
repositorio, y **ambos usan el mismo volumen de datos**: los eventos cargados de una forma se ven al
levantar de la otra.

No es el comportamiento predeterminado de Docker Compose, que nombra los volúmenes anteponiendo el
del proyecto y habría creado uno distinto por cada modo. El `docker-compose.yml` fija el nombre de
forma explícita con `name: bdia_g04_mongodb_data`, por la misma razón por la que fija los
`container_name` y el nombre de la red.

Conviene mantener la convención en los demás componentes que persistan datos.

## Archivos

```text
docker-compose.yml               mongodb + mongo-express
.env.example                     credenciales y puertos locales
seed_data.json                   eventos de ejemplo de user_events
generar_datos.js                 crea la coleccion y carga los eventos
Makefile                         make generar-datos y make shell
consultas/                       consultas representativas en mongosh
```

El contenedor `mongodb` monta `seed_data.json` y `generar_datos.js` en `/scripts`, ambos en modo de
solo lectura.

## Relación con el compose unificado

Este compose ya está incorporado al [`docker-compose.yml`](../../docker-compose.yml) de la raíz
mediante `include:`, de modo que el componente puede levantarse de dos formas equivalentes: desde
este directorio, o junto al resto de la solución desde la raíz del repositorio. **No conviene usar
las dos a la vez**, porque los nombres de contenedor son los mismos y entran en conflicto.

## Problemas frecuentes

- `MongoServerError: Authentication failed` indica que el contenedor no arrancó con las credenciales
  que usa `mongosh`. Conviene recrearlo con `docker compose up -d --wait` para que tome el `.env`.
- Si el puerto 27017 u 8081 está ocupado en el equipo, se cambia `MONGO_LISTEN_PORT` o
  `MONGO_EXPRESS_LISTEN_PORT` en `.env`. El puerto sigue vinculado a `127.0.0.1`.
- La colección `user_events` se recrea en cada `make generar-datos`: es el comportamiento esperado.
