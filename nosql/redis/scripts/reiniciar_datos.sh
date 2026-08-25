#!/bin/sh
# ------------------------------------------------------------
# Vuelve a dejar la base en el estado inicial:
#   sh scripts/reiniciar_datos.sh
#
# Funciona con la pila levantada de cualquiera de las dos formas, desde el
# compose de la raiz o desde este directorio. Por eso se dirige al contenedor
# por su nombre y no con `docker compose exec`, que resolveria un proyecto
# distinto segun el directorio desde el que se invoque al script.
#
# Reinicia datos, no infraestructura. No modifica la configuracion del
# servidor (maxmemory, politica de descarte, requirepass). Si algun comando
# CONFIG SET dejo la configuracion en un estado inconsistente, alcanza con
# ejecutar `docker compose restart redis`: al no haber persistencia, el
# reinicio restaura los valores declarados en docker-compose.yml.
# ------------------------------------------------------------
set -eu

CONTENEDOR=bdia_g04_redis_server

if [ -z "$(docker ps --quiet --filter "name=^/${CONTENEDOR}$")" ]; then
    echo "El contenedor $CONTENEDOR no esta corriendo." >&2
    echo "Levantar la pila con 'docker compose up -d --wait', desde la raiz" >&2
    echo "del repositorio o desde nosql/redis." >&2
    exit 1
fi

docker exec -i "$CONTENEDOR" sh /scripts/00_cargar_datos.sh

echo ""
echo "Estado inicial restaurado."
