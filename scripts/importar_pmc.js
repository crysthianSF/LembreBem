const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');
const { Pool } = require('pg');
const { obterConfiguracao } = require('../api/src/config/ambiente');
const {
  booleanoSimNao,
  normalizarCabecalho,
  normalizarTexto,
  numeroMonetario,
  quebrarPrincipiosAtivos,
  somenteDigitos,
  textoLimpo,
  textoOuNull,
} = require('../api/src/utils/normalizacao');

const ROTULOS_FIXOS = {
  substancia: ['substancia', 'principio ativo', 'princípio ativo'],
  cnpj: ['cnpj'],
  laboratorio: ['laboratorio', 'laboratório', 'empresa', 'fabricante'],
  codigo_ggrem: ['codigo ggrem', 'código ggrem', 'ggrem'],
  registro: ['registro', 'numero registro', 'n registro'],
  ean_1: ['ean 1', 'ean1'],
  ean_2: ['ean 2', 'ean2'],
  ean_3: ['ean 3', 'ean3'],
  produto: ['produto', 'nome produto', 'nome do produto'],
  apresentacao: ['apresentacao', 'apresentação'],
  classe_terapeutica: ['classe terapeutica', 'classe terapêutica'],
  tipo_produto: [
    'tipo de produto status do produto',
    'tipo de produto',
    'tipo produto',
  ],
  regime_preco: ['regime de preco', 'regime de preço'],
  restricao_hospitalar: ['restricao hospitalar', 'restrição hospitalar'],
  cap: ['cap'],
  confaz_87: ['confaz 87', 'confaz87'],
  icms_0: ['icms 0', 'icms 0 '],
  analise_recursal: ['analise recursal', 'análise recursal'],
  credito_tributario_piscofins: [
    'lista de concessao de credito tributario pis/cofins',
    'lista de concessao de credito tributario pis cofins',
  ],
  comercializacao_2024: ['comercializacao 2024', 'comercialização 2024'],
  tarja: ['tarja'],
  destinacao_comercial: ['destinacao comercial', 'destinação comercial'],
};

const CHAVES_ALIQUOTA_PREFERIDA = [
  '18',
  '17',
  '0',
  'sem_impostos',
  '17_5',
  '19',
  '12',
  '20',
  '20_5',
  '21',
  '22',
  '22_5',
  '23',
];

async function main() {
  const argumentos = lerArgumentos(process.argv.slice(2));
  const caminhoArquivo = path.resolve(process.cwd(), argumentos.arquivo);

  if (!fs.existsSync(caminhoArquivo)) {
    throw new Error(`Arquivo PMC nao encontrado: ${caminhoArquivo}`);
  }

  console.info(`[Importador] Lendo arquivo: ${caminhoArquivo}`);
  const planilha = lerPlanilha(caminhoArquivo);

  console.info(
    `[Importador] Aba utilizada: ${planilha.nomeAba} | cabecalho encontrado na linha ${planilha.linhaCabecalho}.`,
  );

  const colecoes = normalizarColecoes(planilha, caminhoArquivo);

  console.info(
    `[Importador] Linhas validas: ${colecoes.estatisticas.linhasValidas} | fabricantes: ${colecoes.fabricantes.length} | medicamentos base: ${colecoes.medicamentos.length} | apresentacoes: ${colecoes.apresentacoes.length}.`,
  );

  if (argumentos.somenteValidar) {
    imprimirResumoValidacao(planilha, colecoes);
    return;
  }

  const configuracao = obterConfiguracao();
  if (!configuracao.urlBanco) {
    throw new Error(
      'Conexao com o banco nao configurada. Preencha SUPABASE_DB_PASSWORD ou DATABASE_URL no arquivo .env.',
    );
  }

  const schema = validarIdentificadorSql(configuracao.schemaCatalogo || 'catalogo');
  const pool = new Pool({
    connectionString: configuracao.urlBanco,
    ssl: { rejectUnauthorized: false },
  });

  const cliente = await pool.connect();

  try {
    await cliente.query('begin');
    await importarColecoes(cliente, schema, colecoes, argumentos);
    await cliente.query('commit');
    console.info('[Importador] Importacao concluida com sucesso.');
  } catch (erro) {
    await cliente.query('rollback');
    throw erro;
  } finally {
    cliente.release();
    await pool.end();
  }
}

