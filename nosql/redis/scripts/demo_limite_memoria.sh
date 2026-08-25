#!/bin/sh
# ------------------------------------------------------------
# Comprueba que, al alcanzar el limite de memoria, Redis descarta claves
# segun la politica configurada, y que ese descarte alcanza a cualquier
# clave y no solo al relleno insertado.
#
# Se ejecuta dentro del contenedor redis:
#   docker compose exec redis sh /scripts/demo_limite_memoria.sh
#
# Recarga el estado inicial antes de medir, para que la linea base sea
# reproducible y ninguna clave pueda haber vencido por TTL antes de empezar.
# Reduce maxmemory de forma temporal y llena la base con claves de relleno.
# La configuracion se restaura mediante un trap, de modo que vuelve a los
# valores declarados tanto al terminar bien como si el script se interrumpe.
# La recarga del estado inicial, en cambio, solo ocurre si el script llega al
# final: si se interrumpe, hay que ejecutar 00_cargar_datos.sh a mano.
#
# Devuelve 0 solo si observa el hecho que se propone demostrar: que una clave
# SIN TTL fue descartada. El descarte de Redis es un LRU aproximado que muestrea
# candidatos, de modo que una sola tanda puede no alcanzar las seis claves
# iniciales; por eso el llenado se repite hasta INTENTOS_MAX veces antes de
# darse por vencido.
# ------------------------------------------------------------
set -eu

CANTIDAD=6000
MAXMEMORY_PRUEBA=4mb
INTENTOS_MAX=3

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

# Fase alcanzada, para que el diagnostico de una interrupcion describa el
# estado real y no uno supuesto. Vale "preparacion" mientras no se haya tocado
# la configuracion ni insertado relleno, y "llenado" a partir de ahi.
fase=preparacion

restaurado=0
restaurar_configuracion() {
    estado=$?
    [ "$restaurado" -eq 1 ] && return 0
    restaurado=1

    if [ "$fase" = "preparacion" ]; then
        # Nada que restaurar: no se modifico maxmemory ni se inserto relleno.
        if [ "$estado" -ne 0 ]; then
            echo ""
            echo "El demo se interrumpio durante la preparacion, antes de modificar"
            echo "la configuracion o insertar claves de relleno. La configuracion del"
            echo "servidor no fue alterada. El estado de la base puede haber quedado"
            echo "a medio cargar: docker compose exec redis sh /scripts/00_cargar_datos.sh"
        fi
        return 0
    fi

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

CLAVES_INICIALES="reco:user:user-123:home reco:sess:session-456:product
                  session:session-456 ranking:productos:vistos:7d
                  contador:{reco}:generadas contador:{reco}:cache_hit"

echo "Recargando el estado inicial para partir de una linea base limpia..."
sh /scripts/00_cargar_datos.sh > /dev/null
echo ""

# Se registra que claves existen ANTES de forzar el limite. Sin este registro,
# una clave vencida por su propio TTL antes de empezar se informaria despues
# como descartada por LRU, y la evidencia seria incorrecta.
presentes_antes=""
for clave in $CLAVES_INICIALES; do
    if [ "$(cli EXISTS "$clave")" = "1" ]; then
        presentes_antes="$presentes_antes $clave"
    fi
done

echo "Configuracion declarada en docker-compose.yml"
echo "  maxmemory                 $MAXMEMORY_DECLARADO"
echo "  maxmemory-policy          $POLITICA_DECLARADA"
echo ""

echo "Bajando maxmemory a $MAXMEMORY_PRUEBA para forzar el limite..."
fase=llenado
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

relleno="$(awk 'BEGIN { s = ""; for (i = 0; i < 1024; i++) s = s "x"; print s }')"

# Inserta una tanda de CANTIDAD claves con un prefijo propio, para que las
# tandas sucesivas no se pisen entre si.
insertar_tanda() {
    i=1
    while [ "$i" -le "$CANTIDAD" ]; do
        printf 'SET relleno-%s:%d %s\r\n' "$1" "$i" "$relleno"
        i=$((i + 1))
    done | redis-cli --no-auth-warning -a "$REDIS_PASSWORD" --pipe > /dev/null 2>&1
}

# Devuelve 0 si alguna clave sin TTL que existia antes ya no esta.
descarto_clave_sin_ttl() {
    for c in contador:{reco}:generadas contador:{reco}:cache_hit; do
        case " $presentes_antes " in
            *" $c "*) ;;
            *) continue ;;
        esac
        [ "$(cli EXISTS "$c")" = "0" ] && return 0
    done
    return 1
}

