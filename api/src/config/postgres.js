const dns = require('dns');
const { Pool } = require('pg');
const { garantirUrlBanco } = require('./ambiente');
const { opcoesBanco } = require('./tls_banco');

let pool;

function obterPool() {
  if (!pool) {
    // Em alguns ambientes Windows o host do Supabase resolve primeiro para IPv6
    // e a conexao expira antes de tentar IPv4.
    dns.setDefaultResultOrder('ipv4first');

    pool = new Pool({
      ...opcoesBanco(garantirUrlBanco(), process.env.DATABASE_CA_CERT_PATH),
      family: 4,
      max: 10,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 10000,
    });

    pool.on('error', () => {
      console.error('[Banco] Erro inesperado no pool PostgreSQL.');
    });
  }

  return pool;
}

async function testarConexao() {
  const resultado = await obterPool().query('select now() as agora');
  return resultado.rows[0];
}

async function encerrarPool() {
  if (!pool) {
    return;
  }

  const poolAtual = pool;
  pool = undefined;
  await poolAtual.end();
}

module.exports = {
  encerrarPool,
  obterPool,
  testarConexao,
};
