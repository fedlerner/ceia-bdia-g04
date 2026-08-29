# ------------------------------------------------------------
# Makefile general del TP Integrador - Grupo 04.
#
# Envuelve la puesta en marcha, la carga de datos de prueba y las
# verificaciones de los tres motores (PostgreSQL, MongoDB y Redis) a partir
# del compose unificado de la raiz.
#
# Los targets por base tienen la forma <bd>.<operacion> y, salvo `up` y `down`,
# no tocan el estado del despliegue: operan sobre los contenedores en marcha
# mediante `docker exec` por nombre, de modo que funcionan igual si la pila se
# levanto desde la raiz o desde el directorio de cada componente.
#
# Las credenciales se toman de las variables de entorno del contenedor, no del
# .env local: la misma convencion que nosql/mongodb/Makefile y los scripts de
# nosql/redis. Por eso los comandos usan `sh -c '...'` con $$VAR, para que la
# variable se expanda dentro del contenedor.
# ------------------------------------------------------------

.DEFAULT_GOAL := up

CONTENEDOR_POSTGRES := bdia_g04_postgres
CONTENEDOR_REDIS    := bdia_g04_redis_server
CONTENEDOR_DEMO     := bdia_g04_redis_demo

# Comprobacion previa comun a los targets que hablan con un contenedor en
# marcha. Sin ella, `docker exec` sobre una pila detenida responde con el hash
# del contenedor y no dice que hacer. Es la misma guarda que usa
# nosql/mongodb/Makefile y nosql/redis/scripts/reiniciar_datos.sh.
define contenedor_en_marcha
	@if [ -z "$$(docker ps --quiet --filter 'name=^/$(1)$$')" ]; then \
		echo "El contenedor $(1) no esta corriendo." >&2; \
		echo "Levantar la pila con 'make up' o 'make setup'." >&2; \
		exit 1; \
	fi
endef

.PHONY: env up setup down help \
	postgresql.shell postgresql.queries postgresql.checks postgresql.integrity \
	postgresql.concurrency postgresql.verify \
	mongo.seed mongo.shell \
	redis.seed redis.shell redis.demo-cache redis.demo-memory redis.session-renew

# ------------------------------------------------------------
# Targets globales
# ------------------------------------------------------------

# Crea cada .env a partir de su .env.example, solo si todavia no existe.
env:
	@test -f db/.env || cp db/.env.example db/.env
	@test -f nosql/mongodb/.env || cp nosql/mongodb/.env.example nosql/mongodb/.env
	@test -f nosql/redis/.env || cp nosql/redis/.env.example nosql/redis/.env

# Levanta los tres motores con el compose unificado.
up: env
	docker compose up -d --wait
	@echo ""
	@echo "Servicios de visualizacion:"
	@printf '  Mongo Express : http://localhost:%s\n' "$$(grep '^MONGO_EXPRESS_LISTEN_PORT=' nosql/mongodb/.env | cut -d= -f2)"
	@printf '  RedisInsight  : http://localhost:%s\n' "$$(grep '^REDISINSIGHT_LISTEN_PORT=' nosql/redis/.env | cut -d= -f2)"
	@echo "  PostgreSQL     : sin interfaz web; usar 'make postgresql.shell'"

# Crea/verifica los datos de prueba de las tres bases, en orden:
# 1) PostgreSQL, 2) MongoDB, 3) Redis.
setup: up
	@echo "==> 1/3 PostgreSQL: verificando esquema, datos y reglas"
	$(MAKE) postgresql.verify
	@echo "==> 2/3 MongoDB: recreando user_events y cargando seed_data.json"
	$(MAKE) mongo.seed
	@echo "==> 3/3 Redis: cargando y verificando el estado inicial"
	$(MAKE) redis.seed

# Detiene la pila. Junto a `up`, es el unico target que altera el estado del
# despliegue.
down:
	docker compose down