contador_descartado=0
insertadas=0
intento=1
while [ "$intento" -le "$INTENTOS_MAX" ]; do
    echo "Insertando $CANTIDAD claves de relleno de 1 KB (tanda $intento de $INTENTOS_MAX)..."
    insertar_tanda "$intento"
    insertadas=$((insertadas + CANTIDAD))

    if descarto_clave_sin_ttl; then
        contador_descartado=1
        break
    fi

    if [ "$intento" -lt "$INTENTOS_MAX" ]; then
        echo "  Las claves sin TTL sobrevivieron a esta tanda. El descarte de Redis"
        echo "  es un LRU aproximado por muestreo, asi que se insiste con otra tanda."
    fi
    intento=$((intento + 1))
done

claves_despues="$(cli DBSIZE)"
descartadas_despues="$(info_valor stats evicted_keys)"
memoria_despues="$(info_valor memory used_memory_human)"
descartadas_delta=$((descartadas_despues - descartadas_antes))

echo ""
echo "Estado despues de llenar"
echo "  DBSIZE                    $claves_despues   (se insertaron $insertadas claves)"
echo "  evicted_keys              $descartadas_despues   (+$descartadas_delta en esta corrida)"
echo "  used_memory               $memoria_despues"
echo ""

# Se comprueban las cuatro estructuras del modelo, incluidos los contadores.
# Los contadores no tienen TTL, de modo que su descarte es lo que demuestra
# que allkeys-lru alcanza a cualquier clave y no solo a las que expiran.
#
# El estado se informa comparando contra presentes_antes, para no atribuir al
# descarte por memoria una clave que ya no estaba al comenzar.
echo "Sobrevivieron las claves del estado inicial?"
printf '  %-30s %-10s %s\n' "clave" "TTL" "estado"
for clave in $CLAVES_INICIALES; do
    case "$clave" in
        contador:*) ttl="sin TTL" ;;
        *)          ttl="con TTL" ;;
    esac

    case " $presentes_antes " in
        *" $clave "*) estaba_antes=1 ;;
        *)            estaba_antes=0 ;;
    esac

    if [ "$(cli EXISTS "$clave")" = "1" ]; then
        printf '  %-30s %-10s presente\n' "$clave" "$ttl"
    elif [ "$estaba_antes" -eq 1 ]; then
        printf '  %-30s %-10s DESCARTADA por allkeys-lru\n' "$clave" "$ttl"
    else
        printf '  %-30s %-10s ausente ya antes de forzar el limite\n' "$clave" "$ttl"
    fi
done

echo ""
if [ "$descartadas_delta" -eq 0 ]; then
    echo "No hubo descartes: el relleno no alcanzo el limite de $MAXMEMORY_PRUEBA."
    echo "Aumentar CANTIDAD y repetir para observar el efecto."
    resultado=1
elif [ "$contador_descartado" -eq 1 ]; then
    echo "Se descartaron $descartadas_delta claves al alcanzar el limite de memoria,"
    echo "entre ellas al menos un contador SIN TTL."
    echo "Queda demostrado que allkeys-lru alcanza a cualquier clave, tenga TTL o no."
    resultado=0
else
    echo "Se descartaron $descartadas_delta claves al alcanzar el limite de memoria,"
    echo "pero todas las claves sin TTL sobrevivieron a las $INTENTOS_MAX tandas."
    echo "El descarte de Redis es un LRU aproximado por muestreo, de modo que puede"
    echo "no alcanzar a un conjunto pequeno de claves."
    echo "Esta corrida NO demuestra que allkeys-lru alcance a las claves sin TTL,"
    echo "asi que se devuelve error: aumentar CANTIDAD o INTENTOS_MAX y repetir."
    resultado=1
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

exit "$resultado"
