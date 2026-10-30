const fs = require('node:fs');

function opcoesBanco(databaseUrl, caminhoCa) {
  let uri;
  try {
    uri = new URL(databaseUrl);
  } catch (_) {
    throw new Error('URL do banco invalida.');
  }
  if (!['postgres:', 'postgresql:'].includes(uri.protocol) || !uri.hostname) {
    throw new Error('URL do banco invalida.');
  }
  if ([...uri.searchParams.keys()].some((chave) =>
    chave.toLowerCase().startsWith('ssl') ||
    chave.toLowerCase() === 'uselibpqcompat')) {
    throw new Error('Configure TLS somente no objeto ssl, sem parametros SSL na URL.');
  }
  let ca;
  if (caminhoCa) {
    try {
      ca = fs.readFileSync(caminhoCa, 'utf8');
      if (!ca.trim()) throw new Error();
    } catch (_) {
      throw new Error('Nao foi possivel carregar o certificado CA do banco.');
    }
  }
  return {
    connectionString: databaseUrl,
    ssl: { rejectUnauthorized: true, ...(ca ? { ca } : {}) },
  };
}

module.exports = { opcoesBanco };
