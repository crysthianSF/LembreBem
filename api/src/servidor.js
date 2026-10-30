const { criarApp } = require('./app');
const { obterConfiguracao } = require('./config/ambiente');
const { encerrarPool, testarConexao } = require('./config/postgres');

let servidorAtivo;
let encerrando = false;

async function encerrarServidor(sinal) {
  if (encerrando) {
    return;
  }

  encerrando = true;
  console.info(`[API] Encerrando servidor (${sinal})...`);

  try {
    if (servidorAtivo) {
      await new Promise((resolve, reject) => {
        servidorAtivo.close((erro) => {
          if (erro) {
            reject(erro);
            return;
          }
          resolve();
        });
      });
    }

    await encerrarPool();
    console.info('[API] Recursos encerrados com sucesso.');
    process.exit(0);
  } catch (erro) {
    console.error('[API] Falha ao encerrar a API do catalogo:', erro.message);
    process.exit(1);
  }
}

async function iniciar() {
  const configuracao = obterConfiguracao();
  const app = criarApp();

  await testarConexao();
  console.info('[API] Conexao com o banco validada com sucesso.');

  servidorAtivo = app.listen(configuracao.porta, () => {
    console.info(
      `[API] Servidor do catalogo iniciado em http://localhost:${configuracao.porta}`,
    );
  });
}

process.on('SIGINT', () => {
  encerrarServidor('SIGINT');
});

process.on('SIGTERM', () => {
  encerrarServidor('SIGTERM');
});

iniciar().catch(() => {
  console.error('[API] Falha ao iniciar a API do catalogo. Verifique a configuracao e o certificado do banco.');
  process.exit(1);
});
