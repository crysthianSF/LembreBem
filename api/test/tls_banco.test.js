const test = require('node:test');
const assert = require('node:assert/strict');
const { opcoesBanco } = require('../src/config/tls_banco');

test('TLS obrigatorio sem substituir limites do pool', () => {
  assert.deepEqual(opcoesBanco('postgres://user:secret@localhost/db').ssl,
    { rejectUnauthorized: true });
});

test('rejeita parametros que podem substituir TLS', () => {
  for (const chave of ['sslmode', 'sslcert', 'sslkey', 'sslrootcert', 'SSLMode', 'uselibpqcompat']) {
    assert.throws(() => opcoesBanco(`postgres://user:secret@localhost/db?${chave}=disable`),
      /Configure TLS/);
  }
});

test('erros de configuracao nao expoem URL ou credenciais', () => {
  assert.throws(() => opcoesBanco('secret-invalid-url'), { message: 'URL do banco invalida.' });
  assert.throws(() => opcoesBanco('https://user:secret@localhost/db'), /URL do banco invalida/);
  assert.throws(() => opcoesBanco('postgres://user:secret@localhost/db', 'arquivo-inexistente.pem'),
    { message: 'Nao foi possivel carregar o certificado CA do banco.' });
});