function lerArgumentos(argumentos) {
  const resultado = {
    arquivo: 'xls_conformidade_site_20260309_101927947.xlsx',
    modo: 'substituir',
    tamanhoLote: 400,
    somenteValidar: false,
  };

  for (let indice = 0; indice < argumentos.length; indice += 1) {
    const atual = argumentos[indice];

    if (atual === '--somente-validar') {
      resultado.somenteValidar = true;
      continue;
    }

    if (atual === '--arquivo') {
      resultado.arquivo = argumentos[indice + 1];
      indice += 1;
      continue;
    }

    if (atual === '--modo') {
      resultado.modo = argumentos[indice + 1] || resultado.modo;
      indice += 1;
      continue;
    }

    if (atual === '--lote') {
      resultado.tamanhoLote = Number(argumentos[indice + 1]) || resultado.tamanhoLote;
      indice += 1;
    }
  }

  return resultado;
}

function lerPlanilha(caminhoArquivo) {
  const workbook = xlsx.readFile(caminhoArquivo, {
    cellDates: false,
    raw: false,
    dense: true,
  });

  const nomeAba = workbook.SheetNames[0];
  const worksheet = workbook.Sheets[nomeAba];
  const linhas = xlsx.utils.sheet_to_json(worksheet, {
    header: 1,
    raw: false,
    defval: '',
  });

  const cabecalho = detectarCabecalho(linhas);
  const publicadoEm = extrairPublicadoEm(linhas);

  return {
    nomeAba,
    linhas,
    linhaCabecalho: cabecalho.indice + 1,
    cabecalhoOriginal: cabecalho.cabecalhoOriginal,
    colunasFixas: cabecalho.colunasFixas,
    colunasPrecos: cabecalho.colunasPrecos,
    publicadoEm,
  };
}

function detectarCabecalho(linhas) {
  let melhor = null;

  linhas.forEach((linha, indice) => {
    const cabecalhos = linha.map((valor) => normalizarCabecalho(valor));
    const colunasFixas = {};
    let pontuacao = 0;

    Object.entries(ROTULOS_FIXOS).forEach(([campo, sinonimos]) => {
      const colunaEncontrada = cabecalhos.findIndex((coluna) =>
        sinonimos.includes(coluna),
      );

      if (colunaEncontrada >= 0) {
        colunasFixas[campo] = colunaEncontrada;
        pontuacao += 10;
      }
    });

    const colunasPrecos = detectarColunasDePreco(cabecalhos);
    pontuacao +=
      Object.keys(colunasPrecos.pf).length + Object.keys(colunasPrecos.pmc).length;

    const possuiObrigatorios =
      colunasFixas.substancia !== undefined &&
      colunasFixas.produto !== undefined &&
      colunasFixas.apresentacao !== undefined &&
      colunasFixas.registro !== undefined &&
      colunasFixas.codigo_ggrem !== undefined;

    if (!possuiObrigatorios) {
      return;
    }

    if (!melhor || pontuacao > melhor.pontuacao) {
      melhor = {
        indice,
        pontuacao,
        cabecalhoOriginal: linha,
        colunasFixas,
        colunasPrecos,
      };
    }
  });

  if (!melhor) {
    throw new Error(
      'Nao foi possivel detectar o cabecalho da planilha PMC. Verifique se o arquivo e o correto.',
    );
  }

  return melhor;
}

function detectarColunasDePreco(cabecalhos) {
  const colunasPrecos = {
    pf: {},
    pmc: {},
  };

  cabecalhos.forEach((cabecalho, indice) => {
    if (!cabecalho) {
      return;
    }

    const grupo = cabecalho.startsWith('pf ')
      ? 'pf'
      : cabecalho.startsWith('pmc ')
      ? 'pmc'
      : null;

    if (!grupo) {
      return;
    }

    const sufixo = cabecalho.replace(/^pf\s+|^pmc\s+/g, '').trim();
    const chave = normalizarAliquota(sufixo);

    if (chave) {
      colunasPrecos[grupo][chave] = indice;
    }
  });

  return colunasPrecos;
}

function normalizarAliquota(valor) {
  const texto = normalizarCabecalho(valor);
  if (!texto) {
    return null;
  }

  if (texto.includes('sem impostos')) {
    return 'sem_impostos';
  }

  const possuiAlc = /\balc\b/.test(texto);
  const numero = texto.match(/\d+(?:\s+\d+)?/);
  if (!numero) {
    return null;
  }

  let chave = numero[0].replace(/\s+/g, '_');
  if (possuiAlc) {
    chave += '_alc';
  }

  return chave;
}