help:
	@printf 'Targets globales\n'
	@printf '  make / make up   levanta los tres motores (docker compose up -d --wait)\n'
	@printf '  make setup       up + datos y verificaciones: postgres, mongo, redis\n'
	@printf '  make env         crea los .env a partir de los .env.example\n'
	@printf '  make down        detiene la pila\n'
	@printf '\nPostgreSQL (postgresql.*)\n'
	@printf '  postgresql.shell        consola psql\n'
	@printf '  postgresql.queries      re-ejecuta las 5 consultas representativas\n'
	@printf '  postgresql.checks       23 controles de estado\n'
	@printf '  postgresql.integrity    15 pruebas de integridad\n'
	@printf '  postgresql.concurrency  prueba de concurrencia sobre un pedido\n'
	@printf '  postgresql.verify       queries + checks + integrity + concurrency\n'
	@printf '\nMongoDB (mongo.*)\n'
	@printf '  mongo.seed   recrea user_events y carga seed_data.json\n'
	@printf '  mongo.shell  consola mongosh en la base del componente\n'
	@printf '\nRedis (redis.*)\n'
	@printf '  redis.seed          restaura el estado inicial y lo verifica\n'
	@printf '  redis.shell         consola redis-cli\n'
	@printf '  redis.demo-cache    medicion de latencia MISS vs HIT\n'
	@printf '  redis.demo-memory   eviccion al alcanzar el limite de memoria\n'
	@printf '  redis.session-renew ejemplo de renovar_sesion.lua\n'

# ------------------------------------------------------------
# PostgreSQL
# ------------------------------------------------------------

postgresql.shell:
	$(call contenedor_en_marcha,$(CONTENEDOR_POSTGRES))
	docker exec -it $(CONTENEDOR_POSTGRES) sh -c 'psql -X -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

postgresql.queries:
	$(call contenedor_en_marcha,$(CONTENEDOR_POSTGRES))
	@for q in db/consultas/*.sql; do \
		echo "  - $$q"; \
		docker exec -i $(CONTENEDOR_POSTGRES) sh -c 'psql -X -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"' < "$$q"; \
	done

postgresql.checks:
	$(call contenedor_en_marcha,$(CONTENEDOR_POSTGRES))
	docker exec -i $(CONTENEDOR_POSTGRES) sh -c 'psql -X -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"' < db/validacion/01_validation.sql

postgresql.integrity:
	$(call contenedor_en_marcha,$(CONTENEDOR_POSTGRES))
	docker exec -i $(CONTENEDOR_POSTGRES) sh -c 'psql -X -v ON_ERROR_STOP=1 -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"' < db/validacion/02_integrity_tests.sql

postgresql.concurrency:
	$(call contenedor_en_marcha,$(CONTENEDOR_POSTGRES))
	bash db/scripts/validar_concurrencia_totales.sh

postgresql.verify: postgresql.queries postgresql.checks postgresql.integrity postgresql.concurrency

# ------------------------------------------------------------
# MongoDB
# ------------------------------------------------------------

# Delega en el Makefile del componente, que ya incluye la guarda de contenedor
# y toma las credenciales del entorno del contenedor.
mongo.seed:
	$(MAKE) -C nosql/mongodb generar-datos

mongo.shell:
	$(MAKE) -C nosql/mongodb shell

# ------------------------------------------------------------
# Redis
# ------------------------------------------------------------

redis.seed:
	sh nosql/redis/scripts/reiniciar_datos.sh

redis.shell:
	$(call contenedor_en_marcha,$(CONTENEDOR_REDIS))
	docker exec -it $(CONTENEDOR_REDIS) sh -c 'redis-cli --no-auth-warning -a "$$REDIS_PASSWORD"'

redis.demo-cache:
	$(call contenedor_en_marcha,$(CONTENEDOR_DEMO))
	docker exec $(CONTENEDOR_DEMO) python /workspace/scripts/demo_cache_aside.py

redis.demo-memory:
	$(call contenedor_en_marcha,$(CONTENEDOR_REDIS))
	docker exec $(CONTENEDOR_REDIS) sh /scripts/demo_limite_memoria.sh

redis.session-renew:
	$(call contenedor_en_marcha,$(CONTENEDOR_REDIS))
	docker exec $(CONTENEDOR_REDIS) sh -c 'redis-cli --no-auth-warning -a "$$REDIS_PASSWORD" --eval /scripts/renovar_sesion.lua session:session-456 , 2026-08-19T15:47:00Z product-004 1800'
