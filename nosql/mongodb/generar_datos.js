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
const LIMITE_RETENCION = new Date(Date.now() - RETENCION_SEGUNDOS * 1000);

const database = db.getSiblingDB(DB_NAME);

// 1. Leer y VALIDAR el seed ANTES de tocar la base. Se valida primero para
// que un seed mal formado no deje la coleccion vacia: si algo falla, la
// carga anterior sigue intacta. Sin esta comprobacion,
// una fecha mal escrita produce un Invalid Date que MongoDB almacena como
// 1970-01-01: el documento entra sin error y queda invisible para todas
// las consultas, porque todas acotan una ventana temporal.
const crudos = JSON.parse(fs.readFileSync(SEED_PATH, "utf8"));
const errores = [];

// La forma del archivo se comprueba antes que su contenido. Sin esto, un
// arreglo vacio no genera ningun error por documento, la ejecucion sigue y
// insertMany falla con un error del driver despues del drop, dejando la
// coleccion vacia: el mismo fallo destructivo que esta validacion evita.
if (!Array.isArray(crudos)) {
  print("El seed no es un arreglo JSON; no se carga nada. La base NO fue modificada.");
  quit(1);
}
if (crudos.length === 0) {
  print("El seed no tiene documentos; no se carga nada. La base NO fue modificada.");
  quit(1);
}

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
  if (!isNaN(ts.getTime()) && ts < LIMITE_RETENCION) {
    errores.push("documento " + i + " (" + d._id + "): " + d.timestamp +
      " supera la retencion de " + RETENCION_DIAS + " dias; MongoDB lo eliminaria por TTL");
  }
  return Object.assign({}, d, { timestamp: ts });
});

// Los _id se comprueban sobre el conjunto y no documento por documento. Las
// Time Series Collections no imponen unicidad sobre _id, a diferencia de una
// coleccion comun, de modo que MongoDB aceptaria los duplicados sin error y el
// conteo final seguiria coincidiendo con el del archivo.
const vistos = {};
crudos.forEach(function (d, i) {
  if (d._id === undefined) return;
  if (Object.prototype.hasOwnProperty.call(vistos, d._id)) {
    errores.push("documento " + i + " (" + d._id + "): _id duplicado, ya usado por el documento " +
      vistos[d._id]);
  } else {
    vistos[d._id] = i;
  }
});

if (errores.length > 0) {
  print("El seed tiene " + errores.length + " problema(s); no se carga nada:");
  errores.forEach(function (e) { print("  " + e); });
  print("");
  print("Si el motivo es la retencion, las fechas del seed envejecieron: hay que");
  print("actualizarlas, y con ellas los resultados esperados de consultas/, o ampliar");
  print("RETENCION_DIAS. La base NO fue modificada.");
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

// La retencion ya se comprobo sobre el seed antes de tocar la base, de modo que
// volver a contar documentos vencidos daria cero siempre. Lo util aqui es otra
// cosa: cuanto margen le queda al evento mas antiguo antes de alcanzarla.
const masViejo = coll.find({}, { timestamp: 1 }).sort({ timestamp: 1 }).limit(1).toArray()[0];
const margenDias = Math.floor(
  (masViejo.timestamp.getTime() - LIMITE_RETENCION.getTime()) / (24 * 60 * 60 * 1000)
);

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
print("El evento mas antiguo es del " + masViejo.timestamp.toISOString().substring(0, 10) +
      " y le quedan " + margenDias + " dias antes de alcanzar la retencion.");