function extrairPublicadoEm(linhas) {
  for (const linha of linhas.slice(0, 12)) {
    const texto = linha.map((item) => textoLimpo(item)).join(' ');
    const encontrado = texto.match(
      /publicada em (\d{2}\/\d{2}\/\d{4})(?:\s+(\d{2})h(\d{2})min)?/i,
    );

    if (encontrado) {
      const [, data, hora = '00', minuto = '00'] = encontrado;
      const [dia, mes, ano] = data.split('/');
      return `${ano}-${mes}-${dia}T${hora}:${minuto}:00-03:00`;
    }
  }

  return null;
}

function normalizarColecoes(planilha, caminhoArquivo) {
  const hashArquivo = gerarHashArquivo(caminhoArquivo);
  const loteImportacao = `${new Date().toISOString().replace(/[:.]/g, '-')}_${hashArquivo.slice(
    0,
    10,
  )}`;
  const linhasDados = planilha.linhas.slice(planilha.linhaCabecalho);
  const fabricantes = new Map();
  const principiosAtivos = new Map();
  const medicamentos = new Map();
  const apresentacoes = new Map();
  const relacoesPrincipios = new Map();
  let linhasValidas = 0;

  linhasDados.forEach((linha, indice) => {
    const linhaPlanilha = planilha.linhaCabecalho + indice + 1;
    const item = normalizarLinha({
      linha,
      linhaPlanilha,
      planilha,
      caminhoArquivo,
      loteImportacao,
    });

    if (!item) {
      return;
    }

    linhasValidas += 1;
    fabricantes.set(item.fabricante.chave_importacao, item.fabricante);
    medicamentos.set(item.medicamento.registro, item.medicamento);
    apresentacoes.set(item.apresentacao.codigo_ggrem, item.apresentacao);

    item.principiosAtivos.forEach((principio) => {
      principiosAtivos.set(principio.nome_normalizado, principio);
      relacoesPrincipios.set(
        `${item.medicamento.registro}::${principio.nome_normalizado}`,
        {
          registro: item.medicamento.registro,
          principio_normalizado: principio.nome_normalizado,
          ordem: principio.ordem,
          principal: principio.principal,
        },
      );
    });
  });

  return {
    loteImportacao,
    hashArquivo,
    publicadoEm: planilha.publicadoEm,
    fabricantes: Array.from(fabricantes.values()),
    principiosAtivos: Array.from(principiosAtivos.values()),
    medicamentos: Array.from(medicamentos.values()),
    apresentacoes: Array.from(apresentacoes.values()),
    relacoesPrincipios: Array.from(relacoesPrincipios.values()),
    estatisticas: {
      linhasValidas,
    },
  };
}

