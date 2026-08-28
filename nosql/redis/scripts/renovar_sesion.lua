-- ------------------------------------------------------------
-- Renueva una sesion anonima sin revivirla si ya vencio.
--
-- KEYS[1] clave de la sesion, por ejemplo session:session-456
-- ARGV[1] marca temporal de la ultima actividad
-- ARGV[2] ultimo producto visto
-- ARGV[3] segundos de la ventana deslizante
--
-- Devuelve 1 si renovo la sesion y 0 si la sesion ya no existia.
--
-- Por que un script y no MULTI/EXEC: la transaccion garantiza que las tres
-- escrituras se apliquen juntas, pero no puede ramificar segun un resultado
-- intermedio. Sin la comprobacion de existencia, HINCRBY sobre una sesion
-- vencida la vuelve a crear con los campos de estos comandos y sin los
-- originales, es decir una sesion incompleta que declara haber empezado nunca.
--
-- Redis ejecuta cada script de forma atomica, de modo que entre el EXISTS y
-- las escrituras no puede intercalarse ninguna otra operacion.
-- ------------------------------------------------------------

if redis.call('EXISTS', KEYS[1]) == 0 then
  return 0
end

redis.call('HINCRBY', KEYS[1], 'events_count', 1)
redis.call('HSET', KEYS[1], 'last_seen_at', ARGV[1], 'last_product_id', ARGV[2])
redis.call('EXPIRE', KEYS[1], ARGV[3])

return 1
