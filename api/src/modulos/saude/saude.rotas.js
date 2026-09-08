const express = require('express');
const { testarConexao } = require('../../config/postgres');

function criarRotasSaude() {
  const router = express.Router();

  router.get('/', async (req, res, next) => {
    try {
      const resultadoBanco = await testarConexao();
      res.json({
        status: 'ok',
        servico: 'catalogo-pmc',
        banco: 'ok',
        horario_banco: resultadoBanco.agora,
      });
    } catch (erro) {
      next(erro);
    }
  });

  return router;
}

module.exports = {
  criarRotasSaude,
};