function normalizarLinha({ linha, linhaPlanilha, planilha, caminhoArquivo, loteImportacao }) {
  const obter = (campo) => {
    const indice = planilha.colunasFixas[campo];
    return indice === undefined ? '' : linha[indice];
  };

  const substancia = textoOuNull(obter('substancia'));
  const produto = textoOuNull(obter('produto'));
  const apresentacao = textoOuNull(obter('apresentacao'));
  const registro = somenteDigitos(obter('registro')) || textoOuNull(obter('registro'));
  const codigoGgrem = somenteDigitos(obter('codigo_ggrem')) || textoOuNull(obter('codigo_ggrem'));

  if (!produto || !apresentacao || !registro || !codigoGgrem) {
    return null;
  }

  const fabricanteNome = textoOuNull(obter('laboratorio')) || 'Fabricante nao informado';
  const cnpj = formatarCnpj(obter('cnpj'));
  const chaveFabricante = cnpj
    ? `cnpj:${cnpj}`
    : `nome:${normalizarTexto(fabricanteNome)}`;
  const precosPf = extrairPrecos(planilha.colunasPrecos.pf, linha);
  const precosPmc = extrairPrecos(planilha.colunasPrecos.pmc, linha);
  const pfPadrao = selecionarPrecoPadrao(precosPf);
  const pmcPadrao = selecionarPrecoPadrao(precosPmc);
  const ean1 = limparEan(obter('ean_1'));
  const ean2 = limparEan(obter('ean_2'));
  const ean3 = limparEan(obter('ean_3'));
  const eanPrincipal = ean1 || ean2 || ean3 || null;
  const concentracaoDosagem = extrairConcentracaoDosagem(apresentacao);
  const unidade = extrairUnidade(concentracaoDosagem);
  const tipoProduto = textoOuNull(obter('tipo_produto'));
  const tipoMedicamento = inferirTipoMedicamento(tipoProduto);
  const principios = quebrarPrincipiosAtivos(substancia).map((nome, indice) => ({
    nome,
    nome_normalizado: normalizarTexto(nome),
    lote_importacao: loteImportacao,
    ordem: indice + 1,
    principal: indice === 0,
  }));

  return {
    fabricante: {
      chave_importacao: chaveFabricante,
      cnpj,
      nome: fabricanteNome,
      nome_normalizado: normalizarTexto(fabricanteNome),
      lote_importacao: loteImportacao,
    },
    medicamento: {
      registro: String(registro),
      nome_produto: produto,
      nome_produto_normalizado: normalizarTexto(produto),
      substancia,
      substancia_normalizada: normalizarTexto(substancia),
      classe_terapeutica: textoOuNull(obter('classe_terapeutica')),
      tipo_produto: tipoProduto,
      tipo_medicamento: tipoMedicamento,
      regime_preco: textoOuNull(obter('regime_preco')),
      fabricante_chave: chaveFabricante,
      lote_importacao: loteImportacao,
      dados_origem: {
        arquivo: path.basename(caminhoArquivo),
        aba: planilha.nomeAba,
        linha_planilha: linhaPlanilha,
        publicado_em: planilha.publicadoEm,
      },
    },
    apresentacao: {
      codigo_ggrem: String(codigoGgrem),
      registro: String(registro),
      apresentacao,
      apresentacao_normalizada: normalizarTexto(apresentacao),
      concentracao_dosagem: concentracaoDosagem,
      unidade,
      ean_1: ean1,
      ean_2: ean2,
      ean_3: ean3,
      ean_principal: eanPrincipal,
      pf_preco_padrao: pfPadrao.valor,
      pmc_preco_padrao: pmcPadrao.valor,
      aliquota_pf_padrao: pfPadrao.aliquota,
      aliquota_pmc_padrao: pmcPadrao.aliquota,
      precos_pf: precosPf,
      precos_pmc: precosPmc,
      restricao_hospitalar: booleanoSimNao(obter('restricao_hospitalar')),
      cap: booleanoSimNao(obter('cap')),
      confaz_87: booleanoSimNao(obter('confaz_87')),
      icms_0: booleanoSimNao(obter('icms_0')),
      analise_recursal: textoOuNull(obter('analise_recursal')),
      credito_tributario_piscofins: textoOuNull(
        obter('credito_tributario_piscofins'),
      ),
      comercializacao_2024: booleanoSimNao(obter('comercializacao_2024')),
      tarja: textoOuNull(obter('tarja')),
      destinacao_comercial: textoOuNull(obter('destinacao_comercial')),
      lote_importacao: loteImportacao,
      dados_origem: {
        arquivo: path.basename(caminhoArquivo),
        aba: planilha.nomeAba,
        linha_planilha: linhaPlanilha,
        publicado_em: planilha.publicadoEm,
      },
    },
    principiosAtivos: principios,
  };
}

function extrairPrecos(colunas, linha) {
  const precos = {};

  Object.entries(colunas).forEach(([aliquota, indice]) => {
    const valor = numeroMonetario(linha[indice]);
    if (valor !== null) {
      precos[aliquota] = valor;
    }
  });

  return precos;
}

function selecionarPrecoPadrao(precos) {
  for (const chave of CHAVES_ALIQUOTA_PREFERIDA) {
    if (precos[chave] !== undefined) {
      return { aliquota: chave, valor: precos[chave] };
    }
  }

  const primeiraAliquota = Object.keys(precos)[0];
  if (!primeiraAliquota) {
    return { aliquota: null, valor: null };
  }

  return {
    aliquota: primeiraAliquota,
    valor: precos[primeiraAliquota],
  };
}

function extrairConcentracaoDosagem(apresentacao) {
  if (!apresentacao) {
    return null;
  }

  const padrao =
    /\d+(?:[.,]\d+)?\s?(?:MG\/ML|G\/ML|MG\/G|G\/G|UI\/ML|UI\/G|MCG|MUI|MEQ|MG|UG|UI|G|%)(?:\s*\+\s*\d+(?:[.,]\d+)?\s?(?:MG\/ML|G\/ML|MG\/G|G\/G|UI\/ML|UI\/G|MCG|MUI|MEQ|MG|UG|UI|G|%))*/gi;
  const encontrados = apresentacao.match(padrao) || [];
  const dosagens = encontrados
    .map((valor) => textoLimpo(valor))
    .filter((valor) => /[a-z%]/i.test(valor));

  return dosagens.length ? dosagens[0] : null;
}

