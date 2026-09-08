import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lembrebem/backend/catalogo_api.dart';
import 'package:lembrebem/modelo_alarme.dart';
import 'package:lembrebem/menu_rodape.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/widgets/componentes.dart';

class TelaConfigAlarme extends StatefulWidget {
  final Alarme? alarme;
  final String? medicamentoInicial;
  final int? medicamentoIdInicial;

  const TelaConfigAlarme({
    super.key,
    this.alarme,
    this.medicamentoInicial,
    this.medicamentoIdInicial,
  });

  @override
  State<TelaConfigAlarme> createState() => _TelaConfigAlarmeState();
}

class _TelaConfigAlarmeState extends State<TelaConfigAlarme> {
  String? _selectedInterval;
  String? _selectedUso;
  TimeOfDay _selectedTime = TimeOfDay.now();
  final TextEditingController _medicamentoController = TextEditingController();
  final TextEditingController _observacoesController = TextEditingController();
  final CatalogoApi _catalogoApi = CatalogoApi();
  final FocusNode _medicamentoFocusNode = FocusNode();
  final List<Map<String, dynamic>> _sugestoesMedicamentos = [];
  Timer? _debounceBusca;
  int? _medicamentoIdSelecionado;
  String? _usuarioMedicamentoIdSelecionado;
  String _termoSugestao = '';
  bool _buscandoSugestoes = false;
  String? _erroSugestao;

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: Color(0xFF55C2C3)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  static const List<String> _opcoesIntervalo = [
    '8 em 8h',
    '6 em 6h',
    '12 em 12h',
    '24 em 24h',
  ];
  static const List<String> _opcoesDiasUso = [
    'Uso contínuo',
    'Seg. e Qua.',
    'Seg., Qua. e Sex.',
    'Todo dia',
    '3 dias',
    '7 dias',
  ];

  List<String> get _intervalosDisponiveis {
    final atual = widget.alarme?.intervalo;
    if (atual != null &&
        atual.isNotEmpty &&
        !_opcoesIntervalo.contains(atual)) {
      return [atual, ..._opcoesIntervalo];
    }
    return _opcoesIntervalo;
  }

  List<String> get _diasUsoDisponiveis {
    final atual = widget.alarme?.diasDeUso;
    if (atual != null && atual.isNotEmpty && !_opcoesDiasUso.contains(atual)) {
      return [atual, ..._opcoesDiasUso];
    }
    return _opcoesDiasUso;
  }

  @override
  void initState() {
    super.initState();
    if (widget.alarme != null) {
      _medicamentoController.text = widget.alarme!.nome;
      _observacoesController.text = widget.alarme!.observacoes;
      _selectedTime = widget.alarme!.horario;
      _medicamentoIdSelecionado = widget.alarme!.medicamentoId;
      _usuarioMedicamentoIdSelecionado = widget.alarme!.usuarioMedicamentoId;

      final intervaloAtual = widget.alarme!.intervalo;
      _selectedInterval = intervaloAtual.isNotEmpty ? intervaloAtual : null;

      final diasAtual = widget.alarme!.diasDeUso;
      _selectedUso = diasAtual.isNotEmpty ? diasAtual : null;
    } else if (widget.medicamentoInicial != null &&
        widget.medicamentoInicial!.isNotEmpty) {
      _medicamentoController.text = widget.medicamentoInicial!;
      _medicamentoIdSelecionado = widget.medicamentoIdInicial;
    }
  }

  void _ajustarHora(int delta) {
    setState(() {
      final hora = (_selectedTime.hour + delta) % 24;
      _selectedTime = TimeOfDay(
        hour: hora < 0 ? hora + 24 : hora,
        minute: _selectedTime.minute,
      );
    });
  }

  void _ajustarMinuto(int delta) {
    setState(() {
      final minuto = (_selectedTime.minute + delta) % 60;
      _selectedTime = TimeOfDay(
        hour: _selectedTime.hour,
        minute: minuto < 0 ? minuto + 60 : minuto,
      );
    });
  }

