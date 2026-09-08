const express = require('express');
const controlador = require('./medicamentos.controlador');

function criarRotasMedicamentos() {
  const router = express.Router();

  router.get('/', controlador.listarMedicamentos);
  router.get('/busca', controlador.buscarPorTermo);
  router.get('/ids', controlador.buscarPorIds);
  router.get('/registro/:registro', controlador.buscarPorRegistro);
  router.get('/fabricante/:fabricante', controlador.listarPorFabricante);
  router.get('/principio-ativo/:nome', controlador.listarPorPrincipioAtivo);
  router.get('/:id', controlador.buscarPorId);

  return router;
}

module.exports = {
  criarRotasMedicamentos,
};