function extrairUnidade(concentracaoDosagem) {
  if (!concentracaoDosagem) {
    return null;
  }

  const encontrado = concentracaoDosagem.match(
    /(MG\/ML|G\/ML|MG\/G|G\/G|UI\/ML|UI\/G|MG|G|MCG|UG|UI|MUI|MEQ|%)/i,
  );

  return encontrado ? encontrado[1].toUpperCase() : null;
}

function inferirTipoMedicamento(tipoProduto) {
  const texto = normalizarTexto(tipoProduto);
  if (!texto) {
    return null;
  }

  if (texto.includes('generico')) {
    return 'generico';
  }
  if (texto.includes('similar')) {
    return 'similar';
  }
  if (texto.includes('novo')) {
    return 'referencia';
  }
  if (texto.includes('biologico')) {
    return 'biologico';
  }
  if (texto.includes('fitoterapico')) {
    return 'fitoterapico';
  }
  if (texto.includes('especifico')) {
    return 'especifico';
  }

  return 'outro';
}

function limparEan(valor) {
  const digitos = somenteDigitos(valor);
  return digitos || null;
}

function formatarCnpj(valor) {
  const digitos = somenteDigitos(valor);
  if (digitos.length !== 14) {
    return null;
  }

  return digitos.replace(
    /^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$/,
    '$1.$2.$3/$4-$5',
  );
}

function gerarHashArquivo(caminhoArquivo) {
  const conteudo = fs.readFileSync(caminhoArquivo);
  return crypto.createHash('sha1').update(conteudo).digest('hex');
}

function validarIdentificadorSql(valor) {
  if (!/^[a-z_][a-z0-9_]*$/i.test(valor)) {
    throw new Error(`Identificador SQL invalido: ${valor}`);
  }

  return valor;
}

