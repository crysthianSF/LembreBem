const cors = require('cors');
const express = require('express');
const { criarRotasMedicamentos } = require('./modulos/medicamentos/medicamentos.rotas');
const { criarRotasSaude } = require('./modulos/saude/saude.rotas');

function criarApp() {
  const app = express();

  app.disable('x-powered-by');
  app.use(
    cors({
      origin: true,
      credentials: true,
    }),
  );
  app.use(express.json({ limit: '1mb' }));

  app.use((req, res, next) => {
    const inicio = Date.now();
    res.on('finish', () => {
      const duracao = Date.now() - inicio;
      console.info(
        `[API] ${req.method} ${req.originalUrl} -> ${res.statusCode} em ${duracao}ms`,
      );
    });
    next();
  });

  app.use('/api/saude', criarRotasSaude());
  app.use('/api/medicamentos', criarRotasMedicamentos());

  app.use((req, res) => {
    res.status(404).json({
      erro: 'Rota nao encontrada.',
      rota: req.originalUrl,
    });
  });

  app.use((erro, req, res, next) => {
    const status = erro.statusCode || 500;
    const mensagem =
      status >= 500
        ? 'Falha interna ao consultar o catalogo.'
        : erro.message || 'Falha ao processar a requisicao.';

    if (status >= 500) {
      console.error('[API] Erro interno:', erro);
    } else {
      console.warn(`[API] Resposta controlada ${status}: ${erro.message}`);
    }

    res.status(status).json({
      erro: mensagem,
      detalhe: process.env.NODE_ENV === 'production' ? undefined : erro.message,
    });
  });

  return app;
}

module.exports = {
  criarApp,
};
