# Capa clave-valor en Redis

Implementación de la capa clave-valor de la solución: cache de recomendaciones, sesiones de
visitantes anónimos, rankings precalculados y rate limit del motor de recomendaciones.

El modelo y las justificaciones de diseño están en [`../modelo_nosql.md`](../modelo_nosql.md),
sección 2. Este directorio contiene la implementación y los comandos representativos.

## Puesta en marcha

Con la pila unificada levantada desde la raíz, el [`Makefile`](../../Makefile) general expone los
targets de esta capa (`make redis.seed`, `make redis.shell`, `make redis.demo-cache`, etc.), que
operan sobre los contenedores por nombre y sirven igual en cualquiera de los dos modos de arranque.

Requiere Docker Desktop o Docker Engine con Docker Compose. Desde `nosql/redis`:

```bash
cp .env.example .env
```

```bash
docker compose up -d --wait
```

Una vez que el servicio `redis` figure como saludable, se carga el estado inicial. Desde la raíz,
con la pila unificada levantada:

```bash
make redis.seed
```

Desde este directorio, de forma equivalente:

```bash
docker compose exec redis sh /scripts/00_cargar_datos.sh
```

El script termina con `Carga completa y consistente en la base 0 de Redis.` y devuelve un código de
error si alguna verificación falla, de modo que sirve también para comprobar el entorno.

La consola de Redis se abre con `make redis.shell` desde la raíz, o de forma equivalente desde este
directorio:

```bash
docker compose exec redis sh -c 'redis-cli --no-auth-warning -a "$REDIS_PASSWORD"'
```

La contraseña se toma de la variable del contenedor en lugar de escribirla en el comando, de modo que
la instrucción sigue siendo válida si se cambia `REDIS_PASSWORD` en el `.env`.

En Windows PowerShell, el primer comando es `Copy-Item .env.example .env`.

## Servicios

| Servicio | Función | Acceso |
| --- | --- | --- |
| `redis` | Servidor Redis 8.2 y ejecución de comandos con `redis-cli`. | `localhost:6379` |
| `redisinsight` | Visor web e interfaz de consulta (Workbench). | <http://localhost:5540> |
| `demo` | Contenedor con Python y `redis-py` para el demo de cache-aside. | sin puerto expuesto |

RedisInsight se conecta con host `redis`, puerto `6379` y la contraseña definida en `REDIS_PASSWORD`
(`bdia_local_pass` si no se modificó el `.env.example`). Al ser una interfaz gráfica, el valor se
se escribe manualmente: la interfaz no expande la variable. El host `redis` solo existe dentro de la red de
Docker; el acceso desde el navegador es por `localhost:5540`.

## Configuración

`.env.example` define credenciales y puertos locales:

| Variable | Valor predeterminado | Función |
| --- | --- | --- |
| `REDIS_PASSWORD` | `bdia_local_pass` | Contraseña de Redis (`requirepass`). |
| `REDIS_LISTEN_PORT` | `6379` | Puerto de Redis en el equipo local. |
| `REDIS_MAXMEMORY` | `256mb` | Límite de memoria de la cache. |
| `REDIS_MAXMEMORY_POLICY` | `allkeys-lru` | Política de descarte al alcanzar el límite. |
| `REDISINSIGHT_LISTEN_PORT` | `5540` | Puerto web de RedisInsight. |

Los puertos se publican únicamente en `127.0.0.1`. Las credenciales corresponden al entorno local del
trabajo y no deben reutilizarse fuera de él.

## Decisiones de configuración

Tres opciones del `docker-compose.yml` responden a decisiones de diseño y no a valores
predeterminados:

| Opción | Valor | Motivo |
| --- | --- | --- |
| `--save "" --appendonly no` | Sin persistencia | Todo el contenido es descartable. La cache, las sesiones y los rankings se reconstruyen desde PostgreSQL, MongoDB y el motor; los contadores y la cuota de rate limit en curso no, pero perderlos es aceptable. Persistir agregaría costo de disco sin aportar ninguna garantía que el diseño necesite. |
| `--maxmemory 256mb` | Límite explícito | Sin límite, Redis crece hasta agotar la memoria del equipo. Fijarlo convierte un problema de infraestructura en una política de cache. |
| `--maxmemory-policy allkeys-lru` | Descarte por recencia | Es la política adecuada cuando todo el contenido es descartable. Las alternativas evaluadas están en [`comandos/05`](comandos/05_expiracion_memoria_y_patrones.md). |

Como consecuencia, al reiniciar el contenedor se pierden las claves y, bajo presión de memoria,
cualquiera de ellas puede ser descartada. De ahí una restricción que atraviesa el diseño: ninguna
información que deba sobrevivir puede residir únicamente en Redis.

## Comandos representativos