async function importarColecoes(cliente, schema, colecoes, argumentos) {
  console.info('[Importador] Gravando fabricantes...');
  await inserirFabricantes(cliente, schema, colecoes.fabricantes, argumentos.tamanhoLote);
  const mapaFabricantes = await carregarMapaIds(
    cliente,
    schema,
    'fabricantes',
    'chave_importacao',
    colecoes.fabricantes.map((item) => item.chave_importacao),
  );

  console.info('[Importador] Gravando principios ativos...');
  await inserirPrincipiosAtivos(
    cliente,
    schema,
    colecoes.principiosAtivos,
    argumentos.tamanhoLote,
  );
  const mapaPrincipios = await carregarMapaIds(
    cliente,
    schema,
    'principios_ativos',
    'nome_normalizado',
    colecoes.principiosAtivos.map((item) => item.nome_normalizado),
  );

  console.info('[Importador] Gravando medicamentos base...');
  const medicamentosParaInsercao = colecoes.medicamentos.map((item) => ({
    registro: item.registro,
    nome_produto: item.nome_produto,
    nome_produto_normalizado: item.nome_produto_normalizado,
    substancia: item.substancia,
    substancia_normalizada: item.substancia_normalizada,
    classe_terapeutica: item.classe_terapeutica,
    tipo_produto: item.tipo_produto,
    tipo_medicamento: item.tipo_medicamento,
    regime_preco: item.regime_preco,
    fabricante_id: mapaFabricantes.get(item.fabricante_chave),
    lote_importacao: item.lote_importacao,
    dados_origem: item.dados_origem,
  }));

  await inserirMedicamentosBase(
    cliente,
    schema,
    medicamentosParaInsercao,
    argumentos.tamanhoLote,
  );
  const mapaMedicamentos = await carregarMapaIds(
    cliente,
    schema,
    'medicamentos_base',
    'registro',
    colecoes.medicamentos.map((item) => item.registro),
  );

  console.info('[Importador] Atualizando relacoes com principios ativos...');
  const idsMedicamentosImportados = Array.from(mapaMedicamentos.values());
  if (idsMedicamentosImportados.length) {
    await cliente.query(
      `delete from ${schema}.medicamentos_principios_ativos where medicamento_id = any($1::bigint[])`,
      [idsMedicamentosImportados],
    );
  }

  const relacoesParaInsercao = colecoes.relacoesPrincipios
    .map((item) => ({
      medicamento_id: mapaMedicamentos.get(item.registro),
      principio_ativo_id: mapaPrincipios.get(item.principio_normalizado),
      ordem: item.ordem,
      principal: item.principal,
    }))
    .filter((item) => item.medicamento_id && item.principio_ativo_id);

  await inserirRelacoesPrincipios(
    cliente,
    schema,
    relacoesParaInsercao,
    argumentos.tamanhoLote,
  );

  console.info('[Importador] Gravando apresentacoes...');
  const apresentacoesParaInsercao = colecoes.apresentacoes.map((item) => ({
    medicamento_id: mapaMedicamentos.get(item.registro),
    codigo_ggrem: item.codigo_ggrem,
    apresentacao: item.apresentacao,
    apresentacao_normalizada: item.apresentacao_normalizada,
    concentracao_dosagem: item.concentracao_dosagem,
    unidade: item.unidade,
    ean_1: item.ean_1,
    ean_2: item.ean_2,
    ean_3: item.ean_3,
    ean_principal: item.ean_principal,
    pf_preco_padrao: item.pf_preco_padrao,
    pmc_preco_padrao: item.pmc_preco_padrao,
    aliquota_pf_padrao: item.aliquota_pf_padrao,
    aliquota_pmc_padrao: item.aliquota_pmc_padrao,
    precos_pf: item.precos_pf,
    precos_pmc: item.precos_pmc,
    restricao_hospitalar: item.restricao_hospitalar,
    cap: item.cap,
    confaz_87: item.confaz_87,
    icms_0: item.icms_0,
    analise_recursal: item.analise_recursal,
    credito_tributario_piscofins: item.credito_tributario_piscofins,
    comercializacao_2024: item.comercializacao_2024,
    tarja: item.tarja,
    destinacao_comercial: item.destinacao_comercial,
    lote_importacao: item.lote_importacao,
    dados_origem: item.dados_origem,
  }));

  await inserirApresentacoes(
    cliente,
    schema,
    apresentacoesParaInsercao,
    argumentos.tamanhoLote,
  );

  if (argumentos.modo === 'substituir') {
    console.info('[Importador] Removendo registros ausentes na nova carga...');
    await removerAusentes(cliente, schema, colecoes.loteImportacao);
  }
}

async function inserirFabricantes(cliente, schema, registros, tamanhoLote) {
  if (!registros.length) {
    return;
  }

  const sql = `
    insert into ${schema}.fabricantes (
      chave_importacao,
      cnpj,
      nome,
      nome_normalizado,
      lote_importacao
    )
    select
      x.chave_importacao,
      x.cnpj,
      x.nome,
      x.nome_normalizado,
      x.lote_importacao
    from jsonb_to_recordset($1::jsonb) as x(
      chave_importacao text,
      cnpj text,
      nome text,
      nome_normalizado text,
      lote_importacao text
    )
    on conflict (chave_importacao)
    do update set
      cnpj = excluded.cnpj,
      nome = excluded.nome,
      nome_normalizado = excluded.nome_normalizado,
      lote_importacao = excluded.lote_importacao,
      atualizado_em = timezone('utc', now())
  `;

  await executarEmLotes(cliente, sql, registros, tamanhoLote);
}

async function inserirPrincipiosAtivos(cliente, schema, registros, tamanhoLote) {
  if (!registros.length) {
    return;
  }

  const sql = `
    insert into ${schema}.principios_ativos (
      nome,
      nome_normalizado,
      lote_importacao
    )
    select
      x.nome,
      x.nome_normalizado,
      x.lote_importacao
    from jsonb_to_recordset($1::jsonb) as x(
      nome text,
      nome_normalizado text,
      lote_importacao text
    )
    on conflict (nome_normalizado)
    do update set
      nome = excluded.nome,
      lote_importacao = excluded.lote_importacao,
      atualizado_em = timezone('utc', now())
  `;

  await executarEmLotes(cliente, sql, registros, tamanhoLote);
}

