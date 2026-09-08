import 'package:flutter/material.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';

class MedicamentoDetalhesSheet {
  static Future<void> mostrar(
    BuildContext context, {
    required Map<String, dynamic> medicamento,
    String? tituloAlternativo,
    String? subtitulo,
    String? mensagemAuxiliar,
    List<Widget> acoesExtras = const [],
  }) {
    final titulo =
        _texto(tituloAlternativo).isNotEmpty
            ? _texto(tituloAlternativo)
            : _texto(medicamento['nome_produto']).isNotEmpty
            ? _texto(medicamento['nome_produto'])
            : 'Medicamento';

    final nomeCatalogo = _texto(medicamento['nome_produto']);
    final principioAtivo = _texto(medicamento['principio_ativo']);
    final principiosAtivos = _listaPrincipiosAtivos(medicamento);
    final fabricante = _extrairFabricante(medicamento);
    final empresa = _texto(medicamento['empresa_detentora_registro']);
    final dosagem = _extrairDosagem(medicamento);
    final classe = _texto(medicamento['classe_terapeutica']);
    final tipo = _extrairTipoMedicamento(medicamento);
    final tipoProduto = _texto(medicamento['tipo_produto']);
    final apresentacao = _texto(medicamento['apresentacao']);
    final registro =
        _texto(medicamento['numero_registro']).isNotEmpty
            ? _texto(medicamento['numero_registro'])
            : _texto(medicamento['registro']);
    final ggrem = _texto(medicamento['codigo_ggrem']);
    final ean =
        _texto(medicamento['ean']).isNotEmpty
            ? _texto(medicamento['ean'])
            : _texto(medicamento['ean_1']);
    final unidade = _texto(medicamento['unidade']);
    final pmc = _formatarPreco(
      _extrairNumero(medicamento['pmc']) ??
          _extrairNumero(medicamento['preco']),
      prefixo: 'PMC',
    );
    final pf = _formatarPreco(_extrairNumero(medicamento['pf']), prefixo: 'PF');
    final tarja = _extrairTarja(medicamento);
    final situacao = _texto(medicamento['situacao_registro']);
    final regimePreco = _texto(medicamento['regime_preco']);
    final cnpjFabricante = _texto(medicamento['cnpj_fabricante']);
    final creditoTributario = _texto(
      medicamento['credito_tributario_piscofins'],
    );
    final destinacaoComercial = _texto(medicamento['destinacao_comercial']);
    final comercializacao2024 = _formatarBooleano(
      medicamento['comercializacao_2024'],
    );
    final restricaoHospitalar = _formatarBooleano(
      medicamento['restricao_hospitalar'],
    );
    final cap = _formatarBooleano(medicamento['cap']);
    final confaz87 = _formatarBooleano(medicamento['confaz_87']);
    final icmsZero = _formatarBooleano(medicamento['icms_0']);
    final analiseRecursal = _texto(medicamento['analise_recursal']);
    final aliquotaPmc = _texto(medicamento['aliquota_pmc_padrao']);
    final aliquotaPf = _texto(medicamento['aliquota_pf_padrao']);
    final apelido = _texto(medicamento['apelido']);
    final medicamentoId = _texto(medicamento['medicamento_id']);

    final resumo = <_CampoDetalhe>[
      if (principioAtivo.isNotEmpty)
        _CampoDetalhe('Principio ativo', principioAtivo),
      if (fabricante.isNotEmpty) _CampoDetalhe('Fabricante', fabricante),
      if (dosagem.isNotEmpty) _CampoDetalhe('Concentracao', dosagem),
      if (classe.isNotEmpty) _CampoDetalhe('Classe terapeutica', classe),
    ];

    final dadosIdentificacao = <_CampoDetalhe>[
      if (apelido.isNotEmpty) _CampoDetalhe('Apelido salvo', apelido),
      if (nomeCatalogo.isNotEmpty &&
          nomeCatalogo.toLowerCase() != titulo.toLowerCase())
        _CampoDetalhe('Nome no catalogo', nomeCatalogo),
      if (principiosAtivos.isNotEmpty &&
          principiosAtivos.toLowerCase() != principioAtivo.toLowerCase())
        _CampoDetalhe('Principios ativos', principiosAtivos),
      if (apresentacao.isNotEmpty) _CampoDetalhe('Apresentacao', apresentacao),
      if (unidade.isNotEmpty) _CampoDetalhe('Unidade', unidade),
      if (registro.isNotEmpty) _CampoDetalhe('Registro', registro),
      if (ggrem.isNotEmpty) _CampoDetalhe('Codigo GGREM', ggrem),
      if (medicamentoId.isNotEmpty)
        _CampoDetalhe('Medicamento ID', medicamentoId),
      if (ean.isNotEmpty) _CampoDetalhe('EAN', ean),
    ];

    final dadosComerciais = <_CampoDetalhe>[
      if (pmc.isNotEmpty) _CampoDetalhe('Preco maximo ao consumidor', pmc),
      if (pf.isNotEmpty) _CampoDetalhe('Preco fabrica', pf),
      if (regimePreco.isNotEmpty) _CampoDetalhe('Regime de preco', regimePreco),
      if (aliquotaPmc.isNotEmpty)
        _CampoDetalhe('Aliquota PMC padrao', '$aliquotaPmc%'),
      if (aliquotaPf.isNotEmpty)
        _CampoDetalhe('Aliquota PF padrao', '$aliquotaPf%'),
      if (creditoTributario.isNotEmpty)
        _CampoDetalhe('Credito tributario PIS/COFINS', creditoTributario),
      if (comercializacao2024.isNotEmpty)
        _CampoDetalhe('Comercializacao em 2024', comercializacao2024),
      if (destinacaoComercial.isNotEmpty)
        _CampoDetalhe('Destinacao comercial', destinacaoComercial),
    ];

    final dadosRegulatorios = <_CampoDetalhe>[
      if (tipo.isNotEmpty) _CampoDetalhe('Tipo de medicamento', tipo),
      if (tipoProduto.isNotEmpty &&
          tipoProduto.toLowerCase() != tipo.toLowerCase())
        _CampoDetalhe('Tipo de produto', tipoProduto),
      if (tarja.isNotEmpty) _CampoDetalhe('Tarja', tarja),
      if (situacao.isNotEmpty) _CampoDetalhe('Situacao do registro', situacao),
      if (empresa.isNotEmpty &&
          empresa.toLowerCase() != fabricante.toLowerCase())
        _CampoDetalhe('Empresa detentora do registro', empresa),
      if (cnpjFabricante.isNotEmpty)
        _CampoDetalhe('CNPJ do fabricante', cnpjFabricante),
      if (restricaoHospitalar.isNotEmpty)
        _CampoDetalhe('Restricao hospitalar', restricaoHospitalar),
      if (cap.isNotEmpty) _CampoDetalhe('CAP', cap),
      if (confaz87.isNotEmpty) _CampoDetalhe('CONFAZ 87', confaz87),
      if (icmsZero.isNotEmpty) _CampoDetalhe('ICMS 0', icmsZero),
      if (analiseRecursal.isNotEmpty)
        _CampoDetalhe('Analise recursal', analiseRecursal),
    ];

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.48,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FBFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 54,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB9C8CC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            color: corTextoEscuro,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        if (_texto(subtitulo).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _texto(subtitulo),
                            style: const TextStyle(
                              color: Color(0xFF5E6A6E),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (tipo.isNotEmpty)
                              const _ChipInfo(
                                texto: '',
                                corFundo: Color(0xFFE8F6EF),
                                corTexto: Color(0xFF24704A),
                              ).copyWith(texto: 'Tipo: $tipo'),
                            if (tarja.isNotEmpty)
                              const _ChipInfo(
                                texto: '',
                                corFundo: Color(0xFFFFF1E6),
                                corTexto: Color(0xFFB8641D),
                              ).copyWith(texto: tarja),
                            if (pmc.isNotEmpty)
                              const _ChipInfo(
                                texto: '',
                                corFundo: Color(0xFFEAF7F8),
                                corTexto: Color(0xFF2D7E84),
                              ).copyWith(texto: pmc),
                            if (registro.isNotEmpty)
                              const _ChipInfo(
                                texto: '',
                                corFundo: Color(0xFFF1F4F6),
                                corTexto: Color(0xFF4E5B63),
                              ).copyWith(texto: 'Registro: $registro'),
                            if (situacao.isNotEmpty)
                              _ChipInfo(
                                texto: situacao,
                                corFundo:
                                    situacao.toLowerCase() == 'ativo'
                                        ? const Color(0xFFE5F7EA)
                                        : const Color(0xFFFCEAEA),
                                corTexto:
                                    situacao.toLowerCase() == 'ativo'
                                        ? const Color(0xFF1B8F45)
                                        : const Color(0xFFC0392B),
                              ),
                          ],
                        ),
                        if (resumo.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _SecaoDetalhes(
                            titulo: 'Resumo',
                            children:
                                resumo
                                    .map((item) => _BlocoResumo(item: item))
                                    .toList(),
                          ),
                        ],
                        if (_texto(mensagemAuxiliar).isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFF2D59B),
                              ),
                            ),
                            child: Text(
                              _texto(mensagemAuxiliar),
                              style: const TextStyle(
                                color: Color(0xFF85641B),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                        if (dadosIdentificacao.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _SecaoDetalhes(
                            titulo: 'Identificacao',
                            children:
                                dadosIdentificacao
                                    .map((item) => _LinhaDetalhe(item: item))
                                    .toList(),
                          ),
                        ],
                        if (dadosComerciais.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _SecaoDetalhes(
                            titulo: 'Dados comerciais',
                            children:
                                dadosComerciais
                                    .map((item) => _LinhaDetalhe(item: item))
                                    .toList(),
                          ),
                        ],
                        if (dadosRegulatorios.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _SecaoDetalhes(
                            titulo: 'Dados regulatorios',
                            children:
                                dadosRegulatorios
                                    .map((item) => _LinhaDetalhe(item: item))
                                    .toList(),
                          ),
                        ],
                        if (acoesExtras.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          ...acoesExtras,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static String _texto(dynamic valor) {
    if (valor == null) {
      return '';
    }
    return valor.toString().trim();
  }

  static String _listaPrincipiosAtivos(Map<String, dynamic> medicamento) {
    final lista = medicamento['principios_ativos'];
    if (lista is List) {
      final itens =
          lista
              .map((item) => _texto(item))
              .where((item) => item.isNotEmpty)
              .toList();
      return itens.join(', ');
    }

    final detalhados = medicamento['principios_ativos_detalhados'];
    if (detalhados is List) {
      final itens =
          detalhados
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return _texto(item['nome']);
                }
                if (item is Map) {
                  return _texto(item['nome']);
                }
                return _texto(item);
              })
              .where((item) => item.isNotEmpty)
              .toList();
      return itens.join(', ');
    }

    return '';
  }

  static String _extrairFabricante(Map<String, dynamic> medicamento) {
    final fabricante = _texto(medicamento['fabricante']);
    if (fabricante.isNotEmpty) {
      return fabricante;
    }
    return _texto(medicamento['empresa_detentora_registro']);
  }

  static String _extrairDosagem(Map<String, dynamic> medicamento) {
    final dosagem = _texto(medicamento['concentracao_dosagem']);
    if (dosagem.isNotEmpty) {
      return dosagem;
    }

    final fontes = [
      _texto(medicamento['nome_produto']),
      _texto(medicamento['principio_ativo']),
    ];

    final regex = RegExp(
      r'\b\d+(?:[\.,]\d+)?\s?(?:mg|g|mcg|ug|ml|ui|%)\b',
      caseSensitive: false,
    );

    for (final texto in fontes) {
      final match = regex.firstMatch(texto);
      if (match != null) {
        return match.group(0) ?? '';
      }
    }

    return '';
  }

  static String _extrairTipoMedicamento(Map<String, dynamic> medicamento) {
    final tipo = _texto(medicamento['tipo_medicamento']).toLowerCase();
    switch (tipo) {
      case 'generico':
        return 'Generico';
      case 'similar':
        return 'Similar';
      case 'referencia':
        return 'Referencia';
      case 'biologico':
        return 'Biologico';
    }

    final tipoProduto = _texto(medicamento['tipo_produto']);
    if (tipoProduto.isNotEmpty) {
      return tipoProduto;
    }

    return _texto(medicamento['categoria_regulatoria']);
  }

  static String _extrairTarja(Map<String, dynamic> medicamento) {
    final tarja = _texto(medicamento['tarja']);
    if (tarja.isEmpty || tarja == '- (*)' || tarja == '-') {
      return '';
    }
    return tarja;
  }

  static double? _extrairNumero(dynamic valor) {
    if (valor is num) {
      return valor.toDouble();
    }

    final texto = _texto(valor);
    if (texto.isEmpty) {
      return null;
    }

    final normalizado =
        texto.contains(',') && texto.contains('.')
            ? texto.replaceAll('.', '').replaceAll(',', '.')
            : texto.replaceAll(',', '.');

    return double.tryParse(normalizado);
  }

  static String _formatarPreco(double? valor, {required String prefixo}) {
    if (valor == null || valor <= 0) {
      return '';
    }

    return '$prefixo R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  static String _formatarBooleano(dynamic valor) {
    if (valor == true) {
      return 'Sim';
    }
    if (valor == false) {
      return 'Nao';
    }
    return '';
  }
}

