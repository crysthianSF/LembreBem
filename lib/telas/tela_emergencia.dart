import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lembrebem/backend/contatos_emergencia_api.dart';
import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:lembrebem/menu_rodape.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/widgets/skeleton_box.dart';
import 'package:lembrebem/widgets/componentes.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:url_launcher/url_launcher.dart';

class TelaEmergencia extends StatefulWidget {
  const TelaEmergencia({super.key});

  @override
  State<TelaEmergencia> createState() => _TelaEmergenciaState();
}

class _TelaEmergenciaState extends State<TelaEmergencia> {
  final ContatosEmergenciaApi _contatosApi = ContatosEmergenciaApi();

  List<Map<String, dynamic>> _contatos = [];
  bool _carregando = true;
  bool _tabelaAusente = false;

  @override
  void initState() {
    super.initState();
    _carregarContatos();
  }

  String? get _usuarioId => SupabaseBackend.client.auth.currentUser?.id;

  Future<void> _carregarContatos() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) {
      setState(() => _carregando = false);
      return;
    }
    try {
      final contatos = await _contatosApi.listarContatos(usuarioId: usuarioId);
      if (!mounted) {
        return;
      }
      setState(() {
        _contatos = contatos;
        _carregando = false;
        _tabelaAusente = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _carregando = false;
        _tabelaAusente = e.toString().contains('contatos_emergencia');
      });
    }
  }

  Future<void> _ligar(String numero) async {
    final somenteDigitos = numero.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('tel:$somenteDigitos');
    try {
      final abriu = await launchUrl(uri);
      if (!abriu && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível iniciar a ligação.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível iniciar a ligação.')),
        );
      }
    }
  }

  Future<void> _removerContato(Map<String, dynamic> contato) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Remover contato?'),
            content: Text('Remover "${contato['nome']}" dos seus contatos?'),
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
      await _contatosApi.deletarContato(contatoId: contato['id'].toString());
      await _carregarContatos();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao remover contato.')),
        );
      }
    }
  }

  Future<void> _abrirFormularioContato() async {
    final salvo = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const _TelaAdicionarContato()),
    );
    if (salvo == true) {
      await _carregarContatos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FundoDecorado(
        child: Column(
          children: [
            Expanded(
              child: ConteudoCentralizado(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const Text(
                        'Emergência',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: corPrimariaEscura,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _CardContatoOficial(
                        titulo: 'Polícia Militar',
                        numero: '190',
                        icone: Icons.shield_outlined,
                      ),
                      const SizedBox(height: 14),
                      const _CardContatoOficial(
                        titulo: 'SAMU',
                        numero: '192',
                        icone: Icons.medical_services_outlined,
                      ),
                      const SizedBox(height: 14),
                      const _CardContatoOficial(
                        titulo: 'Corpo de Bombeiros',
                        numero: '193',
                        icone: Icons.local_fire_department_outlined,
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Contatos de confiança',
                        style: TextStyle(
                          color: corPrimariaEscura,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_carregando) ...[
                        const SkeletonBox(height: 72),
                        const SizedBox(height: 10),
                        const SkeletonBox(height: 72),
                      ] else if (_tabelaAusente)
                        const CartaoBranco(
                          child: Text(
                            'Contatos indisponíveis. Rode o SQL '
                            '(sql/prototipo_novas_tabelas.sql) no Supabase '
                            'para ativar este recurso.',
                            style: TextStyle(
                              fontSize: 13,
                              color: corTextoCinza,
                            ),
                          ),
                        )
                      else if (_contatos.isEmpty)
                        const CartaoBranco(
                          child: Text(
                            'Nenhum contato de confiança cadastrado.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: corTextoCinza,
                            ),
                          ),
                        )
                      else
                        ..._contatos.map(
                          (contato) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CardContatoConfianca(
                              nome: contato['nome']?.toString() ?? '',
                              telefone: contato['telefone']?.toString() ?? '',
                              aoLigar:
                                  () => _ligar(
                                    contato['telefone']?.toString() ?? '',
                                  ),
                              aoRemover: () => _removerContato(contato),
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      BotaoPrimario(
                        texto: 'Adicionar contato de emergência',
                        icone: Icons.add,
                        onPressed: _abrirFormularioContato,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
            const BarraNavegacaoApp(ativa: AbaApp.emergencia),
          ],
        ),
      ),
    );
  }
}

class _CardContatoOficial extends StatelessWidget {
  const _CardContatoOficial({
    required this.titulo,
    required this.numero,
    required this.icone,
  });

  final String titulo;
  final String numero;
  final IconData icone;

  Future<void> _ligar(BuildContext context) async {
    final uri = Uri.parse('tel:$numero');
    try {
      await launchUrl(uri);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível iniciar a ligação.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _ligar(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: corEmergencia, width: 2),
          boxShadow: sombraCard,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: corEmergencia.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icone, size: 26, color: corEmergenciaForte),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    numero,
                    style: const TextStyle(
                      color: corEmergenciaForte,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: corEmergencia,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone, color: Colors.white, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardContatoConfianca extends StatelessWidget {
  const _CardContatoConfianca({
    required this.nome,
    required this.telefone,
    required this.aoLigar,
    required this.aoRemover,
  });

  final String nome;
  final String telefone;
  final VoidCallback aoLigar;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    return CartaoBranco(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  telefone,
                  style: const TextStyle(color: corTextoCinza, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: aoRemover,
            icon: const Icon(
              Icons.delete_outline,
              color: Color(0xFFF87171),
              size: 22,
            ),
          ),
          GestureDetector(
            onTap: aoLigar,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: corPrimaria,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelaAdicionarContato extends StatefulWidget {
  const _TelaAdicionarContato();

  @override
  State<_TelaAdicionarContato> createState() => _TelaAdicionarContatoState();
}

class _TelaAdicionarContatoState extends State<_TelaAdicionarContato> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _telefoneController = TextEditingController();
  final ContatosEmergenciaApi _contatosApi = ContatosEmergenciaApi();

  final telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool _salvando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando || !_formKey.currentState!.validate()) {
      return;
    }
    final usuarioId = SupabaseBackend.client.auth.currentUser?.id;
    if (usuarioId == null) {
      return;
    }

    setState(() => _salvando = true);
    try {
      await _contatosApi.salvarContato(
        usuarioId: usuarioId,
        nome: _nomeController.text.trim(),
        telefone: _telefoneController.text.trim(),
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
          e.toString().contains('contatos_emergencia')
              ? 'Tabela não encontrada. Rode o SQL no Supabase.'
              : 'Erro ao salvar contato.';
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
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: FundoDecorado(
        child: ConteudoCentralizado(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: LinkVoltar(onTap: () => Navigator.pop(context)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Adicionar contato de emergência',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: corPrimariaEscura,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),
                  CampoComIcone(
                    controller: _nomeController,
                    rotulo: 'Nome',
                    dica: 'Digite o nome do contato...',
                    icone: Icons.person_outline,
                    validador:
                        (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Informe o nome.'
                                : null,
                  ),
                  const SizedBox(height: 16),
                  CampoComIcone(
                    controller: _telefoneController,
                    rotulo: 'Número de telefone',
                    dica: '(00) 00000-0000',
                    icone: Icons.phone_outlined,
                    teclado: TextInputType.phone,
                    formatadores: [
                      FilteringTextInputFormatter.digitsOnly,
                      telefoneFormatter,
                    ],
                    validador: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Informe o telefone.';
                      }
                      if (telefoneFormatter.getUnmaskedText().length < 10) {
                        return 'Digite um telefone válido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),
                  BotaoPrimario(
                    texto: 'Salvar contato',
                    carregando: _salvando,
                    onPressed: _salvar,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
