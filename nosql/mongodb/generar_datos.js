// ------------------------------------------------------------
// Genera los datos de la capa documental en MongoDB.
//
// Se ejecuta dentro del contenedor mongodb, que monta
// seed_data.json en /scripts:
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
// Crea la coleccion user_events como Time Series Collection, crea los
// indices secundarios y carga los documentos de seed_data.json.
// ------------------------------------------------------------

const fs = require("fs");

const DB_NAME = process.env.MONGO_DATABASE || "bdia_g04_mongodb";
const COLL = "user_events";
const SEED_PATH = "/scripts/seed_data.json";

const database = db.getSiblingDB(DB_NAME);

// 1. Recrear la coleccion como serie de tiempo. El drop previo deja el
// script idempotente: volver a cargarlo restaura el estado inicial.
database.getCollection(COLL).drop();
database.createCollection(COLL, {
  timeseries: {
    timeField: "timestamp",
    metaField: "user_id",
    granularity: "seconds"
  }
});

const coll = database.getCollection(COLL);

// 2. Indice secundario para las consultas analiticas que filtran por
// event_type (../modelo_nosql.md, 1.5). El filtro por user_id lo resuelve
// el indice automatico { user_id: 1, timestamp: 1 } del metaField.
coll.createIndex({ event_type: 1 });

// 3. Cargar los documentos de ejemplo. En el archivo el timestamp es una
// cadena ISO-8601 legible; aqui se convierte a Date, que es el tipo que
// espera el timeField.
const docs = JSON.parse(fs.readFileSync(SEED_PATH, "utf8")).map(function (d) {
  return Object.assign({}, d, { timestamp: new Date(d.timestamp) });
});
coll.insertMany(docs);

print("Cargados " + docs.length + " eventos en " + DB_NAME + "." + COLL + ".");