class _SecaoDetalhes extends StatelessWidget {
  const _SecaoDetalhes({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: corTextoEscuro,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _BlocoResumo extends StatelessWidget {
  const _BlocoResumo({required this.item});

  final _CampoDetalhe item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.rotulo,
            style: const TextStyle(
              color: Color(0xFF5B6D72),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.valor,
            style: const TextStyle(
              color: corTextoEscuro,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaDetalhe extends StatelessWidget {
  const _LinhaDetalhe({required this.item});

  final _CampoDetalhe item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.rotulo,
            style: const TextStyle(
              color: Color(0xFF6A787C),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.valor,
            style: const TextStyle(
              color: corTextoEscuro,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipInfo extends StatelessWidget {
  const _ChipInfo({
    required this.texto,
    required this.corFundo,
    required this.corTexto,
  });

  final String texto;
  final Color corFundo;
  final Color corTexto;

  _ChipInfo copyWith({String? texto, Color? corFundo, Color? corTexto}) {
    return _ChipInfo(
      texto: texto ?? this.texto,
      corFundo: corFundo ?? this.corFundo,
      corTexto: corTexto ?? this.corTexto,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: corTexto,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CampoDetalhe {
  const _CampoDetalhe(this.rotulo, this.valor);

  final String rotulo;
  final String valor;
}
