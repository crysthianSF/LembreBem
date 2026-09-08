import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lembrebem/backend/app_api.dart';
import 'package:lembrebem/backend/catalogo_api.dart';
import 'package:lembrebem/backend/favoritos_api.dart';
import 'package:lembrebem/backend/receitas_api.dart';
import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:lembrebem/menu_rodape.dart';
import 'package:lembrebem/modelo_alarme.dart' as modelo;
import 'package:lembrebem/backend/alarmes_api.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/telas/tela_alarme.dart';
import 'package:lembrebem/telas/tela_config_alarme.dart';
import 'package:lembrebem/widgets/skeleton_box.dart';
import 'package:lembrebem/widgets/componentes.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TelaMedicamentos extends StatefulWidget {
  const TelaMedicamentos({super.key});

  @override
  State<TelaMedicamentos> createState() => _TelaMedicamentosState();
}

enum _AbaMedicamentos { emUso, historico, receitas }

class _TelaMedicamentosState extends State<TelaMedicamentos> {
  final AlarmesApi _alarmesApi = AlarmesApi();
  final AppApi _appApi = AppApi();
  final CatalogoApi _catalogoApi = CatalogoApi();
  final FavoritosApi _favoritosApi = FavoritosApi();
  final ReceitasApi _receitasApi = ReceitasApi();

  _AbaMedicamentos _abaAtiva = _AbaMedicamentos.emUso;

  bool _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _emUso = [];
  List<Map<String, dynamic>> _historico = [];

  List<Map<String, dynamic>> _receitas = [];
  bool _receitasDisponiveis = true;

