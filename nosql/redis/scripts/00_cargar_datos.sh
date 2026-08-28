#!/bin/sh
# ------------------------------------------------------------
# Carga el estado inicial de la capa clave-valor y verifica que haya
# quedado consistente.
#
# Se ejecuta dentro del contenedor redis, que monta datos/ en /datos:
#   docker compose exec redis sh /scripts/00_cargar_datos.sh
#
# Termina con codigo distinto de cero si alguna verificacion falla, de modo
# que sirve tambien como comprobacion del entorno.
#
# Ejecuta FLUSHDB: elimina todo el contenido de la base antes de cargar.
# ------------------------------------------------------------
set -eu

cli() {
    redis-cli --no-auth-warning -a "$REDIS_PASSWORD" "$@"
}

echo "Vaciando la base actual..."
cli FLUSHDB > /dev/null

echo "Cargando estado inicial..."
# redis-cli lee comandos linea por linea desde stdin. Se descartan los
# comentarios y las lineas vacias antes de enviarlos.
grep -v '^\s*#' /datos/estado_inicial.redis | grep -v '^\s*$' \
    | redis-cli --no-auth-warning -a "$REDIS_PASSWORD" > /dev/null

echo ""
echo "Verificando el estado cargado:"

fallos=0

verificar() {
    etiqueta="$1"
    esperado="$2"
    obtenido="$3"
    if [ "$esperado" = "$obtenido" ]; then
        printf '  %-42s %s\n' "$etiqueta" "$obtenido"
    else
        printf '  %-42s %s  (se esperaba %s)\n' "$etiqueta" "$obtenido" "$esperado"
        fallos=$((fallos + 1))
    fi
}

verificar "claves totales (DBSIZE)"            6 "$(cli DBSIZE)"
verificar "tipo de reco:user:user-123:home"    string "$(cli TYPE reco:user:user-123:home)"
verificar "tipo de session:session-456"        hash "$(cli TYPE session:session-456)"
verificar "tipo de ranking:...:vistos:7d"      zset "$(cli TYPE ranking:productos:vistos:7d)"
verificar "campos de la sesion (HLEN)"         5 "$(cli HLEN session:session-456)"
verificar "productos en el ranking (ZCARD)"    8 "$(cli ZCARD ranking:productos:vistos:7d)"

# Las claves con expiracion deben tener un TTL positivo. TTL devuelve -1 si
# la clave no expira nunca y -2 si la clave no existe.
for clave in reco:user:user-123:home reco:sess:session-456:product session:session-456 ranking:productos:vistos:7d; do
    ttl="$(cli TTL "$clave")"
    if [ "$ttl" -gt 0 ]; then
        printf '  %-42s %s s\n' "TTL de $clave" "$ttl"
    else
        printf '  %-42s %s  (se esperaba un TTL positivo)\n' "TTL de $clave" "$ttl"
        fallos=$((fallos + 1))
    fi
done

# Los contadores no deben expirar: son acumulados operativos.
for clave in 'contador:{reco}:generadas' 'contador:{reco}:cache_hit'; do
    ttl="$(cli TTL "$clave")"
    verificar "TTL de $clave" -1 "$ttl"
done

echo ""
if [ "$fallos" -ne 0 ]; then
    echo "Carga INCOMPLETA: $fallos verificaciones fallaron."
    exit 1
fi

echo "Carga completa y consistente en la base 0 de Redis."