  @override
  void dispose() {
    _debounceBusca?.cancel();
    _medicamentoController.dispose();
    _observacoesController.dispose();
    _medicamentoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _buscarSugestoesMedicamento(String termo) async {
    final termoLimpo = termo.trim();
    if (termoLimpo.isEmpty || termoLimpo.length < 2) {
      if (mounted) {
        setState(() {
          _sugestoesMedicamentos.clear();
          _erroSugestao = null;
          _buscandoSugestoes = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _buscandoSugestoes = true;
        _erroSugestao = null;
      });
    }

    try {
      final resultados = await _catalogoApi.buscarMedicamentosPorTermo(
        termoLimpo,
        limite: 8,
      );

      if (!mounted || _termoSugestao.trim() != termoLimpo) {
        return;
      }

      setState(() {
        _sugestoesMedicamentos
          ..clear()
          ..addAll(resultados);
        _buscandoSugestoes = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _erroSugestao = _mensagemErroBusca(e);
        _buscandoSugestoes = false;
      });
    }
  }

  void _onChangeMedicamento(String value) {
    _debounceBusca?.cancel();
    _medicamentoIdSelecionado = null;
    _usuarioMedicamentoIdSelecionado = null;
    _termoSugestao = value;
    _debounceBusca = Timer(
      const Duration(milliseconds: 250),
      () => _buscarSugestoesMedicamento(value),
    );
  }

  void _selecionarSugestao(Map<String, dynamic> sugestao) {
    final id = sugestao['id'];
    final medicamentoId =
        id is int
            ? id
            : id is num
            ? id.toInt()
            : int.tryParse(id?.toString() ?? '');

    setState(() {
      _medicamentoController.text = sugestao['nome_produto']?.toString() ?? '';
      _medicamentoIdSelecionado = medicamentoId;
      _sugestoesMedicamentos.clear();
    });
    _medicamentoFocusNode.unfocus();
  }

  String _campoTexto(dynamic valor) {
    if (valor == null) {
      return '';
    }
    return valor.toString().trim();
  }

  String _extrairFabricanteCatalogo(Map<String, dynamic> item) {
    final fabricante = _campoTexto(item['fabricante']);
    if (fabricante.isNotEmpty) {
      return fabricante;
    }
    return _campoTexto(item['empresa_detentora_registro']);
  }

  String _extrairTipoCatalogo(Map<String, dynamic> item) {
    final tipo = _campoTexto(item['tipo_medicamento']).toLowerCase();
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

    final tipoProduto = _campoTexto(item['tipo_produto']);
    if (tipoProduto.isNotEmpty) {
      return tipoProduto;
    }

    return _campoTexto(item['categoria_regulatoria']);
  }

  String _extrairTarjaCatalogo(Map<String, dynamic> item) {
    final tarja = _campoTexto(item['tarja']);
    if (tarja.isEmpty || tarja == '- (*)' || tarja == '-') {
      return '';
    }
    return tarja;
  }

  String _extrairPrecoCatalogo(Map<String, dynamic> item) {
    final preco = _extrairNumero(item['preco']);
    if (preco == null || preco <= 0) {
      return '';
    }
    return 'PMC R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  double? _extrairNumero(dynamic valor) {
    if (valor is num) {
      return valor.toDouble();
    }

    final texto = _campoTexto(valor);
    if (texto.isEmpty) {
      return null;
    }

    final normalizado =
        texto.contains(',') && texto.contains('.')
            ? texto.replaceAll('.', '').replaceAll(',', '.')
            : texto.replaceAll(',', '.');

    return double.tryParse(normalizado);
  }

  Widget _chipCatalogo(
    String texto, {
    required Color corFundo,
    required Color corTexto,
  }) {
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
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _salvarAlarme() {
    Navigator.pop(
      context,
      Alarme(
        id: widget.alarme?.id ?? '',
        nome: _medicamentoController.text,
        observacoes: _observacoesController.text,
        horario: _selectedTime,
        diasDeUso: _selectedUso ?? '',
        ativado: true,
        intervalo: _selectedInterval ?? '',
        medicamentoId: _medicamentoIdSelecionado,
        usuarioMedicamentoId: _usuarioMedicamentoIdSelecionado,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corFundo,
      appBar: AppBar(
        backgroundColor: corFundo,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: corPrimariaEscura),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.alarme != null ? 'Editar alarme' : 'Adicionar alarme',
          style: const TextStyle(
            color: corPrimariaEscura,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Center(
              child: Text(
                'Horário da medicação',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: corPrimariaEscura,
                ),
              ),
            ),
            SizedBox(height: 12),
            Container(
              decoration: cardDecoracao(radius: 16),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ColunaSpinner(
                    valor: _selectedTime.hour.toString().padLeft(2, '0'),
                    aoSubir: () => _ajustarHora(1),
                    aoDescer: () => _ajustarHora(-1),
                    aoTocarValor: () => _selectTime(context),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w300,
                        color: Color(0xFF9AA5A8),
                      ),
                    ),
                  ),
                  _ColunaSpinner(
                    valor: _selectedTime.minute.toString().padLeft(2, '0'),
                    aoSubir: () => _ajustarMinuto(1),
                    aoDescer: () => _ajustarMinuto(-1),
                    aoTocarValor: () => _selectTime(context),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            Text(
              'Nome do Medicamento',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: corPrimariaEscura,
              ),
            ),
            SizedBox(height: 8),
            Column(
              children: [
                TextField(
                  controller: _medicamentoController,
                  focusNode: _medicamentoFocusNode,
                  onChanged: _onChangeMedicamento,
                  decoration: InputDecoration(
                    hintText: 'Digite o nome do medicamento...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                if (_buscandoSugestoes) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (_termoSugestao.trim().length == 1 &&
                    !_buscandoSugestoes &&
                    _sugestoesMedicamentos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Digite pelo menos 2 letras.',
                        style: TextStyle(
                          color: Color(0xFF6A6A6A),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                if (_erroSugestao != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _erroSugestao!,
                      style: const TextStyle(
                        color: Color(0xFFC0392B),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                if (_sugestoesMedicamentos.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _sugestoesMedicamentos.length,
                      separatorBuilder:
                          (_, __) =>
                              Divider(height: 1, color: Colors.grey[300]),
                      itemBuilder: (context, index) {
                        final item = _sugestoesMedicamentos[index];
                        final nome = item['nome_produto']?.toString() ?? '';
                        final principio =
                            item['principio_ativo']?.toString() ?? '';
                        final dosagem =
                            item['concentracao_dosagem']?.toString() ?? '';
                        final fabricante = _extrairFabricanteCatalogo(item);
                        final tipo = _extrairTipoCatalogo(item);
                        final tarja = _extrairTarjaCatalogo(item);
                        final preco = _extrairPrecoCatalogo(item);
                        final registro =
                            item['numero_registro']?.toString() ??
                            item['registro']?.toString() ??
                            '';

                        return InkWell(
                          onTap: () => _selecionarSugestao(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nome,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (dosagem.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    dosagem,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                                if (principio.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    principio,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                                if (fabricante.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    fabricante,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                                if (tipo.isNotEmpty ||
                                    tarja.isNotEmpty ||
                                    preco.isNotEmpty ||
                                    registro.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      if (tipo.isNotEmpty)
                                        _chipCatalogo(
                                          tipo,
                                          corFundo: const Color(0xFFE8F6EF),
                                          corTexto: const Color(0xFF24704A),
                                        ),
                                      if (tarja.isNotEmpty)
                                        _chipCatalogo(
                                          tarja,
                                          corFundo: const Color(0xFFFFF1E6),
                                          corTexto: const Color(0xFFB8641D),
                                        ),
                                      if (preco.isNotEmpty)
                                        _chipCatalogo(
                                          preco,
                                          corFundo: const Color(0xFFEAF7F8),
                                          corTexto: const Color(0xFF2D7E84),
                                        ),
                                      if (registro.isNotEmpty)
                                        _chipCatalogo(
                                          'Registro: $registro',
                                          corFundo: const Color(0xFFF1F4F6),
                                          corTexto: const Color(0xFF4E5B63),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (!_buscandoSugestoes &&
                    _erroSugestao == null &&
                    _termoSugestao.trim().length >= 2 &&
                    _sugestoesMedicamentos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Medicamento nao encontrado.',
                        style: TextStyle(
                          color: Color(0xFF6A6A6A),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(height: 20),

            Text(
              'Intervalos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: corPrimariaEscura,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14),
              decoration: cardDecoracao(radius: 14),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedInterval ?? '8 em 8h',
                decoration: InputDecoration(border: InputBorder.none),
                isExpanded: true,
                items:
                    _intervalosDisponiveis.map((value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged:
                    (newValue) => setState(() => _selectedInterval = newValue),
              ),
            ),

            SizedBox(height: 20),

            Text(
              'Dias de uso',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: corPrimariaEscura,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14),
              decoration: cardDecoracao(radius: 14),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedUso ?? 'Uso contínuo',
                decoration: InputDecoration(border: InputBorder.none),
                isExpanded: true,
                items:
                    _diasUsoDisponiveis.map((value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged:
                    (newValue) => setState(() => _selectedUso = newValue),
              ),
            ),

            SizedBox(height: 20),

            Text(
              'Observações',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: corPrimariaEscura,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14),
              decoration: cardDecoracao(radius: 14),
              child: TextField(
                controller: _observacoesController,
                decoration: InputDecoration(
                  hintText:
                      'Digite orientações importantes para o uso correto do medicamento...',
                  border: InputBorder.none,
                ),
                maxLines: 4,
              ),
            ),

            SizedBox(height: 24),

            BotaoPrimario(
              texto:
                  widget.alarme != null ? 'Salvar alterações' : 'Salvar alarme',
              onPressed: _salvarAlarme,
            ),
          ],
        ),
      ),

      bottomNavigationBar: const BarraNavegacaoApp(ativa: AbaApp.alarme),
    );
  }

  String _mensagemErroBusca(Object erro) {
    final texto = erro.toString().toLowerCase();
    if (texto.contains('failed host lookup') ||
        texto.contains('xmlhttprequest') ||
        texto.contains('socketexception') ||
        texto.contains('network')) {
      return 'Sem acesso ao catalogo no Supabase agora. Verifique sua conexao e tente novamente.';
    }
    return 'Falha ao buscar medicamento.';
  }
}

class _ColunaSpinner extends StatelessWidget {
  const _ColunaSpinner({
    required this.valor,
    required this.aoSubir,
    required this.aoDescer,
    required this.aoTocarValor,
  });

  final String valor;
  final VoidCallback aoSubir;
  final VoidCallback aoDescer;
  final VoidCallback aoTocarValor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: aoSubir,
          icon: const Icon(
            Icons.keyboard_arrow_up,
            size: 30,
            color: corTextoCinzaClaro,
          ),
        ),
        GestureDetector(
          onTap: aoTocarValor,
          child: Text(
            valor,
            style: const TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w300,
              color: corPrimariaEscura,
            ),
          ),
        ),
        IconButton(
          onPressed: aoDescer,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 30,
            color: corTextoCinzaClaro,
          ),
        ),
      ],
    );
  }
}