async function inserirMedicamentosBase(cliente, schema, registros, tamanhoLote) {
  if (!registros.length) {
    return;
  }

  const sql = `
    insert into ${schema}.medicamentos_base (
      registro,
      nome_produto,
      nome_produto_normalizado,
      substancia,
      substancia_normalizada,
      classe_terapeutica,
      tipo_produto,
      tipo_medicamento,
      regime_preco,
      fabricante_id,
      lote_importacao,
      dados_origem
    )
    select
      x.registro,
      x.nome_produto,
      x.nome_produto_normalizado,
      x.substancia,
      x.substancia_normalizada,
      x.classe_terapeutica,
      x.tipo_produto,
      x.tipo_medicamento,
      x.regime_preco,
      x.fabricante_id,
      x.lote_importacao,
      x.dados_origem
    from jsonb_to_recordset($1::jsonb) as x(
      registro text,
      nome_produto text,
      nome_produto_normalizado text,
      substancia text,
      substancia_normalizada text,
      classe_terapeutica text,
      tipo_produto text,
      tipo_medicamento text,
      regime_preco text,
      fabricante_id bigint,
      lote_importacao text,
      dados_origem jsonb
    )
    on conflict (registro)
    do update set
      nome_produto = excluded.nome_produto,
      nome_produto_normalizado = excluded.nome_produto_normalizado,
      substancia = excluded.substancia,
      substancia_normalizada = excluded.substancia_normalizada,
      classe_terapeutica = excluded.classe_terapeutica,
      tipo_produto = excluded.tipo_produto,
      tipo_medicamento = excluded.tipo_medicamento,
      regime_preco = excluded.regime_preco,
      fabricante_id = excluded.fabricante_id,
      lote_importacao = excluded.lote_importacao,
      dados_origem = excluded.dados_origem,
      atualizado_em = timezone('utc', now())
  `;

  await executarEmLotes(cliente, sql, registros, tamanhoLote);
}

async function inserirRelacoesPrincipios(cliente, schema, registros, tamanhoLote) {
  if (!registros.length) {
    return;
  }

  const sql = `
    insert into ${schema}.medicamentos_principios_ativos (
      medicamento_id,
      principio_ativo_id,
      ordem,
      principal
    )
    select
      x.medicamento_id,
      x.principio_ativo_id,
      x.ordem,
      x.principal
    from jsonb_to_recordset($1::jsonb) as x(
      medicamento_id bigint,
      principio_ativo_id bigint,
      ordem smallint,
      principal boolean
    )
    on conflict (medicamento_id, principio_ativo_id)
    do update set
      ordem = excluded.ordem,
      principal = excluded.principal
  `;

  await executarEmLotes(cliente, sql, registros, tamanhoLote);
}

async function inserirApresentacoes(cliente, schema, registros, tamanhoLote) {
  if (!registros.length) {
    return;
  }

  const sql = `
    insert into ${schema}.apresentacoes (
      medicamento_id,
      codigo_ggrem,
      apresentacao,
      apresentacao_normalizada,
      concentracao_dosagem,
      unidade,
      ean_1,
      ean_2,
      ean_3,
      ean_principal,
      pf_preco_padrao,
      pmc_preco_padrao,
      aliquota_pf_padrao,
      aliquota_pmc_padrao,
      precos_pf,
      precos_pmc,
      restricao_hospitalar,
      cap,
      confaz_87,
      icms_0,
      analise_recursal,
      credito_tributario_piscofins,
      comercializacao_2024,
      tarja,
      destinacao_comercial,
      lote_importacao,
      dados_origem
    )
    select
      x.medicamento_id,
      x.codigo_ggrem,
      x.apresentacao,
      x.apresentacao_normalizada,
      x.concentracao_dosagem,
      x.unidade,
      x.ean_1,
      x.ean_2,
      x.ean_3,
      x.ean_principal,
      x.pf_preco_padrao,
      x.pmc_preco_padrao,
      x.aliquota_pf_padrao,
      x.aliquota_pmc_padrao,
      x.precos_pf,
      x.precos_pmc,
      x.restricao_hospitalar,
      x.cap,
      x.confaz_87,
      x.icms_0,
      x.analise_recursal,
      x.credito_tributario_piscofins,
      x.comercializacao_2024,
      x.tarja,
      x.destinacao_comercial,
      x.lote_importacao,
      x.dados_origem
    from jsonb_to_recordset($1::jsonb) as x(
      medicamento_id bigint,
      codigo_ggrem text,
      apresentacao text,
      apresentacao_normalizada text,
      concentracao_dosagem text,
      unidade text,
      ean_1 text,
      ean_2 text,
      ean_3 text,
      ean_principal text,
      pf_preco_padrao numeric,
      pmc_preco_padrao numeric,
      aliquota_pf_padrao text,
      aliquota_pmc_padrao text,
      precos_pf jsonb,
      precos_pmc jsonb,
      restricao_hospitalar boolean,
      cap boolean,
      confaz_87 boolean,
      icms_0 boolean,
      analise_recursal text,
      credito_tributario_piscofins text,
      comercializacao_2024 boolean,
      tarja text,
      destinacao_comercial text,
      lote_importacao text,
      dados_origem jsonb
    )
    on conflict (codigo_ggrem)
    do update set
      medicamento_id = excluded.medicamento_id,
      apresentacao = excluded.apresentacao,
      apresentacao_normalizada = excluded.apresentacao_normalizada,
      concentracao_dosagem = excluded.concentracao_dosagem,
      unidade = excluded.unidade,
      ean_1 = excluded.ean_1,
      ean_2 = excluded.ean_2,
      ean_3 = excluded.ean_3,
      ean_principal = excluded.ean_principal,
      pf_preco_padrao = excluded.pf_preco_padrao,
      pmc_preco_padrao = excluded.pmc_preco_padrao,
      aliquota_pf_padrao = excluded.aliquota_pf_padrao,
      aliquota_pmc_padrao = excluded.aliquota_pmc_padrao,
      precos_pf = excluded.precos_pf,
      precos_pmc = excluded.precos_pmc,
      restricao_hospitalar = excluded.restricao_hospitalar,
      cap = excluded.cap,
      confaz_87 = excluded.confaz_87,
      icms_0 = excluded.icms_0,
      analise_recursal = excluded.analise_recursal,
      credito_tributario_piscofins = excluded.credito_tributario_piscofins,
      comercializacao_2024 = excluded.comercializacao_2024,
      tarja = excluded.tarja,
      destinacao_comercial = excluded.destinacao_comercial,
      lote_importacao = excluded.lote_importacao,
      dados_origem = excluded.dados_origem,
      atualizado_em = timezone('utc', now())
  `;

  await executarEmLotes(cliente, sql, registros, tamanhoLote);
}

