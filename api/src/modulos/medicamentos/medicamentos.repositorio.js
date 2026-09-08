const { obterPool } = require('../../config/postgres');
const {
  normalizarTexto,
  somenteDigitos,
  textoLimpo,
} = require('../../utils/normalizacao');

function numeroOuNull(valor) {
  if (valor === null || valor === undefined || valor === '') {
    return null;
  }

  const numero = Number(valor);
  return Number.isFinite(numero) ? numero : null;
}

function inteiroOuNull(valor) {
  const numero = numeroOuNull(valor);
  return numero === null ? null : Math.trunc(numero);
}

function mapearMedicamento(linha) {
  if (!linha) {
    return null;
  }

  return {
    id: inteiroOuNull(linha.id),
    medicamento_id: inteiroOuNull(linha.medicamento_id),
    codigo_ggrem: textoLimpo(linha.codigo_ggrem),
    registro: textoLimpo(linha.registro),
    numero_registro: textoLimpo(linha.registro),
    nome_produto: textoLimpo(linha.nome_produto),
    nome_produto_normalizado: textoLimpo(linha.nome_produto_normalizado),
    principio_ativo: textoLimpo(linha.principio_ativo),
    principio_ativo_normalizado: textoLimpo(linha.principio_ativo_normalizado),
    principios_ativos: Array.isArray(linha.principios_ativos)
      ? linha.principios_ativos
      : [],
    fabricante: textoLimpo(linha.fabricante),
    empresa_detentora_registro: textoLimpo(linha.fabricante),
    fabricante_normalizado: textoLimpo(linha.fabricante_normalizado),
    cnpj_fabricante: textoLimpo(linha.cnpj_fabricante),
    apresentacao: textoLimpo(linha.apresentacao),
    apresentacao_normalizada: textoLimpo(linha.apresentacao_normalizada),
    concentracao_dosagem: textoLimpo(linha.concentracao_dosagem),
    unidade: textoLimpo(linha.unidade),
    classe_terapeutica: textoLimpo(linha.classe_terapeutica),
    tipo_produto: textoLimpo(linha.tipo_produto),
    tipo_medicamento: textoLimpo(linha.tipo_medicamento),
    categoria_regulatoria:
      textoLimpo(linha.tipo_produto) || textoLimpo(linha.tipo_medicamento),
    situacao_registro: '',
    regime_preco: textoLimpo(linha.regime_preco),
    ean: textoLimpo(linha.ean),
    ean_1: textoLimpo(linha.ean_1),
    ean_2: textoLimpo(linha.ean_2),
    ean_3: textoLimpo(linha.ean_3),
    pf: numeroOuNull(linha.pf),
    pmc: numeroOuNull(linha.pmc),
    preco: numeroOuNull(linha.preco),
    aliquota_pf_padrao: textoLimpo(linha.aliquota_pf_padrao),
    aliquota_pmc_padrao: textoLimpo(linha.aliquota_pmc_padrao),
    restricao_hospitalar: linha.restricao_hospitalar,
    cap: linha.cap,
    confaz_87: linha.confaz_87,
    icms_0: linha.icms_0,
    analise_recursal: textoLimpo(linha.analise_recursal),
    credito_tributario_piscofins: textoLimpo(
      linha.credito_tributario_piscofins,
    ),
    comercializacao_2024: linha.comercializacao_2024,
    tarja: textoLimpo(linha.tarja),
    destinacao_comercial: textoLimpo(linha.destinacao_comercial),
    precos_pf: linha.precos_pf || {},
    precos_pmc: linha.precos_pmc || {},
    principios_ativos_detalhados:
      linha.principios_ativos_detalhados || linha.principios_ativos || [],
  };
}

function montarFiltrosDeListagem({ fabricante, principioAtivo, registro }) {
  const condicoes = [];
  const parametros = [];

  if (fabricante) {
    parametros.push(`%${normalizarTexto(fabricante)}%`);
    condicoes.push(`fabricante_normalizado like $${parametros.length}`);
  }

  if (principioAtivo) {
    parametros.push(`%${normalizarTexto(principioAtivo)}%`);
    condicoes.push(`principio_ativo_normalizado like $${parametros.length}`);
  }

  if (registro) {
    parametros.push(`%${textoLimpo(registro)}%`);
    condicoes.push(`registro like $${parametros.length}`);
  }

  return {
    clausulaWhere: condicoes.length ? `where ${condicoes.join(' and ')}` : '',
    parametros,
  };
}

