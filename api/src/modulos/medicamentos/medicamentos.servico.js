const repositorio = require('./medicamentos.repositorio');
const { normalizarTexto, somenteDigitos } = require('../../utils/normalizacao');

function limitarNumero(valor, { padrao, minimo, maximo }) {
  const numero = Number(valor);
  if (!Number.isFinite(numero)) {
    return padrao;
  }

  return Math.max(minimo, Math.min(maximo, Math.trunc(numero)));
}

function pontuarMedicamento(item, termo) {
  const termoNormalizado = normalizarTexto(termo);
  const termoDigitos = somenteDigitos(termo);
  const nome = normalizarTexto(item.nome_produto);
  const principio = normalizarTexto(item.principio_ativo);
  const apresentacao = normalizarTexto(item.apresentacao);
  const dosagem = normalizarTexto(item.concentracao_dosagem || '');
  const classe = normalizarTexto(item.classe_terapeutica || '');
  const tipoMedicamento = normalizarTexto(item.tipo_medicamento || '');
  const fabricante = normalizarTexto(item.fabricante);
  const registro = item.registro || '';
  const ean = item.ean || '';
  const pmc = somenteDigitos(item.pmc || '');

  let score = 0;

  if (nome === termoNormalizado) {
    score += 1200;
  }
  if (nome.startsWith(termoNormalizado)) {
    score += 900;
  }
  if (nome.includes(termoNormalizado)) {
    score += 600;
  }
  if (principio.startsWith(termoNormalizado)) {
    score += 400;
  } else if (principio.includes(termoNormalizado)) {
    score += 260;
  }
  if (apresentacao.includes(termoNormalizado)) {
    score += 220;
  }
  if (dosagem.includes(termoNormalizado)) {
    score += 240;
  }
  if (classe.includes(termoNormalizado)) {
    score += 210;
  }
  if (tipoMedicamento.includes(termoNormalizado)) {
    score += 180;
  }
  if (fabricante.includes(termoNormalizado)) {
    score += 180;
  }
  if (termoDigitos && registro.includes(termoDigitos)) {
    score += 540;
  }
  if (termoDigitos && ean === termoDigitos) {
    score += 800;
  }
  if (termoDigitos && pmc.includes(termoDigitos)) {
    score += 120;
  }
  if (item.pmc !== null && item.pmc !== undefined) {
    score += 20;
  }

  return score;
}

async function listarMedicamentos(consulta = {}) {
  const limite = limitarNumero(consulta.limite, {
    padrao: 20,
    minimo: 1,
    maximo: 100,
  });
  const pagina = limitarNumero(consulta.pagina, {
    padrao: 1,
    minimo: 1,
    maximo: 10000,
  });

  const resultado = await repositorio.listarMedicamentos({
    limite,
    pagina,
    fabricante: consulta.fabricante,
    principioAtivo: consulta.principioAtivo,
    registro: consulta.registro,
  });

  return {
    dados: resultado.itens,
    meta: {
      limite,
      pagina,
      total: resultado.total,
      total_paginas: Math.max(1, Math.ceil(resultado.total / limite)),
    },
  };
}

async function buscarMedicamentosPorTermo(termo, limiteInformado) {
  const termoLimpo = (termo || '').trim();
  if (termoLimpo.length < 2) {
    return {
      dados: [],
      meta: {
        termo: termoLimpo,
        limite: 0,
        total: 0,
      },
    };
  }

  const limite = limitarNumero(limiteInformado, {
    padrao: 12,
    minimo: 1,
    maximo: 50,
  });

  const candidatos = await repositorio.buscarPorTermo({
    termo: termoLimpo,
    limiteExpandido: Math.max(limite * 4, 24),
  });

  candidatos.sort((a, b) => {
    const scoreA = pontuarMedicamento(a, termoLimpo);
    const scoreB = pontuarMedicamento(b, termoLimpo);
    if (scoreA !== scoreB) {
      return scoreB - scoreA;
    }

    const nomeA = a.nome_produto || '';
    const nomeB = b.nome_produto || '';
    return nomeA.localeCompare(nomeB, 'pt-BR');
  });

  const dados = candidatos.slice(0, limite);

  return {
    dados,
    meta: {
      termo: termoLimpo,
      limite,
      total: dados.length,
    },
  };
}

async function buscarMedicamentosPorIds(idsInformados) {
  const ids =
    Array.isArray(idsInformados)
      ? idsInformados
      : String(idsInformados || '')
          .split(',')
          .map((id) => id.trim())
          .filter(Boolean);

  const dados = await repositorio.buscarPorIds(ids);

  return {
    dados,
    meta: {
      total: dados.length,
    },
  };
}

async function buscarMedicamentoPorId(id) {
  const medicamento = await repositorio.buscarPorId(id);
  if (!medicamento) {
    const erro = new Error('Medicamento nao encontrado.');
    erro.statusCode = 404;
    throw erro;
  }

  return {
    dado: medicamento,
  };
}

async function buscarMedicamentosPorRegistro(registro) {
  const itens = await repositorio.buscarPorRegistro(registro);
  return {
    dados: itens,
    meta: {
      registro,
      total: itens.length,
    },
  };
}

module.exports = {
  buscarMedicamentoPorId,
  buscarMedicamentosPorIds,
  buscarMedicamentosPorRegistro,
  buscarMedicamentosPorTermo,
  listarMedicamentos,
};