async function carregarMapaIds(cliente, schema, tabela, colunaChave, chaves) {
  if (!chaves.length) {
    return new Map();
  }

  const resultado = await cliente.query(
    `select id, ${colunaChave} as chave from ${schema}.${tabela} where ${colunaChave} = any($1::text[])`,
    [chaves],
  );

  return new Map(resultado.rows.map((item) => [item.chave, Number(item.id)]));
}

async function executarEmLotes(cliente, sql, registros, tamanhoLote) {
  for (let inicio = 0; inicio < registros.length; inicio += tamanhoLote) {
    const lote = registros.slice(inicio, inicio + tamanhoLote);
    await cliente.query(sql, [JSON.stringify(lote)]);
  }
}

async function removerAusentes(cliente, schema, loteImportacao) {
  await cliente.query(
    `delete from ${schema}.apresentacoes where lote_importacao <> $1`,
    [loteImportacao],
  );
  await cliente.query(
    `delete from ${schema}.medicamentos_base where lote_importacao <> $1`,
    [loteImportacao],
  );
  await cliente.query(
    `
      delete from ${schema}.principios_ativos pa
      where pa.lote_importacao <> $1
        and not exists (
          select 1
          from ${schema}.medicamentos_principios_ativos rel
          where rel.principio_ativo_id = pa.id
        )
    `,
    [loteImportacao],
  );
  await cliente.query(
    `
      delete from ${schema}.fabricantes f
      where f.lote_importacao <> $1
        and not exists (
          select 1
          from ${schema}.medicamentos_base m
          where m.fabricante_id = f.id
        )
    `,
    [loteImportacao],
  );
}

function imprimirResumoValidacao(planilha, colecoes) {
  console.info('[Importador] Execucao em modo somente-validar.');
  console.info(
    '[Importador] Mapeamento provavel das colunas fixas: ' +
      JSON.stringify(planilha.colunasFixas, null, 2),
  );
  console.info(
    '[Importador] Mapeamento provavel das colunas PF/PMC: ' +
      JSON.stringify(planilha.colunasPrecos, null, 2),
  );
  console.info(
    '[Importador] Exemplo de tres apresentacoes normalizadas: ' +
      JSON.stringify(colecoes.apresentacoes.slice(0, 3), null, 2),
  );
}

main().catch((erro) => {
  console.error('[Importador] Falha na importacao:', erro.message);
  process.exit(1);
});
