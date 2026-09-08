import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lembrebem/backend/auth_api.dart';
import 'package:lembrebem/backend/cuidador_api.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/telas/tela_inicial.dart';
import 'package:lembrebem/widgets/skeleton_box.dart';
import 'package:lembrebem/widgets/componentes.dart';
import 'package:url_launcher/url_launcher.dart';

class TelaCuidadorPainel extends StatefulWidget {
  const TelaCuidadorPainel({super.key});

  @override
  State<TelaCuidadorPainel> createState() => _TelaCuidadorPainelState();
}

enum _AbaCuidador { pacientes, relatorios, perfil }

class _TelaCuidadorPainelState extends State<TelaCuidadorPainel> {
  final CuidadorApi _cuidadorApi = CuidadorApi();
  final AuthApi _authApi = AuthApi();

  _AbaCuidador _abaAtiva = _AbaCuidador.pacientes;

  bool _carregando = true;
  String? _erro;
  Map<String, dynamic>? _cuidador;
  List<Map<String, dynamic>> _pacientes = [];
  final Map<String, List<Map<String, dynamic>>> _dosesHoje = {};
  final Map<String, int> _adesaoPorPaciente = {};
  final Map<String, List<Map<String, dynamic>>> _adesaoSemanal = {};

  String _buscaPaciente = '';

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  Future<void> _carregarTudo() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final cuidador = await _cuidadorApi.buscarCuidadorAtual();
      final pacientes = await _cuidadorApi.listarPacientes();

      _dosesHoje.clear();
      _adesaoPorPaciente.clear();
      _adesaoSemanal.clear();

