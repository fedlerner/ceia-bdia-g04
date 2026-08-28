// ------------------------------------------------------------
// Genera y valida los datos de la capa documental en MongoDB.
//
// Se ejecuta dentro del contenedor mongodb, que monta seed_data.json
// en /scripts:
//
//   make generar-datos
//
// o, de forma equivalente:
//
//   docker exec bdia_g04_mongodb sh -c 'mongosh --quiet \
//     --username "$MONGO_INITDB_ROOT_USERNAME" \
//     --password "$MONGO_INITDB_ROOT_PASSWORD" \
//     --authenticationDatabase admin --file /scripts/generar_datos.js'
//
// Crea la coleccion user_events como Time Series Collection con su
// politica de retencion, crea los indices secundarios y carga los
// documentos de seed_data.json.
//
// Termina con codigo distinto de cero si alguna verificacion falla, de
// modo que sirve tambien como comprobacion del entorno.
// ------------------------------------------------------------

const fs = require("fs");

const DB_NAME = process.env.MONGO_DATABASE || "bdia_g04_mongodb";
const COLL = "user_events";
const SEED_PATH = "/scripts/seed_data.json";

// Retencion de los eventos. Ver ../modelo_nosql.md, seccion 1.3.
const RETENCION_DIAS = 90;
const RETENCION_SEGUNDOS = RETENCION_DIAS * 24 * 60 * 60;

const database = db.getSiblingDB(DB_NAME);

// 1. Leer y VALIDAR el seed ANTES de tocar la base. Se valida primero para
// que un seed mal formado no deje la coleccion vacia: si algo falla, la
// carga anterior sigue intacta. Sin esta comprobacion,
// una fecha mal escrita produce un Invalid Date que MongoDB almacena como
// 1970-01-01: el documento entra sin error y queda invisible para todas
// las consultas, porque todas acotan una ventana temporal.
const crudos = JSON.parse(fs.readFileSync(SEED_PATH, "utf8"));
const errores = [];

const docs = crudos.map(function (d, i) {
  const ts = new Date(d.timestamp);
  if (isNaN(ts.getTime())) {
    errores.push("documento " + i + " (" + d._id + "): timestamp invalido '" + d.timestamp + "'");
  }
  if (!d.event_type) {
    errores.push("documento " + i + " (" + d._id + "): falta event_type");
  }
  if (!d.user_id && !d.session_id) {
    errores.push("documento " + i + " (" + d._id + "): no tiene ni user_id ni session_id");
  }
  return Object.assign({}, d, { timestamp: ts });
});

if (errores.length > 0) {
  print("El seed tiene " + errores.length + " problema(s); no se carga nada:");
  errores.forEach(function (e) { print("  " + e); });
  quit(1);
}

// 2. Recrear la coleccion como serie de tiempo. El drop previo deja el
// script idempotente: volver a cargarlo restaura el estado inicial.
database.getCollection(COLL).drop();
database.createCollection(COLL, {
  timeseries: {
    timeField: "timestamp",
    metaField: "user_id",
    granularity: "seconds"
  },
  expireAfterSeconds: RETENCION_SEGUNDOS
});

const coll = database.getCollection(COLL);

// 3. Indice secundario para las consultas analiticas que filtran por
// event_type (../modelo_nosql.md, 1.5). El filtro por user_id lo resuelve
// el indice automatico { user_id: 1, timestamp: 1 } del metaField.
coll.createIndex({ event_type: 1 });

// 4. Cargar.
coll.insertMany(docs);

// 5. Verificar contra la base, no contra el archivo de entrada.
print("");
print("Verificando el estado cargado:");

let fallos = 0;

function verificar(etiqueta, esperado, obtenido) {
  const ok = String(esperado) === String(obtenido);
  print("  " + etiqueta.padEnd(44) + obtenido + (ok ? "" : "  (se esperaba " + esperado + ")"));
  if (!ok) fallos += 1;
}

const opciones = database.getCollectionInfos({ name: COLL })[0].options;
const indices = coll.getIndexes().map(function (i) { return i.name; });

verificar("documentos cargados", docs.length, coll.countDocuments());
verificar("timeField", "timestamp", opciones.timeseries && opciones.timeseries.timeField);
verificar("metaField", "user_id", opciones.timeseries && opciones.timeseries.metaField);
verificar("retencion en segundos", RETENCION_SEGUNDOS, opciones.expireAfterSeconds);
verificar("indice del metaField", true, indices.indexOf("user_id_1_timestamp_1") !== -1);
verificar("indice { event_type: 1 }", true, indices.indexOf("event_type_1") !== -1);

// Todos los eventos deben caer dentro de la ventana de retencion. Si alguno
// la supera, el monitor de TTL de MongoDB lo eliminaria poco despues de esta
// carga: el script informaria exito y los datos desapareceran a continuacion,
// sin ningun aviso. Comprobarlo aqui convierte esa perdida silenciosa en un
// error explicito.
//
// Se compara contra la retencion y no contra un rango de fechas fijo, para que
// la comprobacion siga siendo valida al agregar eventos de cualquier fecha.
const limite = new Date(Date.now() - RETENCION_SEGUNDOS * 1000);
const vencidos = coll.countDocuments({ timestamp: { $lt: limite } });
verificar("eventos dentro de la retencion (" + RETENCION_DIAS + " dias)", 0, vencidos);

if (vencidos > 0) {
  print("");
  print("  " + vencidos + " evento(s) del seed son anteriores a " + limite.toISOString() + ".");
  print("  MongoDB los eliminara por TTL en cuanto corra su monitor.");
  print("  Actualizar las fechas de seed_data.json o ampliar RETENCION_DIAS.");
}

// El modelo admite eventos de clientes identificados y de visitantes
// anonimos; el seed debe ejercitar los dos casos.
const anonimos = coll.countDocuments({ user_id: { $exists: false } });
verificar("eventos de visitante anonimo (>0)", true, anonimos > 0);

print("");
if (fallos > 0) {
  print("Carga INCOMPLETA: " + fallos + " verificaciones fallaron.");
  quit(1);
}

print("Cargados " + coll.countDocuments() + " eventos en " + DB_NAME + "." + COLL +
      " (" + anonimos + " de visitante anonimo), con retencion de " + RETENCION_DIAS + " dias.");
