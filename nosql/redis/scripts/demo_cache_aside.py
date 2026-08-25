"""
Mide la diferencia de latencia entre resolver una solicitud de
recomendaciones ejecutando el motor (cache MISS) y resolverla desde Redis
(cache HIT), aplicando el patron cache-aside.

Se ejecuta dentro del contenedor demo:
    docker compose exec demo python /workspace/scripts/demo_cache_aside.py

Tambien puede ejecutarse desde el equipo local, instalando redis-py y
definiendo REDIS_HOST=localhost.

Elimina y regenera la clave reco:user:user-demo:home. No altera el resto del
estado inicial.
"""

import json
import os
import time

import redis

# Latencia simulada del camino lento: consultar PostgreSQL y MongoDB y
# ejecutar el motor de recomendaciones. No se conecta a esos motores porque
# todavia no estan implementados. Lo que se mide es el efecto de la cache,
# no el costo real del motor.
LATENCIA_MOTOR_S = 0.25

CLAVE_DEMO = "reco:user:user-demo:home"
TTL_SEGUNDOS = 600
SOLICITUDES = 5


def conectar() -> redis.Redis:
    # La contrasena se exige en lugar de tomar un valor por defecto. Un
    # fallback convertiria una variable mal definida en un error de
    # autenticacion de Redis, que apunta al servidor y no al verdadero motivo.
    contrasena = os.environ.get("REDIS_PASSWORD")
    if not contrasena:
        raise SystemExit(
            "Falta la variable REDIS_PASSWORD.\n"
            "Dentro del contenedor la define docker-compose.yml:\n"
            "  docker compose exec demo python /workspace/scripts/demo_cache_aside.py\n"
            "Desde el equipo local hay que exportarla con el valor de "
            "nosql/redis/.env:\n"
            "  export REDIS_PASSWORD=$(grep ^REDIS_PASSWORD nosql/redis/.env | cut -d= -f2)"
        )

    return redis.Redis(
        host=os.environ.get("REDIS_HOST", "localhost"),
        port=int(os.environ.get("REDIS_PORT", "6379")),
        password=contrasena,
        decode_responses=True,
    )


def generar_recomendaciones(user_id: str, contexto: str) -> dict:
    """Sustituye al motor de recomendaciones mientras no este implementado."""
    time.sleep(LATENCIA_MOTOR_S)
    return {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "model_version": "v1",
        "source": "motor",
        "user_id": user_id,
        "context": contexto,
        "recommendations": [
            {"product_id": "product-004", "score": 0.94},
            {"product_id": "product-001", "score": 0.89},
            {"product_id": "product-003", "score": 0.81},
        ],
    }


def obtener_recomendaciones(cliente: redis.Redis, user_id: str, contexto: str):
    """Lee la cache y, solo ante un MISS, ejecuta el motor y guarda el
    resultado con TTL."""
    clave = CLAVE_DEMO

    cacheado = cliente.get(clave)
    if cacheado is not None:
        cliente.incr("contador:reco:cache_hit")
        return json.loads(cacheado), "HIT"

    recomendaciones = generar_recomendaciones(user_id, contexto)
    cliente.set(clave, json.dumps(recomendaciones), ex=TTL_SEGUNDOS)
    cliente.incr("contador:reco:generadas")
    return recomendaciones, "MISS"


def main() -> None:
    cliente = conectar()
    cliente.ping()

    # Se elimina la clave para que la primera solicitud sea siempre un MISS.
    cliente.delete(CLAVE_DEMO)

    estadisticas_previas = cliente.info("stats")
    hits_previos = estadisticas_previas["keyspace_hits"]
    misses_previos = estadisticas_previas["keyspace_misses"]

    print(f"Latencia simulada del motor: {LATENCIA_MOTOR_S * 1000:.0f} ms")
    print(f"Clave de demostracion:       {CLAVE_DEMO}")
    print()
    print(f"  {'#':<3} {'resultado':<10} {'latencia':>12}   productos")
    print(f"  {'-' * 3} {'-' * 10} {'-' * 12}   {'-' * 30}")

    latencias = {"HIT": [], "MISS": []}

    for numero in range(1, SOLICITUDES + 1):
        inicio = time.perf_counter()
        recomendaciones, resultado = obtener_recomendaciones(
            cliente, "user-demo", "home"
        )
        transcurrido_ms = (time.perf_counter() - inicio) * 1000
        latencias[resultado].append(transcurrido_ms)

        productos = ", ".join(
            item["product_id"] for item in recomendaciones["recommendations"]
        )
        print(f"  {numero:<3} {resultado:<10} {transcurrido_ms:>9.2f} ms   {productos}")

    print()

    # SOLICITUDES es ajustable: con un valor de 1 no se produce ningun HIT y
    # el promedio correspondiente no existe.
    def promedio(resultado: str) -> float | None:
        medidas = latencias[resultado]
        return sum(medidas) / len(medidas) if medidas else None

    promedio_miss = promedio("MISS")
    promedio_hit = promedio("HIT")

    print("Resumen medido")
    for etiqueta, valor, resultado in (
        ("MISS (motor)", promedio_miss, "MISS"),
        ("HIT  (Redis)", promedio_hit, "HIT"),
    ):
        cantidad = len(latencias[resultado])
        # Las filas sin dato se alinean con las numericas, que ocupan el
        # ancho del valor mas el sufijo " ms".
        if valor is None:
            print(f"  {etiqueta}          {'sin datos':>12}   n=0")
        else:
            print(f"  {etiqueta}          {valor:>9.2f} ms   n={cantidad}")

    if promedio_miss is not None and promedio_hit:
        print(f"  Reduccion             {promedio_miss / promedio_hit:>9.1f} x")
    else:
        print(f"  Reduccion             {'no aplica':>12}   "
              f"(se requieren al menos 2 solicitudes)")
    print()

    estadisticas = cliente.info("stats")
    print("Estadisticas del servidor (delta de esta corrida)")
    print(f"  keyspace_hits         {estadisticas['keyspace_hits'] - hits_previos:>9}")
    print(f"  keyspace_misses       {estadisticas['keyspace_misses'] - misses_previos:>9}")
    print()

    print("Estado de la clave")
    print(f"  TTL restante          {cliente.ttl(CLAVE_DEMO):>9} s")
    print(f"  Tamano en memoria     {cliente.memory_usage(CLAVE_DEMO):>9} bytes")
    print()
    print("Contadores acumulados")
    for contador in ("contador:reco:generadas", "contador:reco:cache_hit"):
        valor = cliente.get(contador)
        print(f"  {contador:<26}{valor if valor is not None else 'sin datos':>5}")


if __name__ == "__main__":
    main()
