const { Pool } = require("pg");

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.PGSSL === "true" ? { rejectUnauthorized: false } : false,
});

async function query(sql, params = []) {
  return pool.query(sql, params);
}

async function callFn(fnName, args = []) {
  const placeholders = args.map((_, i) => `$${i + 1}`).join(", ");
  const sql = `SELECT * FROM ${fnName}(${placeholders})`;
  return query(sql, args);
}

module.exports = {
  pool,
  query,
  callFn,
};
