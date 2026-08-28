# ------------------------------------------------------------
# Atajos para operar el componente MongoDB del TP Integrador.
#
# Usa `docker exec` contra el contenedor por nombre, de modo que
# funciona igual si la pila se levanto desde la raiz del repositorio
# o desde este directorio. Las credenciales salen de las variables de
# entorno del contenedor, que el compose define a partir de .env.
# ------------------------------------------------------------

CONTENEDOR := bdia_g04_mongodb

.PHONY: generar-datos shell

# Crea la coleccion user_events (Time Series) y carga seed_data.json.
generar-datos:
	docker exec $(CONTENEDOR) sh -c 'mongosh --quiet \
		--username "$$MONGO_INITDB_ROOT_USERNAME" \
		--password "$$MONGO_INITDB_ROOT_PASSWORD" \
		--authenticationDatabase admin \
		--file /scripts/generar_datos.js'

# Abre una consola interactiva de mongosh, ya posicionada en la base del
# componente. Sin indicarla, mongosh conecta a `test` y las consultas de
# consultas/, que usan db.user_events, devolverian cero sin ningun error.
shell:
	docker exec -it $(CONTENEDOR) sh -c 'mongosh \
		--username "$$MONGO_INITDB_ROOT_USERNAME" \
		--password "$$MONGO_INITDB_ROOT_PASSWORD" \
		--authenticationDatabase admin \
		"$$MONGO_DATABASE"'