  String? get _usuarioId => SupabaseBackend.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  Future<void> _carregarTudo() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) {
      setState(() {
        _erro = 'Usuário não autenticado.';
        _carregando = false;
      });
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final usuarioMeds = await _appApi.listarUsuarioMedicamentos(
        usuarioId: usuarioId,
      );
      List<Map<String, dynamic>> favoritos = [];
      try {
        favoritos = await _favoritosApi.listarFavoritos(usuarioId: usuarioId);
      } catch (_) {}
      try {
        _receitas = await _receitasApi.listarReceitas(usuarioId: usuarioId);
        _receitasDisponiveis = true;
      } catch (_) {
        _receitasDisponiveis = false;
      }
      final idsCatalogo =
          <String>{
            ...usuarioMeds
                .map((m) => m['medicamento_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty),
            ...favoritos
                .map((f) => f['medicamento_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty),
          }.toList();

      Map<String, Map<String, dynamic>> catalogo = {};
      try {
        catalogo = await _catalogoApi.buscarMedicamentosPorIds(idsCatalogo);
      } catch (_) {}

      final emUso = <Map<String, dynamic>>[];
      final historico = <Map<String, dynamic>>[];
      final idsJaListados = <String>{};

      for (final item in usuarioMeds) {
        final medId = item['medicamento_id']?.toString() ?? '';
        final detalhe = catalogo[medId];
        final combinado = {
          ...?detalhe,
          '_origem': 'usuario_medicamento',
          '_usuario_medicamento_id': item['id']?.toString(),
          '_medicamento_id': item['medicamento_id'],
          '_apelido': item['apelido']?.toString() ?? '',
          '_criado_em': item['created_at']?.toString() ?? '',
        };
        final ativo = item['ativo'];
        if (ativo == false) {
          historico.add(combinado);
        } else {
          emUso.add(combinado);
          idsJaListados.add(medId);
        }
      }

      for (final fav in favoritos) {
        final medId = fav['medicamento_id']?.toString() ?? '';
        if (medId.isEmpty || idsJaListados.contains(medId)) {
          continue;
        }
        final detalhe = catalogo[medId];
        emUso.add({
          ...?detalhe,
          '_origem': 'favorito',
          '_medicamento_id': fav['medicamento_id'],
          '_criado_em': fav['criado_em']?.toString() ?? '',
        });
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _emUso = emUso;
        _historico = historico;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _erro = 'Falha ao carregar seus medicamentos.';
        _carregando = false;
      });
    }
  }

  String _nomeItem(Map<String, dynamic> item) {
    final nomeCatalogo = item['nome_produto']?.toString() ?? '';
    if (nomeCatalogo.isNotEmpty) {
      return nomeCatalogo;
    }
    final apelido = item['_apelido']?.toString() ?? '';
    if (apelido.isNotEmpty) {
      return apelido;
    }
    return 'Medicamento ${item['_medicamento_id'] ?? ''}';
  }

  String _dataFormatada(String? iso) {
    if (iso == null || iso.isEmpty) {
      return '';
    }
    final data = DateTime.tryParse(iso);
    if (data == null) {
      return '';
    }
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Future<void> _removerItemEmUso(Map<String, dynamic> item) async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) {
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Remover medicamento?'),
            content: Text('Remover "${_nomeItem(item)}" da lista Em Uso?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Remover',
                  style: TextStyle(color: corEmergencia),
                ),
              ),
            ],
          ),
    );
    if (confirmar != true) {
      return;
    }

    try {
      final medId = item['_medicamento_id'];
      final medIdInt =
          medId is num ? medId.toInt() : int.tryParse(medId?.toString() ?? '');

      if (item['_origem'] == 'favorito') {
        if (medIdInt != null) {
          await _favoritosApi.removerFavorito(
            usuarioId: usuarioId,
            medicamentoId: medIdInt,
          );
        }
      } else {
        final usuarioMedicamentoId =
            item['_usuario_medicamento_id']?.toString();
        if (usuarioMedicamentoId != null) {
          await _appApi.deletarUsuarioMedicamento(
            usuarioId: usuarioId,
            usuarioMedicamentoId: usuarioMedicamentoId,
            medicamentoId: medIdInt,
          );
        }
      }
      await _carregarTudo();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao remover medicamento.')),
        );
      }
    }
  }

  Future<void> _configurarAlarme(Map<String, dynamic> item) async {
    Navigator.pop(context);
    final medId = item['_medicamento_id'];
    final medIdInt =
        medId is num ? medId.toInt() : int.tryParse(medId?.toString() ?? '');

    final novoAlarme = await Navigator.push<modelo.Alarme?>(
      context,
      MaterialPageRoute(
        builder:
            (_) => TelaConfigAlarme(
              medicamentoInicial: _nomeItem(item),
              medicamentoIdInicial: medIdInt,
            ),
      ),
    );

    if (novoAlarme == null || !mounted) {
      return;
    }
    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null) {
      return;
    }
    try {
      await _alarmesApi.salvarNovoAlarme(
        nome: novoAlarme.nome,
        observacoes: novoAlarme.observacoes,
        horario: novoAlarme.horario,
        diasDeUso: novoAlarme.diasDeUso,
        ativado: novoAlarme.ativado,
        intervalo: novoAlarme.intervalo,
        usuarioId: user.id,
        medicamentoId: novoAlarme.medicamentoId,
        usuarioMedicamentoId: novoAlarme.usuarioMedicamentoId,
      );
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TelaAlarme()),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível salvar o alarme.')),
        );
      }
    }
  }

  Future<void> _abrirBula() async {
    final uri = Uri.parse('https://consultas.anvisa.gov.br/#/bulario/');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _abrirDetalhes(Map<String, dynamic> item, {bool historico = false}) {
    final dosagem = item['concentracao_dosagem']?.toString() ?? '';
    final apresentacao = item['apresentacao']?.toString() ?? '';
    final fabricante =
        item['fabricante']?.toString() ??
        item['empresa_detentora_registro']?.toString() ??
        '';
    final principio = item['principio_ativo']?.toString() ?? '';
    final inicio = _dataFormatada(item['_criado_em']?.toString());

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Container(
            decoration: const BoxDecoration(
              color: corFundo,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB9C8CC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.medication_outlined,
                          color: corPrimariaEscura,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nomeItem(item),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: corPrimariaEscura,
                              ),
                            ),
                            if (fabricante.isNotEmpty || dosagem.isNotEmpty)
                              Text(
                                [
                                  if (dosagem.isNotEmpty) dosagem,
                                  if (fabricante.isNotEmpty) fabricante,
                                ].join(' • '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: corTextoCinza,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (apresentacao.isNotEmpty)
                    _cardInfoSheet(
                      Icons.access_time,
                      'Apresentação',
                      apresentacao,
                    ),
                  if (inicio.isNotEmpty)
                    _cardInfoSheet(
                      Icons.calendar_today_outlined,
                      'Período de Uso',
                      historico ? 'Encerrado' : 'Início: $inicio (Contínuo)',
                    ),
                  if (principio.isNotEmpty)
                    _cardInfoSheet(
                      Icons.info_outline,
                      'Princípio Ativo',
                      principio,
                    ),
                  const SizedBox(height: 8),
                  if (!historico)
                    BotaoPrimario(
                      texto: 'Configurar Alarme Horário',
                      cor: corPrimariaEscura,
                      icone: Icons.notifications_none,
                      onPressed: () => _configurarAlarme(item),
                    ),
                  const SizedBox(height: 10),
                  BotaoPrimario(
                    texto: 'Visualizar Bula Digital',
                    contorno: true,
                    cor: corTextoCinza,
                    onPressed: _abrirBula,
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _cardInfoSheet(IconData icone, String titulo, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CartaoBranco(
        radius: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 20, color: corPrimariaEscura),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: corPrimariaEscura,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    texto,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: corTextoEscuro,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adicionarReceita() async {
    final salvo = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _TelaNovaReceita()),
    );
    if (salvo == true) {
      await _carregarTudo();
    }
  }

  Future<void> _abrirReceita(Map<String, dynamic> receita) async {
    try {
      final base64Conteudo = await _receitasApi.buscarArquivoBase64(
        receitaId: receita['id'].toString(),
      );
      if (base64Conteudo == null || base64Conteudo.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Arquivo não encontrado.')),
          );
        }
        return;
      }
      final bytes = base64Decode(base64Conteudo);
      final dir = await getTemporaryDirectory();
      final nomeArquivo = receita['nome_arquivo']?.toString() ?? 'receita.pdf';
      final arquivo = File('${dir.path}/$nomeArquivo');
      await arquivo.writeAsBytes(bytes, flush: true);
      await OpenFilex.open(arquivo.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao abrir a receita.')),
        );
      }
    }
  }

  Future<void> _removerReceita(Map<String, dynamic> receita) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Excluir receita?'),
            content: Text('Excluir "${receita['nome']}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Excluir',
                  style: TextStyle(color: corEmergencia),
                ),
              ),
            ],
          ),
    );
    if (confirmar != true) {
      return;
    }
    try {
      await _receitasApi.deletarReceita(receitaId: receita['id'].toString());
      await _carregarTudo();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao excluir receita.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corFundo,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ConteudoCentralizado(
                child: RefreshIndicator(
                  onRefresh: _carregarTudo,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        const Text(
                          'Meus Medicamentos',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: corPrimariaEscura,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _seletorAbas(),
                        const SizedBox(height: 16),
                        if (_carregando)
                          ...List.generate(
                            4,
                            (_) => const Padding(
                              padding: EdgeInsets.only(bottom: 10),
                              child: SkeletonBox(height: 80, radius: 16),
                            ),
                          )
                        else if (_erro != null)
                          CartaoBranco(
                            child: Column(
                              children: [
                                Text(
                                  _erro!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: corTextoCinza,
                                  ),
                                ),
                                TextButton(
                                  onPressed: _carregarTudo,
                                  child: const Text('Recarregar'),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._conteudoAba(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const BarraNavegacaoApp(ativa: AbaApp.medicamentos),
          ],
        ),
      ),
    );
  }

  Widget _seletorAbas() {
    Widget botao(_AbaMedicamentos aba, String rotulo) {
      final ativa = _abaAtiva == aba;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _abaAtiva = aba),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: ativa ? corPrimariaEscura : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              rotulo.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: ativa ? Colors.white : corTextoCinzaClaro,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: sombraCard,
      ),
      child: Row(
        children: [
          botao(_AbaMedicamentos.emUso, 'Em Uso'),
          botao(_AbaMedicamentos.historico, 'Histórico'),
          botao(_AbaMedicamentos.receitas, 'Receitas'),
        ],
      ),
    );
  }

  List<Widget> _conteudoAba() {
    switch (_abaAtiva) {
      case _AbaMedicamentos.emUso:
        if (_emUso.isEmpty) {
          return [
            _placeholder(
              Icons.medication_outlined,
              'Nenhum medicamento ativo.',
              'Favorite remédios no catálogo da busca para '
                  'acompanhá-los por aqui.',
            ),
          ];
        }
        return _emUso
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _cardMedicamento(item),
              ),
            )
            .toList();

      case _AbaMedicamentos.historico:
        if (_historico.isEmpty) {
          return [
            _placeholder(
              Icons.history,
              'Nenhum medicamento no histórico.',
              'Medicamentos com uso encerrado aparecem aqui.',
            ),
          ];
        }
        return _historico
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _cardMedicamento(item, historico: true),
              ),
            )
            .toList();

      case _AbaMedicamentos.receitas:
        final widgets = <Widget>[
          BotaoPrimario(
            texto: 'Adicionar nova receita',
            icone: Icons.note_add_outlined,
            onPressed:
                _receitasDisponiveis
                    ? _adicionarReceita
                    : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Receitas indisponíveis. Rode o SQL no Supabase.',
                          ),
                        ),
                      );
                    },
          ),
          const SizedBox(height: 14),
        ];
        if (_receitas.isEmpty) {
          widgets.add(
            _placeholder(
              Icons.description_outlined,
              'Nenhuma receita anexada.',
              'Guarde prescrições médicas em formato PDF para '
                  'consultas rápidas.',
            ),
          );
        } else {
          widgets.addAll(
            _receitas.map(
              (receita) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _cardReceita(receita),
              ),
            ),
          );
        }
        return widgets;
    }
  }

  Widget _placeholder(IconData icone, String titulo, String texto) {
    return CartaoBranco(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(icone, size: 40, color: corTextoCinzaClaro),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: corTextoEscuro,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: corTextoCinza,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardMedicamento(Map<String, dynamic> item, {bool historico = false}) {
    final nome = _nomeItem(item);
    final dosagem = item['concentracao_dosagem']?.toString() ?? '';
    final fabricante =
        item['fabricante']?.toString() ??
        item['empresa_detentora_registro']?.toString() ??
        '';
    final inicio = _dataFormatada(item['_criado_em']?.toString());

    final card = CartaoBranco(
      radius: 16,
      onTap: () => _abrirDetalhes(item, historico: historico),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: corFundo,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medication_outlined,
              color: corPrimariaEscura,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                    decoration: historico ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (dosagem.isNotEmpty || fabricante.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (dosagem.isNotEmpty) dosagem,
                      if (fabricante.isNotEmpty) fabricante,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: corPrimariaEscura,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                if (historico)
                  const BadgeStatus(
                    texto: 'Status: Concluído / Interrompido',
                    cor: corSucesso,
                  )
                else if (inicio.isNotEmpty)
                  Text(
                    'Início: $inicio',
                    style: const TextStyle(
                      fontSize: 10,
                      color: corTextoCinzaClaro,
                    ),
                  ),
              ],
            ),
          ),
          if (!historico)
            IconButton(
              onPressed: () => _removerItemEmUso(item),
              icon: const Icon(
                Icons.delete_outline,
                color: Color(0xFFF87171),
                size: 22,
              ),
            ),
          const Icon(Icons.chevron_right, color: corTextoCinzaClaro, size: 22),
        ],
      ),
    );

    return historico ? Opacity(opacity: 0.75, child: card) : card;
  }

  Widget _cardReceita(Map<String, dynamic> receita) {
    final nome = receita['nome']?.toString() ?? '';
    final arquivo = receita['nome_arquivo']?.toString() ?? '';
    final data = _dataFormatada(receita['criado_em']?.toString());

    return CartaoBranco(
      radius: 16,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              color: corEmergencia,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [arquivo, if (data.isNotEmpty) data].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: corTextoCinzaClaro,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _removerReceita(receita),
            icon: const Icon(
              Icons.delete_outline,
              color: Color(0xFFF87171),
              size: 20,
            ),
          ),
          GestureDetector(
            onTap: () => _abrirReceita(receita),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: const Text(
                'Abrir',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: corPrimariaEscura,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelaNovaReceita extends StatefulWidget {
  const _TelaNovaReceita();

  @override
  State<_TelaNovaReceita> createState() => _TelaNovaReceitaState();
}

class _TelaNovaReceitaState extends State<_TelaNovaReceita> {
  final _nomeController = TextEditingController();
  final ReceitasApi _receitasApi = ReceitasApi();

  String? _nomeArquivo;
  List<int>? _bytesArquivo;
  bool _salvando = false;

  static const int _tamanhoMaximo = 3 * 1024 * 1024;

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  Future<void> _selecionarArquivo() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (resultado == null || resultado.files.isEmpty) {
      return;
    }
    final arquivo = resultado.files.first;
    final bytes = arquivo.bytes;
    if (bytes == null) {
      return;
    }
    if (bytes.length > _tamanhoMaximo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arquivo muito grande. Limite de 3 MB.'),
          ),
        );
      }
      return;
    }
    setState(() {
      _nomeArquivo = arquivo.name;
      _bytesArquivo = bytes;
    });
  }

  Future<void> _salvar() async {
    if (_salvando) {
      return;
    }
    final nome = _nomeController.text.trim();
    if (nome.isEmpty || _bytesArquivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome e anexe o arquivo PDF.')),
      );
      return;
    }
    final usuarioId = SupabaseBackend.client.auth.currentUser?.id;
    if (usuarioId == null) {
      return;
    }

    setState(() => _salvando = true);
    try {
      await _receitasApi.salvarReceita(
        usuarioId: usuarioId,
        nome: nome,
        nomeArquivo: _nomeArquivo ?? 'receita.pdf',
        arquivoBase64: base64Encode(_bytesArquivo!),
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      final mensagem =
          e.toString().contains('receitas')
              ? 'Tabela não encontrada. Rode o SQL no Supabase.'
              : 'Erro ao salvar a receita.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final temArquivo = _bytesArquivo != null;

    return Scaffold(
      backgroundColor: corFundo,
      body: SafeArea(
        child: ConteudoCentralizado(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    LinkVoltar(onTap: () => Navigator.pop(context)),
                    const Expanded(
                      child: Text(
                        'Nova Receita',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: corPrimariaEscura,
                        ),
                      ),
                    ),
                    const SizedBox(width: 70),
                  ],
                ),
                const SizedBox(height: 26),
                CampoComIcone(
                  controller: _nomeController,
                  rotulo: 'Nome da Receita / Descrição',
                  dica: 'Ex: Receita Dr. Paulo - Cardiologia',
                  icone: Icons.edit_note,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Documento da Receita',
                  style: TextStyle(
                    color: corPrimariaEscura,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _selecionarArquivo,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            temArquivo ? corPrimaria : const Color(0xFFD1D5DB),
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                temArquivo ? corFundo : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            temArquivo
                                ? Icons.description_outlined
                                : Icons.upload_outlined,
                            color:
                                temArquivo ? corPrimaria : corTextoCinzaClaro,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          temArquivo
                              ? (_nomeArquivo ?? 'arquivo.pdf')
                              : 'Anexar arquivo .pdf',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Toque para selecionar do dispositivo',
                          style: TextStyle(
                            fontSize: 12,
                            color: corTextoCinzaClaro,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                BotaoPrimario(
                  texto: 'Salvar Receita',
                  carregando: _salvando,
                  onPressed: _salvar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