      for (final paciente in pacientes) {
        final id = paciente['id']?.toString() ?? '';
        if (id.isEmpty) {
          continue;
        }
        try {
          _dosesHoje[id] = await _cuidadorApi.listarDosesDeHoje(pacienteId: id);
        } catch (_) {
          _dosesHoje[id] = [];
        }
        try {
          final semana = await _cuidadorApi.adesaoSemanal(pacienteId: id);
          _adesaoSemanal[id] = semana;
          final taxas = semana.map((d) => d['taxa']).whereType<int>().toList();
          _adesaoPorPaciente[id] =
              taxas.isEmpty
                  ? 0
                  : (taxas.reduce((a, b) => a + b) / taxas.length).round();
        } catch (_) {
          _adesaoSemanal[id] = [];
          _adesaoPorPaciente[id] = 0;
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _cuidador = cuidador;
        _pacientes = pacientes;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _erro =
            e.toString().contains('cuidador')
                ? 'Recursos do cuidador indisponíveis. Rode o SQL '
                    '(sql/prototipo_novas_tabelas.sql) no Supabase.'
                : 'Falha ao carregar o painel.';
        _carregando = false;
      });
    }
  }

  Color _corStatus(String pacienteId) {
    final doses = _dosesHoje[pacienteId] ?? [];
    if (doses.any((d) => d['status'] == 'perdida')) {
      return corEmergencia;
    }
    if (doses.any((d) => d['status'] == 'pendente')) {
      return corAviso;
    }
    return corSucesso;
  }

  String _resumoStatus(String pacienteId) {
    final doses = _dosesHoje[pacienteId] ?? [];
    final perdidas = doses.where((d) => d['status'] == 'perdida').length;
    final pendentes = doses.where((d) => d['status'] == 'pendente').length;
    if (perdidas > 0) {
      return '$perdidas dose(s) não registrada(s) hoje';
    }
    if (pendentes > 0) {
      return '$pendentes dose(s) aguardando confirmação';
    }
    if (doses.isEmpty) {
      return 'Sem doses registradas hoje';
    }
    return 'Todas as doses de hoje em dia';
  }

  String _rotuloStatus(String pacienteId) {
    final cor = _corStatus(pacienteId);
    if (cor == corEmergencia) {
      return 'Medicação atrasada';
    }
    if (cor == corAviso) {
      return 'Aguarda confirmação';
    }
    return 'Tudo em dia';
  }

  String _iniciais(String nome) {
    final partes =
        nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) {
      return '?';
    }
    if (partes.length == 1) {
      return partes.first.substring(0, 1).toUpperCase();
    }
    return (partes.first.substring(0, 1) + partes.last.substring(0, 1))
        .toUpperCase();
  }

  Future<void> _abrirModalVincular() async {
    final codigoController = TextEditingController();
    final vinculado = await showDialog<bool>(
      context: context,
      builder:
          (contexto) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: corPrimaria.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.link, color: corPrimaria),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Adicionar Paciente',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(contexto, false),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: corTextoCinza,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Insira o código de 6 dígitos gerado na tela de Perfil '
                    'do paciente para vinculá-lo.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: corTextoCinza,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codigoController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 10,
                      color: corPrimariaEscura,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '000000',
                      hintStyle: const TextStyle(
                        color: Color(0xFFD1D5DB),
                        letterSpacing: 10,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: corPrimaria,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  BotaoPrimario(
                    texto: 'Vincular Código',
                    onPressed: () async {
                      final codigo = codigoController.text.trim();
                      if (codigo.length != 6) {
                        return;
                      }
                      try {
                        await _cuidadorApi.vincularPaciente(codigo: codigo);
                        if (contexto.mounted) {
                          Navigator.pop(contexto, true);
                        }
                      } catch (e) {
                        if (contexto.mounted) {
                          ScaffoldMessenger.of(contexto).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().contains('invalido')
                                    ? 'Código de vinculação inválido.'
                                    : 'Erro ao vincular. Verifique o código.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
    );

    codigoController.dispose();
    if (vinculado == true) {
      await _carregarTudo();
    }
  }

  Future<void> _ligarPaciente(Map<String, dynamic> paciente) async {
    final telefone =
        paciente['telefone']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ??
        '';
    if (telefone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paciente sem telefone cadastrado.')),
      );
      return;
    }
    try {
      await launchUrl(Uri.parse('tel:$telefone'));
    } catch (_) {}
  }

  Future<void> _enviarRelatorioWhatsApp(
    Map<String, dynamic> paciente,
    int dias,
    String rotuloPeriodo,
  ) async {
    final id = paciente['id']?.toString() ?? '';
    final nome = paciente['nome']?.toString() ?? 'Paciente';

    List<Map<String, dynamic>> doses;
    try {
      doses = await _cuidadorApi.listarDosesPeriodo(pacienteId: id, dias: dias);
    } catch (_) {
      doses = _dosesHoje[id] ?? [];
    }

    final tomadas =
        doses
            .where((d) => d['status'] == 'tomada' || d['status'] == 'atrasada')
            .toList();
    final perdidas = doses.where((d) => d['status'] == 'perdida').toList();
    final total = doses.length;
    final indice = total == 0 ? 0 : ((tomadas.length / total) * 100).round();

    final linhas = <String>[
      '*Relatório de Acompanhamento LembreBem* 📋',
      '',
      '*Paciente:* $nome',
      '*Período:* $rotuloPeriodo',
      '',
      '✅ *Medicamentos Tomados:* ${tomadas.length}',
      '❌ *Atrasados ou Não Tomados:* ${perdidas.length}',
      '',
      '📊 *Resumo de Adesão Clínica:*',
      '*Índice de Conclusão:* $indice%',
      '*Doses tomadas no horário:* ${tomadas.length}',
      '*Doses não registradas:* ${perdidas.length}',
    ];

    final telefone =
        paciente['telefone']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ??
        '';
    final texto = Uri.encodeComponent(linhas.join('\n'));
    final uri =
        telefone.isEmpty
            ? Uri.parse('https://wa.me/?text=$texto')
            : Uri.parse('https://wa.me/55$telefone?text=$texto');

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
        );
      }
    }
  }

  void _escolherPeriodoWhatsApp(Map<String, dynamic> paciente) {
    showDialog<void>(
      context: context,
      builder: (contexto) {
        var selecionado = 0;
        const opcoes = [
          ('Hoje (Doses em tempo real)', 1),
          ('Últimos 7 dias (Histórico semanal)', 7),
          ('Último mês (Consolidado mensal)', 30),
        ];
        return StatefulBuilder(
          builder:
              (contexto, setStateDialog) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Período do Relatório',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(contexto),
                            child: const Icon(
                              Icons.close,
                              size: 20,
                              color: corTextoCinza,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < opcoes.length; i++) ...[
                        GestureDetector(
                          onTap: () => setStateDialog(() => selecionado = i),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  selecionado == i
                                      ? corPrimaria.withValues(alpha: 0.08)
                                      : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    selecionado == i
                                        ? corPrimaria
                                        : const Color(0xFFF3F4F6),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          selecionado == i
                                              ? corPrimaria
                                              : const Color(0xFFD1D5DB),
                                      width: 2,
                                    ),
                                  ),
                                  child:
                                      selecionado == i
                                          ? Center(
                                            child: Container(
                                              width: 7,
                                              height: 7,
                                              decoration: const BoxDecoration(
                                                color: corPrimaria,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          )
                                          : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    opcoes[i].$1,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          selecionado == i
                                              ? corPrimariaEscura
                                              : const Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      BotaoPrimario(
                        texto: 'Enviar relatório para paciente',
                        cor: corSucesso,
                        icone: Icons.send,
                        onPressed: () {
                          Navigator.pop(contexto);
                          _enviarRelatorioWhatsApp(
                            paciente,
                            opcoes[selecionado].$2,
                            opcoes[selecionado].$1,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }

  void _abrirDetalhesPaciente(Map<String, dynamic> paciente) {
    final id = paciente['id']?.toString() ?? '';
    final nome = paciente['nome']?.toString() ?? 'Paciente';
    final doses = _dosesHoje[id] ?? [];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Row(
                    children: [
                      _avatarIniciais(nome, tamanho: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _abrirFichaPaciente(paciente);
                              },
                              child: const Text(
                                'Ver perfil completo →',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: corPrimaria,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, color: corTextoCinza),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const RotuloSecao(
                          'Linha do tempo de hoje',
                          cor: corPrimariaEscura,
                        ),
                        const SizedBox(height: 12),
                        if (doses.isEmpty)
                          const Text(
                            'Nenhuma dose registrada hoje.',
                            style: TextStyle(
                              fontSize: 13,
                              color: corTextoCinza,
                            ),
                          )
                        else
                          ...doses.map((dose) => _linhaDose(dose)),
                        const SizedBox(height: 16),
                        BotaoPrimario(
                          texto: 'Enviar relatório via WhatsApp',
                          cor: corSucesso,
                          icone: Icons.chat_outlined,
                          onPressed: () {
                            Navigator.pop(context);
                            _escolherPeriodoWhatsApp(paciente);
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _linhaDose(Map<String, dynamic> dose) {
    final status = dose['status']?.toString() ?? 'pendente';
    final horario = DateTime.tryParse(
      dose['horario_previsto']?.toString() ?? '',
    );
    final horaTexto =
        horario == null
            ? ''
            : '${horario.hour.toString().padLeft(2, '0')}:'
                '${horario.minute.toString().padLeft(2, '0')}';

    IconData icone;
    Color cor;
    switch (status) {
      case 'tomada':
      case 'atrasada':
        icone = Icons.check;
        cor = corSucesso;
        break;
      case 'perdida':
        icone = Icons.error_outline;
        cor = corEmergencia;
        break;
      default:
        icone = Icons.access_time;
        cor = corTextoCinzaClaro;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border:
                  status == 'pendente'
                      ? Border.all(color: const Color(0xFFD1D5DB), width: 2)
                      : null,
            ),
            child: Icon(icone, size: 16, color: cor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose['medicamento_nome']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                Text(
                  [
                    if ((dose['dose']?.toString() ?? '').isNotEmpty)
                      dose['dose'].toString(),
                    if (horaTexto.isNotEmpty) horaTexto,
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: corTextoCinzaClaro,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _abrirFichaPaciente(Map<String, dynamic> paciente) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _TelaFichaPaciente(paciente: paciente)),
    );
  }

  Future<void> _sairDoPainel() async {
    try {
      await _authApi.logout();
    } catch (_) {}
    if (!mounted) {
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const TelaInicial()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corFundo,
      body: Column(
        children: [
          Expanded(
            child:
                _carregando
                    ? _skeleton()
                    : _erro != null
                    ? _erroComRetry()
                    : switch (_abaAtiva) {
                      _AbaCuidador.pacientes => _abaPacientes(),
                      _AbaCuidador.relatorios => _abaRelatorios(),
                      _AbaCuidador.perfil => _abaPerfil(),
                    },
          ),
          _rodapeCuidador(),
        ],
      ),
    );
  }

  Widget _skeleton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            SkeletonBox(height: 120, radius: 18),
            SizedBox(height: 16),
            SkeletonBox(height: 76, radius: 16),
            SizedBox(height: 10),
            SkeletonBox(height: 76, radius: 16),
            SizedBox(height: 10),
            SkeletonBox(height: 76, radius: 16),
          ],
        ),
      ),
    );
  }

  Widget _erroComRetry() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: corTextoEscuro),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _carregarTudo,
                child: const Text('Recarregar'),
              ),
              TextButton(
                onPressed: _sairDoPainel,
                child: const Text(
                  'Sair do Painel',
                  style: TextStyle(color: corEmergencia),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarIniciais(String nome, {double tamanho = 48}) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: const BoxDecoration(
        gradient: gradientePrimario,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _iniciais(nome),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: tamanho * 0.34,
          ),
        ),
      ),
    );
  }

  Widget _abaPacientes() {
    final atrasados =
        _pacientes
            .where(
              (p) => _corStatus(p['id']?.toString() ?? '') == corEmergencia,
            )
            .length;
    final emDia =
        _pacientes
            .where((p) => _corStatus(p['id']?.toString() ?? '') == corSucesso)
            .length;

    final filtrados =
        _buscaPaciente.trim().isEmpty
            ? _pacientes
            : _pacientes
                .where(
                  (p) => (p['nome']?.toString() ?? '').toLowerCase().contains(
                    _buscaPaciente.trim().toLowerCase(),
                  ),
                )
                .toList();

    return Column(
      children: [
        CabecalhoGradiente(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: ConteudoCentralizado(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Painel do Cuidador',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    'Meus Pacientes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _cardStat('Pacientes', _pacientes.length.toString()),
                      const SizedBox(width: 8),
                      _cardStat('Atrasados', atrasados.toString()),
                      const SizedBox(width: 8),
                      _cardStat('Em dia', emDia.toString()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ConteudoCentralizado(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: sombraCard,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search,
                                size: 18,
                                color: corPrimaria,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  onChanged:
                                      (v) => setState(() => _buscaPaciente = v),
                                  decoration: const InputDecoration(
                                    hintText: 'Buscar paciente por nome...',
                                    hintStyle: TextStyle(
                                      fontSize: 13,
                                      color: corTextoCinzaClaro,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _abrirModalVincular,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: corPrimaria,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: sombraCard,
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, size: 16, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Adicionar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _carregarTudo,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        if (filtrados.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.group_outlined,
                                  size: 44,
                                  color: corTextoCinzaClaro,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Nenhum paciente vinculado.\nToque em '
                                  '"Adicionar" e insira o código de 6 '
                                  'dígitos do perfil do paciente.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                    color: corTextoCinza,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...filtrados.map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _cardPaciente(p),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cardStat(String rotulo, String valor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              valor,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              rotulo,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardPaciente(Map<String, dynamic> paciente) {
    final id = paciente['id']?.toString() ?? '';
    final nome = paciente['nome']?.toString() ?? 'Paciente';
    final corBarra = _corStatus(id);

    return GestureDetector(
      onTap: () => _abrirDetalhesPaciente(paciente),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: sombraCard,
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: corBarra,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      _avatarIniciais(nome),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _resumoStatus(id),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: corTextoCinza,
                              ),
                            ),
                            const SizedBox(height: 6),
                            BadgeStatus(
                              texto: _rotuloStatus(id),
                              cor: corBarra,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _ligarPaciente(paciente),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: corPrimaria,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.phone,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _abaRelatorios() {
    final comparativo =
        _pacientes.map((p) {
            final id = p['id']?.toString() ?? '';
            return (
              nome: p['nome']?.toString() ?? 'Paciente',
              taxa: _adesaoPorPaciente[id] ?? 0,
            );
          }).toList()
          ..sort((a, b) => b.taxa.compareTo(a.taxa));

    final media =
        comparativo.isEmpty
            ? 0
            : (comparativo.map((c) => c.taxa).reduce((a, b) => a + b) /
                    comparativo.length)
                .round();
    var tomadas = 0;
    var atrasadas = 0;
    var perdidas = 0;
    for (final id in _dosesHoje.keys) {
      for (final dose in _dosesHoje[id] ?? []) {
        switch (dose['status']) {
          case 'tomada':
            tomadas++;
          case 'atrasada':
            atrasadas++;
          case 'perdida':
            perdidas++;
        }
      }
    }
    final totalDoses = tomadas + atrasadas + perdidas;
    final barrasSemana = <Map<String, dynamic>>[];
    const rotulos = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
    for (var i = 0; i < 7; i++) {
      final taxas = <int>[];
      for (final id in _adesaoSemanal.keys) {
        final dia =
            (_adesaoSemanal[id] ?? [])
                .where((d) => d['dia'] == rotulos[i])
                .toList();
        if (dia.isNotEmpty && dia.first['taxa'] is int) {
          taxas.add(dia.first['taxa'] as int);
        }
      }
      barrasSemana.add({
        'dia': rotulos[i],
        'taxa':
            taxas.isEmpty
                ? null
                : (taxas.reduce((a, b) => a + b) / taxas.length).round(),
      });
    }

    Color corPorTaxa(int taxa) {
      if (taxa >= 90) {
        return corSucesso;
      }
      if (taxa >= 70) {
        return corPrimaria;
      }
      return corAviso;
    }

    return Column(
      children: [
        CabecalhoGradiente(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: ConteudoCentralizado(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Painel do Cuidador',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    'Relatórios',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _cardStat(
                        'Melhor',
                        comparativo.isEmpty
                            ? '—'
                            : '${comparativo.first.taxa}%',
                      ),
                      const SizedBox(width: 8),
                      _cardStat('Média geral', '$media%'),
                      const SizedBox(width: 8),
                      _cardStat(
                        'Atenção',
                        comparativo.isEmpty ? '—' : '${comparativo.last.taxa}%',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ConteudoCentralizado(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CartaoBranco(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Taxa de Adesão — Comparativo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: corPrimariaEscura,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (comparativo.isEmpty)
                          const Text(
                            'Vincule pacientes para ver o comparativo.',
                            style: TextStyle(
                              fontSize: 13,
                              color: corTextoCinza,
                            ),
                          )
                        else
                          ...comparativo.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          c.nome,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF374151),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${c.taxa}%',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: corPorTaxa(c.taxa),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: c.taxa / 100,
                                      minHeight: 10,
                                      backgroundColor: const Color(0xFFF3F4F6),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        corPorTaxa(c.taxa),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  CartaoBranco(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Adesão Semanal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: corPrimariaEscura,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: BarChart(
                            BarChartData(
                              maxY: 100,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine:
                                    (v) => const FlLine(
                                      color: Color(0xFFF3F4F6),
                                      strokeWidth: 1,
                                      dashArray: [4, 4],
                                    ),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(),
                                rightTitles: const AxisTitles(),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 34,
                                    getTitlesWidget:
                                        (valor, meta) => Text(
                                          '${valor.toInt()}%',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: corTextoCinzaClaro,
                                          ),
                                        ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (valor, meta) {
                                      final i = valor.toInt();
                                      if (i < 0 || i >= rotulos.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          rotulos[i],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: corTextoCinzaClaro,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              barGroups: [
                                for (var i = 0; i < barrasSemana.length; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY:
                                            (barrasSemana[i]['taxa'] as int?)
                                                ?.toDouble() ??
                                            0,
                                        width: 20,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(6),
                                            ),
                                        color:
                                            barrasSemana[i]['taxa'] == null
                                                ? const Color(0xFFF3F4F6)
                                                : corPorTaxa(
                                                  barrasSemana[i]['taxa']
                                                      as int,
                                                ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 14,
                          runSpacing: 6,
                          children: [
                            _legenda(corSucesso, '≥90% Excelente'),
                            _legenda(corPrimaria, '70–89% Bom'),
                            _legenda(corAviso, '<70% Atenção'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  CartaoBranco(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Distribuição de Doses — Hoje',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: corPrimariaEscura,
                          ),
                        ),
                        const Text(
                          'Consolidado de todos os pacientes',
                          style: TextStyle(
                            fontSize: 11,
                            color: corTextoCinzaClaro,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (totalDoses == 0)
                          const Text(
                            'Sem doses registradas hoje.',
                            style: TextStyle(
                              fontSize: 13,
                              color: corTextoCinza,
                            ),
                          )
                        else
                          Row(
                            children: [
                              SizedBox(
                                width: 150,
                                height: 150,
                                child: PieChart(
                                  PieChartData(
                                    centerSpaceRadius: 40,
                                    sectionsSpace: 3,
                                    sections: [
                                      if (tomadas > 0)
                                        PieChartSectionData(
                                          value: tomadas.toDouble(),
                                          color: corSucesso,
                                          showTitle: false,
                                          radius: 26,
                                        ),
                                      if (atrasadas > 0)
                                        PieChartSectionData(
                                          value: atrasadas.toDouble(),
                                          color: corAviso,
                                          showTitle: false,
                                          radius: 26,
                                        ),
                                      if (perdidas > 0)
                                        PieChartSectionData(
                                          value: perdidas.toDouble(),
                                          color: corEmergencia,
                                          showTitle: false,
                                          radius: 26,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _itemPizza(
                                      corSucesso,
                                      tomadas,
                                      totalDoses,
                                      'Tomadas',
                                    ),
                                    const SizedBox(height: 10),
                                    _itemPizza(
                                      corAviso,
                                      atrasadas,
                                      totalDoses,
                                      'Atrasadas',
                                    ),
                                    const SizedBox(height: 10),
                                    _itemPizza(
                                      corEmergencia,
                                      perdidas,
                                      totalDoses,
                                      'Perdidas',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legenda(Color cor, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          texto,
          style: const TextStyle(fontSize: 11, color: corTextoCinzaClaro),
        ),
      ],
    );
  }

  Widget _itemPizza(Color cor, int valor, int total, String rotulo) {
    final pct = total == 0 ? 0 : ((valor / total) * 100).round();
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$pct%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
            Text(
              rotulo,
              style: const TextStyle(fontSize: 11, color: corTextoCinzaClaro),
            ),
          ],
        ),
      ],
    );
  }

  Widget _abaPerfil() {
    final nome = _cuidador?['nome']?.toString() ?? 'Cuidador';
    final email = _cuidador?['email']?.toString() ?? '';
    final registro = _cuidador?['registro_profissional']?.toString() ?? '';

    return Column(
      children: [
        CabecalhoGradiente(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x22000000), blurRadius: 10),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 40,
                    color: corPrimariaEscura,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  nome,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  registro.isEmpty ? 'Cuidador(a)' : 'Profissional de saúde',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ConteudoCentralizado(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CartaoBranco(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '👤 Dados Profissionais',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const Divider(color: Color(0xFFF3F4F6)),
                        const SizedBox(height: 6),
                        const RotuloSecao('Registro profissional'),
                        const SizedBox(height: 2),
                        Text(
                          registro.isEmpty ? 'Não informado' : registro,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const RotuloSecao('E-mail de acesso'),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: corPrimaria.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: sombraCard,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: corPrimaria.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.workspace_premium_outlined,
                            color: corPrimaria,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text(
                                    'Plano Premium Ativo',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(
                                    Icons.verified_user_outlined,
                                    size: 15,
                                    color: corSucesso,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Sua assinatura corporativa dá direito ao '
                                'monitoramento de pacientes ilimitados e '
                                'relatórios completos.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: corTextoCinzaClaro,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  BotaoPrimario(
                    texto: 'Sair do Painel',
                    contorno: true,
                    cor: corEmergencia,
                    icone: Icons.logout,
                    onPressed: _sairDoPainel,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rodapeCuidador() {
    Widget aba(_AbaCuidador aba, IconData icone, String rotulo) {
      final ativa = _abaAtiva == aba;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _abaAtiva = aba),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: ativa ? 1.15 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    icone,
                    size: 24,
                    color: ativa ? corPrimariaEscura : corTextoCinzaClaro,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: ativa ? FontWeight.w700 : FontWeight.w500,
                    color: ativa ? corPrimariaEscura : corTextoCinzaClaro,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x14000000))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            aba(_AbaCuidador.pacientes, Icons.group_outlined, 'Pacientes'),
            aba(
              _AbaCuidador.relatorios,
              Icons.bar_chart_outlined,
              'Relatórios',
            ),
            aba(
              _AbaCuidador.perfil,
              Icons.account_circle_outlined,
              'Meu Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

class _TelaFichaPaciente extends StatelessWidget {
  const _TelaFichaPaciente({required this.paciente});

  final Map<String, dynamic> paciente;

  String _texto(String chave) {
    final valor = paciente[chave];
    if (valor == null || valor.toString() == 'null') {
      return '';
    }
    return valor.toString();
  }

  int? get _idade {
    final iso = _texto('data_nascimento');
    if (iso.isEmpty) {
      return null;
    }
    final nascimento = DateTime.tryParse(iso.split('T').first);
    if (nascimento == null) {
      return null;
    }
    final hoje = DateTime.now();
    var anos = hoje.year - nascimento.year;
    if (hoje.month < nascimento.month ||
        (hoje.month == nascimento.month && hoje.day < nascimento.day)) {
      anos--;
    }
    return anos;
  }

  @override
  Widget build(BuildContext context) {
    final idade = _idade;

    return Scaffold(
      backgroundColor: corFundo,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  LinkVoltar(onTap: () => Navigator.pop(context)),
                  const Expanded(
                    child: Text(
                      'Ficha do Paciente',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: corPrimariaEscura,
                      ),
                    ),
                  ),
                  const SizedBox(width: 70),
                ],
              ),
            ),
            Expanded(
              child: ConteudoCentralizado(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _cardFicha('Dados Pessoais', corPrimariaEscura, [
                        ('Nome:', _texto('nome')),
                        ('Idade:', idade == null ? '' : '$idade anos'),
                        ('Tipo Sanguíneo:', _texto('tipo_sanguineo')),
                      ]),
                      const SizedBox(height: 12),
                      _cardFicha('Documentação e Convênio', corPrimariaEscura, [
                        ('Cartão SUS:', _texto('cartao_sus')),
                        ('Plano de Saúde:', _texto('convenio')),
                      ]),
                      const SizedBox(height: 12),
                      _cardFicha('Alertas Médicos', corEmergencia, [
                        ('Alergias:', _texto('alergias')),
                      ]),
                      const SizedBox(height: 12),
                      _cardFicha('Contato', corPrimariaEscura, [
                        ('Telefone:', _texto('telefone')),
                        ('E-mail:', _texto('email')),
                        (
                          'Cidade:',
                          [
                            _texto('cidade'),
                            _texto('estado'),
                          ].where((t) => t.isNotEmpty).join(' - '),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardFicha(
    String titulo,
    Color corTitulo,
    List<(String, String)> linhas,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: sombraCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: corTitulo,
            ),
          ),
          const SizedBox(height: 10),
          for (final (rotulo, valor) in linhas)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$rotulo ',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      valor.isEmpty ? '—' : valor,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            titulo == 'Alertas Médicos' && valor.isNotEmpty
                                ? corEmergencia
                                : const Color(0xFF4B5563),
                        fontWeight:
                            titulo == 'Alertas Médicos' && valor.isNotEmpty
                                ? FontWeight.w600
                                : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
