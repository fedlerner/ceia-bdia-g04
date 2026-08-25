#!/bin/sh
# ------------------------------------------------------------
# Comprueba que, al alcanzar el limite de memoria, Redis descarta claves
# segun la politica configurada, y que ese descarte alcanza a cualquier
# clave y no solo al relleno insertado.
#
# Se ejecuta dentro del contenedor redis:
#   docker compose exec redis sh /scripts/demo_limite_memoria.sh
#
# Reduce maxmemory de forma temporal y llena la base con claves de relleno.
# La configuracion se restaura mediante un trap, de modo que vuelve a los
# valores declarados tanto al terminar bien como si el script se interrumpe.
# La recarga del estado inicial, en cambio, solo ocurre si el script llega al
# final: si se interrumpe, hay que ejecutar 00_cargar_datos.sh a mano.
# ------------------------------------------------------------
set -eu

CANTIDAD=6000
MAXMEMORY_PRUEBA=4mb

cli() {
    redis-cli --no-auth-warning -a "$REDIS_PASSWORD" "$@"
}

# Devuelve el valor de un campo de INFO, sin el retorno de carro final.
info_valor() {
    cli INFO "$1" | tr -d '\r' | awk -F: -v campo="$2" '$1 == campo {print $2}'
}

# Los valores a los que hay que volver se toman del entorno, que los recibe
# de docker-compose.yml. Leerlos de la configuracion en curso seria incorrecto:
# si una corrida anterior quedo a medias, el valor en curso ya es el de prueba
# y la restauracion fijaria el limite reducido de forma permanente.
MAXMEMORY_DECLARADO="$REDIS_MAXMEMORY"
POLITICA_DECLARADA="$REDIS_MAXMEMORY_POLICY"

restaurado=0
restaurar_configuracion() {
    estado=$?
    [ "$restaurado" -eq 1 ] && return 0
    restaurado=1
    cli CONFIG SET maxmemory "$MAXMEMORY_DECLARADO" > /dev/null 2>&1 || true
    cli CONFIG SET maxmemory-policy "$POLITICA_DECLARADA" > /dev/null 2>&1 || true
    if [ "$estado" -ne 0 ]; then
        echo ""
        echo "El demo se interrumpio. La configuracion se restauro a"
        echo "  maxmemory        $MAXMEMORY_DECLARADO"
        echo "  maxmemory-policy $POLITICA_DECLARADA"
        echo "La base quedo con claves de relleno. Para dejarla en el estado"
        echo "inicial: docker compose exec redis sh /scripts/00_cargar_datos.sh"
    fi
}

trap 'restaurar_configuracion; exit 130' INT TERM
trap restaurar_configuracion EXIT

echo "Configuracion declarada en docker-compose.yml"
echo "  maxmemory                 $MAXMEMORY_DECLARADO"
echo "  maxmemory-policy          $POLITICA_DECLARADA"
echo ""

echo "Bajando maxmemory a $MAXMEMORY_PRUEBA para forzar el limite..."
cli CONFIG SET maxmemory "$MAXMEMORY_PRUEBA" > /dev/null
cli CONFIG SET maxmemory-policy allkeys-lru > /dev/null

claves_antes="$(cli DBSIZE)"
descartadas_antes="$(info_valor stats evicted_keys)"
memoria_antes="$(info_valor memory used_memory_human)"

echo "Estado antes de llenar"
echo "  DBSIZE                    $claves_antes"
echo "  evicted_keys              $descartadas_antes"
echo "  used_memory               $memoria_antes"
echo ""

echo "Insertando $CANTIDAD claves de relleno de 1 KB..."
relleno="$(awk 'BEGIN { s = ""; for (i = 0; i < 1024; i++) s = s "x"; print s }')"
i=1
while [ "$i" -le "$CANTIDAD" ]; do
    printf 'SET relleno:%d %s\r\n' "$i" "$relleno"
    i=$((i + 1))
done | redis-cli --no-auth-warning -a "$REDIS_PASSWORD" --pipe > /dev/null 2>&1

claves_despues="$(cli DBSIZE)"
descartadas_despues="$(info_valor stats evicted_keys)"
memoria_despues="$(info_valor memory used_memory_human)"
descartadas_delta=$((descartadas_despues - descartadas_antes))

echo ""
echo "Estado despues de llenar"
echo "  DBSIZE                    $claves_despues   (se insertaron $CANTIDAD claves)"
echo "  evicted_keys              $descartadas_despues   (+$descartadas_delta en esta corrida)"
echo "  used_memory               $memoria_despues"
echo ""

echo "Sobrevivieron las claves del estado inicial?"
for clave in reco:user:user-123:home session:session-456 ranking:productos:vistos:7d; do
    if [ "$(cli EXISTS "$clave")" = "1" ]; then
        printf '  %-38s presente\n' "$clave"
    else
        printf '  %-38s DESCARTADA por la politica allkeys-lru\n' "$clave"
    fi
done

echo ""
if [ "$descartadas_delta" -gt 0 ]; then
    echo "Se descartaron $descartadas_delta claves al alcanzar el limite de memoria."
    echo "Con allkeys-lru el descarte alcanza a cualquier clave, tenga TTL o no."
else
    echo "No hubo descartes: el relleno no alcanzo el limite de $MAXMEMORY_PRUEBA."
    echo "Aumentar CANTIDAD y repetir para observar el efecto."
fi

echo ""
echo "Restaurando la configuracion declarada..."
restaurar_configuracion
echo "  maxmemory                 $(cli CONFIG GET maxmemory | tail -n 1) bytes"
echo "  maxmemory-policy          $(cli CONFIG GET maxmemory-policy | tail -n 1)"

echo ""
echo "Recargando el estado inicial..."
echo ""
sh /scripts/00_cargar_datos.sh
