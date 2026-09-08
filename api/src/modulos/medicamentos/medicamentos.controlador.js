const servico = require('./medicamentos.servico');

async function listarMedicamentos(req, res, next) {
  try {
    const resposta = await servico.listarMedicamentos({
      limite: req.query.limite,
      pagina: req.query.pagina,
      fabricante: req.query.fabricante,
      principioAtivo: req.query.principioAtivo,
      registro: req.query.registro,
    });

    res.json(resposta);
  } catch (erro) {
    next(erro);
  }
}

async function buscarPorTermo(req, res, next) {
  try {
    const resposta = await servico.buscarMedicamentosPorTermo(
      req.query.termo,
      req.query.limite,
    );
    res.json(resposta);
  } catch (erro) {
    next(erro);
  }
}

async function buscarPorId(req, res, next) {
  try {
    const resposta = await servico.buscarMedicamentoPorId(req.params.id);
    res.json(resposta);
  } catch (erro) {
    next(erro);
  }
}

async function buscarPorIds(req, res, next) {
  try {
    const resposta = await servico.buscarMedicamentosPorIds(req.query.ids);
    res.json(resposta);
  } catch (erro) {
    next(erro);
  }
}

async function buscarPorRegistro(req, res, next) {
  try {
    const resposta = await servico.buscarMedicamentosPorRegistro(
      req.params.registro,
    );
    res.json(resposta);
  } catch (erro) {
    next(erro);
  }
}

async function listarPorFabricante(req, res, next) {
  try {
    const resposta = await servico.listarMedicamentos({
      limite: req.query.limite,
      pagina: req.query.pagina,
      fabricante: req.params.fabricante,
    });

    res.json(resposta);
  } catch (erro) {
    next(erro);
  }
}

async function listarPorPrincipioAtivo(req, res, next) {
  try {
    const resposta = await servico.listarMedicamentos({
      limite: req.query.limite,
      pagina: req.query.pagina,
      principioAtivo: req.params.nome,
    });

    res.json(resposta);
  } catch (erro) {
    next(erro);
  }
}

module.exports = {
  buscarPorId,
  buscarPorIds,
  buscarPorRegistro,
  buscarPorTermo,
  listarMedicamentos,
  listarPorFabricante,
  listarPorPrincipioAtivo,
};
