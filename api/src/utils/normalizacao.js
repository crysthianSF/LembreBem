function textoLimpo(valor) {
  if (valor === null || valor === undefined) {
    return '';
  }

  return String(valor).replace(/\s+/g, ' ').trim();
}

function normalizarTexto(valor) {
  return textoLimpo(valor)
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^\w/%+.\- ]+/g, ' ')
    .replace(/_/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizarCabecalho(valor) {
  return normalizarTexto(valor)
    .replace(/[%]/g, ' ')
    .replace(/[().:,]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function somenteDigitos(valor) {
  return textoLimpo(valor).replace(/\D+/g, '');
}

function ehValorVazio(valor) {
  const texto = textoLimpo(valor);
  if (!texto) {
    return true;
  }

  return /^[-–—]+$/.test(texto);
}

function textoOuNull(valor) {
  const texto = textoLimpo(valor);
  return ehValorVazio(texto) ? null : texto;
}

function booleanoSimNao(valor) {
  const texto = normalizarTexto(valor);
  if (!texto) {
    return null;
  }

  if (['sim', 's', 'true', '1'].includes(texto)) {
    return true;
  }

  if (['nao', 'n', 'false', '0'].includes(texto)) {
    return false;
  }

  return null;
}

function numeroMonetario(valor) {
  if (valor === null || valor === undefined || valor === '') {
    return null;
  }

  if (typeof valor === 'number') {
    return Number.isFinite(valor) ? valor : null;
  }

  const texto = textoLimpo(valor)
    .replace(/\./g, '')
    .replace(',', '.')
    .replace(/[^\d.\-]/g, '');

  if (!texto) {
    return null;
  }

  const numero = Number(texto);
  return Number.isFinite(numero) ? numero : null;
}

function quebrarPrincipiosAtivos(valor) {
  const texto = textoLimpo(valor);
  if (!texto) {
    return [];
  }

  return texto
    .split(/;|\|/g)
    .map((item) => textoLimpo(item))
    .filter(Boolean);
}

module.exports = {
  booleanoSimNao,
  ehValorVazio,
  normalizarCabecalho,
  normalizarTexto,
  numeroMonetario,
  quebrarPrincipiosAtivos,
  somenteDigitos,
  textoLimpo,
  textoOuNull,
};