async function listarMedicamentos({ limite, pagina, fabricante, principioAtivo, registro }) {
  const pool = obterPool();
  const offset = (pagina - 1) * limite;
  const filtros = montarFiltrosDeListagem({
    fabricante,
    principioAtivo,
    registro,
  });

  const sqlBase = `
    from catalogo.medicamentos
    ${filtros.clausulaWhere}
  `;

  const totalPromise = pool.query(
    `select count(*)::int as total ${sqlBase}`,
    filtros.parametros,
  );

  const parametrosDados = [...filtros.parametros, limite, offset];
  const dadosPromise = pool.query(
    `
      select *
      ${sqlBase}
      order by nome_produto asc, apresentacao asc, id asc
      limit $${parametrosDados.length - 1}
      offset $${parametrosDados.length}
    `,
    parametrosDados,
  );

  const [resultadoTotal, resultadoDados] = await Promise.all([
    totalPromise,
    dadosPromise,
  ]);

  return {
    total: resultadoTotal.rows[0]?.total || 0,
    itens: resultadoDados.rows.map(mapearMedicamento),
  };
}

async function buscarPorTermo({ termo, limiteExpandido }) {
  const pool = obterPool();
  const termoNormalizado = normalizarTexto(termo);
  const termoDigitos = somenteDigitos(termo);
  const parametros = [];
  const condicoes = [];

  if (termoNormalizado) {
    parametros.push(`%${termoNormalizado}%`);
    const indice = parametros.length;
    condicoes.push(`nome_produto_normalizado like $${indice}`);
    condicoes.push(`principio_ativo_normalizado like $${indice}`);
    condicoes.push(`apresentacao_normalizada like $${indice}`);
    condicoes.push(`fabricante_normalizado like $${indice}`);
    condicoes.push(`lower(coalesce(concentracao_dosagem, '')) like $${indice}`);
    condicoes.push(`lower(coalesce(classe_terapeutica, '')) like $${indice}`);
    condicoes.push(`lower(coalesce(tipo_medicamento, '')) like $${indice}`);
  }

  if (termoDigitos) {
    parametros.push(`%${termoDigitos}%`);
    const indiceRegistro = parametros.length;
    condicoes.push(`registro like $${indiceRegistro}`);
    condicoes.push(`codigo_ggrem like $${indiceRegistro}`);
    condicoes.push(
      `regexp_replace(coalesce(pmc::text, ''), '[^0-9]', '', 'g') like $${indiceRegistro}`,
    );

    parametros.push(termoDigitos);
    const indiceEan = parametros.length;
    condicoes.push(`ean = $${indiceEan}`);
    condicoes.push(`ean_1 = $${indiceEan}`);
    condicoes.push(`ean_2 = $${indiceEan}`);
    condicoes.push(`ean_3 = $${indiceEan}`);
  }

  if (!condicoes.length) {
    return [];
  }

  parametros.push(limiteExpandido);

  const resultado = await pool.query(
    `
      select *
      from catalogo.medicamentos
      where ${condicoes.join(' or ')}
      limit $${parametros.length}
    `,
    parametros,
  );

  return resultado.rows.map(mapearMedicamento);
}

async function buscarPorIds(ids) {
  const idsLimpos =
    Array.isArray(ids)
      ? ids
          .map((id) => somenteDigitos(id))
          .filter(Boolean)
          .map((id) => Number(id))
          .filter((id) => Number.isFinite(id))
      : [];

  if (!idsLimpos.length) {
    return [];
  }

  const pool = obterPool();
  const resultado = await pool.query(
    `
      select *
      from catalogo.medicamentos
      where id = any($1::bigint[])
    `,
    [idsLimpos],
  );

  return resultado.rows.map(mapearMedicamento);
}

async function buscarPorId(id) {
  const pool = obterPool();
  const resultado = await pool.query(
    `
      select
        v.*,
        a.precos_pf,
        a.precos_pmc,
        coalesce(
          (
            select json_agg(
              json_build_object(
                'id', pa.id,
                'nome', pa.nome
              )
              order by mpa.ordem asc, pa.nome asc
            )
            from catalogo.medicamentos_principios_ativos mpa
            join catalogo.principios_ativos pa
              on pa.id = mpa.principio_ativo_id
            where mpa.medicamento_id = v.medicamento_id
          ),
          '[]'::json
        ) as principios_ativos_detalhados
      from catalogo.medicamentos v
      join catalogo.apresentacoes a
        on a.id = v.id
      where v.id = $1
      limit 1
    `,
    [id],
  );

  return mapearMedicamento(resultado.rows[0]);
}

async function buscarPorRegistro(registro) {
  const pool = obterPool();
  const resultado = await pool.query(
    `
      select *
      from catalogo.medicamentos
      where registro = $1
      order by nome_produto asc, apresentacao asc
    `,
    [textoLimpo(registro)],
  );

  return resultado.rows.map(mapearMedicamento);
}

module.exports = {
  buscarPorId,
  buscarPorIds,
  buscarPorRegistro,
  buscarPorTermo,
  listarMedicamentos,
};