| Archivo | Contenido |
| --- | --- |
| [`01`](comandos/01_cache_recomendaciones.md) | Cache de recomendaciones: lectura, escritura con TTL, espacios de nombres, invalidación y métricas. |
| [`02`](comandos/02_sesiones_anonimas.md) | Sesiones con identidad desacoplada y expiración deslizante. |
| [`03`](comandos/03_rankings_precalculados.md) | Rankings precalculados sobre Sorted Sets. |
| [`04`](comandos/04_rate_limit_y_contadores.md) | Rate limit por ventana fija y contadores operativos. |
| [`05`](comandos/05_expiracion_memoria_y_patrones.md) | Patrones de búsqueda, medición de memoria y descarte por límite. |

Cada bloque indica la pregunta de negocio que responde, el resultado esperado y la justificación de
la decisión de diseño asociada.

## Verificaciones con medición

Latencia de la cache, contrastando MISS contra HIT:

```bash
make redis.demo-cache
```

Comportamiento al alcanzar el límite de memoria:

```bash
make redis.demo-memory
```

Ambos se invocan desde la raíz; equivalen a `docker compose exec demo python
/workspace/scripts/demo_cache_aside.py` y `docker compose exec redis sh /scripts/demo_limite_memoria.sh`
respectivamente.

El segundo reduce `maxmemory` de forma temporal, llena la base e informa `evicted_keys`. La
configuración se restaura mediante un `trap`, de modo que vuelve a los valores declarados tanto al
terminar bien como si el script se interrumpe. La recarga del estado inicial, en cambio, solo ocurre
si el script llega al final: si se interrumpe, hay que volver a ejecutar `00_cargar_datos.sh`, y el
propio script lo indica al salir.

Las salidas de ambos están citadas en [`../modelo_nosql.md`](../modelo_nosql.md), sección 2.7.

## Archivos

```text
docker-compose.yml               redis + redisinsight + demo
Dockerfile.demo                  imagen minima con redis-py
.env.example                     credenciales y puertos locales
datos/estado_inicial.redis       estado inicial de las 4 estructuras
scripts/00_cargar_datos.sh       carga y verificacion del estado
scripts/reiniciar_datos.sh       restauracion del estado inicial
scripts/renovar_sesion.lua       renovacion atomica de sesion sin revivirla
scripts/demo_cache_aside.py      medicion de latencia MISS contra HIT
scripts/demo_limite_memoria.sh   limite de memoria y descarte de claves
scripts/requirements.txt         version de redis-py
comandos/                        comandos representativos por estructura
```

El contenedor `redis` monta `scripts/` en `/scripts` y `datos/` en `/datos`, ambos en modo de solo
lectura.

## Restaurar y detener

Para volver al estado inicial sin recrear los contenedores:

```bash
make redis.seed
```

Equivale a `sh scripts/reiniciar_datos.sh`, que recarga el estado inicial.

Conviene tener presente que cuatro de las seis claves iniciales llevan TTL y vencen solas al cabo de
entre 10 y 60 minutos. A partir de ese momento `DBSIZE` devuelve 2, porque quedan únicamente los dos
contadores, que se crean sin vencimiento. No es una falla: es el comportamiento que el diseño
describe, y el mismo script restaura las seis claves cuando hace falta reproducir los ejemplos.

Para detener la pila conservando el volumen de RedisInsight:

```bash
docker compose down
```

Agregando `-v` se elimina también ese volumen.

## Relación con el compose unificado

Este compose ya está incorporado al [`docker-compose.yml`](../../docker-compose.yml) de la raíz
mediante `include:`, de modo que la capa puede levantarse de dos formas equivalentes: desde este
directorio, o junto al resto de la solución desde la raíz del repositorio. **No conviene usar las dos
a la vez**, porque los nombres de contenedor son los mismos y entran en conflicto.

Para que la inclusión funcione sin modificar este archivo, los puertos salen de `.env` y los
`container_name` llevan el prefijo `bdia_g04_`. Los tres servicios se conectan de forma explícita a
`bdia_g04_network`, la misma red que declaran los compose de MongoDB y de PostgreSQL, de modo que al
incluirlos desde la raíz los tres motores quedan en una sola. Al incluirse, el `name:` de este
archivo se ignora y prevalece el del compose de la raíz, que prefija la red con el nombre del
proyecto unificado.

## Problemas frecuentes

- `NOAUTH Authentication required` indica que falta el parámetro de autenticación. Todos los comandos
  de `redis-cli` requieren `--no-auth-warning -a "$REDIS_PASSWORD"` ejecutados dentro del contenedor,
  que es donde esa variable está definida.
- Si el puerto 6379 está ocupado por un Redis instalado en el equipo, se cambia `REDIS_LISTEN_PORT`
  en `.env`. El puerto sigue vinculado a `127.0.0.1`.
- Si al reiniciar el contenedor las claves desaparecieron, es el comportamiento esperado: no hay
  persistencia. Se vuelve a ejecutar `scripts/00_cargar_datos.sh`.
- Si un `CONFIG SET` ejecutado a mano dejó la configuración inconsistente, `docker compose restart
  redis` restaura los valores declarados en el compose. Los scripts que la alteran la restauran
  solos.
- `KEYS` aparece en el archivo 05 con fines comparativos. No debe usarse fuera de una consola de
  inspección: bloquea el servidor mientras se ejecuta.
