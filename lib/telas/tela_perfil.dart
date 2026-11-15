import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lembrebem/backend/auth_api.dart';
import 'package:lembrebem/backend/perfil_usuario_api.dart';
import 'package:lembrebem/menu_rodape.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/telas/tela_inicial.dart';
import 'package:lembrebem/widgets/skeleton_box.dart';
import 'package:lembrebem/widgets/componentes.dart';

class TelaPerfil extends StatefulWidget {
  const TelaPerfil({super.key});

  @override
  State<TelaPerfil> createState() => _TelaPerfilState();
}

class _TelaPerfilState extends State<TelaPerfil> {
  final PerfilUsuarioApi _perfilApi = PerfilUsuarioApi();
  final AuthApi _authApi = AuthApi();
  final ImagePicker _imagePicker = ImagePicker();

  PerfilUsuario? _perfil;
  bool _carregando = true;
  bool _editando = false;
  bool _salvando = false;
  bool _salvoComSucesso = false;
  String? _erro;
  final _nomeController = TextEditingController();
  final _cpfController = TextEditingController();
  final _emailController = TextEditingController();
  final _nascimentoController = TextEditingController();
  final _senhaController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _cepController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _estadoController = TextEditingController();
  final _tipoSanguineoController = TextEditingController();
  final _convenioController = TextEditingController();
  final _cartaoSusController = TextEditingController();
  final _alergiasController = TextEditingController();

  String? _fotoDataUrl;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  @override
  void dispose() {
    for (final c in [
      _nomeController,
      _cpfController,
      _emailController,
      _nascimentoController,
      _senhaController,
      _telefoneController,
      _cepController,
      _logradouroController,
      _numeroController,
      _bairroController,
      _cidadeController,
      _estadoController,
      _tipoSanguineoController,
      _convenioController,
      _cartaoSusController,
      _alergiasController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarPerfil() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final perfil = await _perfilApi.carregarPerfil();
      if (!mounted) {
        return;
      }
      setState(() {
        _perfil = perfil;
        _fotoDataUrl = perfil.fotoDataUrl;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _erro = _mensagemErroPerfil(e);
        _carregando = false;
      });
    }
  }

  String _mensagemErroPerfil(Object erro) {
    final texto = erro.toString().toLowerCase();
    if (texto.contains('failed host lookup') ||
        texto.contains('socketexception') ||
        texto.contains('network')) {
      return 'Sem internet no momento. Verifique sua conexão.';
    }
    return 'Falha ao carregar o perfil.';
  }

  void _iniciarEdicao() {
    final p = _perfil;
    if (p == null) {
      return;
    }
    _nomeController.text = p.nome;
    _cpfController.text = p.cpf;
    _emailController.text = p.email;
    _nascimentoController.text = p.dataNascimento;
    _senhaController.text = p.senha;
    _telefoneController.text = p.telefone;
    _cepController.text = p.cep;
    _logradouroController.text = p.logradouro;
    _numeroController.text = p.numero;
    _bairroController.text = p.bairro;
    _cidadeController.text = p.cidade;
    _estadoController.text = p.estado;
    _tipoSanguineoController.text = p.tipoSanguineo;
    _convenioController.text = p.convenio;
    _cartaoSusController.text = p.cartaoSus;
    _alergiasController.text = p.alergias;
    setState(() {
      _editando = true;
      _salvoComSucesso = false;
    });
  }

  Future<void> _salvar() async {
    final p = _perfil;
    if (p == null || _salvando) {
      return;
    }

    setState(() => _salvando = true);

    final atualizado = PerfilUsuario(
      nome: _nomeController.text.trim(),
      cpf: _cpfController.text.trim(),
      email: _emailController.text.trim(),
      dataNascimento: _nascimentoController.text.trim(),
      telefone: _telefoneController.text.trim(),
      senha: _senhaController.text,
      fotoDataUrl: _fotoDataUrl,
      cep: _cepController.text.trim(),
      logradouro: _logradouroController.text.trim(),
      numero: _numeroController.text.trim(),
      bairro: _bairroController.text.trim(),
      cidade: _cidadeController.text.trim(),
      estado: _estadoController.text.trim().toUpperCase(),
      tipoSanguineo: _tipoSanguineoController.text.trim().toUpperCase(),
      cartaoSus: _cartaoSusController.text.trim(),
      convenio: _convenioController.text.trim(),
      alergias: _alergiasController.text.trim(),
      codigoVinculacao: p.codigoVinculacao,
    );

    try {
      final salvo = await _perfilApi.salvarPerfil(atualizado);
      if (!mounted) {
        return;
      }
      setState(() {
        _perfil = salvo;
        _fotoDataUrl = salvo.fotoDataUrl;
        _editando = false;
        _salvando = false;
        _salvoComSucesso = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _salvando = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erro ao salvar o perfil.')));
    }
  }

  Future<void> _escolherFoto() async {
    try {
      final imagem = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 700,
        maxHeight: 700,
      );
      if (imagem == null) {
        return;
      }
      final bytes = await imagem.readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      setState(() => _fotoDataUrl = dataUrl);
      if (!_editando && _perfil != null) {
        _perfil!.fotoDataUrl = dataUrl;
        try {
          await _perfilApi.salvarPerfil(_perfil!);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _confirmarLogout() async {
    final sair = await showDialog<bool>(
      context: context,
      builder:
          (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: corEmergencia,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Sair da conta?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: corPrimariaEscura,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancelar',
                            style: TextStyle(
                              color: corPrimariaEscura,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: corEmergencia,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Sair',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (sair != true) {
      return;
    }

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

  ImageProvider? _avatarProvider() {
    final foto = _fotoDataUrl;
    if (foto != null && foto.startsWith('data:')) {
      try {
        final base64Parte = foto.split(',').last;
        return MemoryImage(base64Decode(base64Parte));
      } catch (_) {}
    }
    if (foto != null && foto.startsWith('http')) {
      return NetworkImage(foto);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corFundo,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child:
                _carregando
                    ? _skeleton()
                    : _erro != null
                    ? _erroComRetry()
                    : _conteudo(),
          ),
          const BarraNavegacaoApp(ativa: AbaApp.perfil),
        ],
      ),
    );
  }

  Widget _skeleton() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkeletonBox(height: 110, width: 110, radius: 60),
            SizedBox(height: 16),
            SkeletonBox(height: 20, width: 160, radius: 8),
            SizedBox(height: 24),
            SkeletonBox(height: 52, radius: 14),
            SizedBox(height: 12),
            SkeletonBox(height: 52, radius: 14),
            SizedBox(height: 12),
            SkeletonBox(height: 52, radius: 14),
          ],
        ),
      ),
    );
  }

  Widget _erroComRetry() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_erro!, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _carregarPerfil,
              child: const Text('Recarregar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo() {
    final p = _perfil!;

    return SingleChildScrollView(
      child: Column(
        children: [
          _headerGradiente(p),
          ConteudoCentralizado(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  if (_salvoComSucesso)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF6EE7B7)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check, size: 18, color: Color(0xFF059669)),
                          SizedBox(width: 8),
                          Text(
                            'Perfil atualizado!',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _campoPerfil(
                    icone: Icons.badge_outlined,
                    rotulo: 'CPF',
                    valor: p.cpf,
                    controller: _cpfController,
                  ),
                  _campoPerfil(
                    icone: Icons.mail_outline,
                    rotulo: 'Email',
                    valor: p.email,
                    controller: _emailController,
                  ),
                  _campoPerfil(
                    icone: Icons.calendar_today_outlined,
                    rotulo: 'Data de nascimento',
                    valor: p.dataNascimento,
                    controller: _nascimentoController,
                    sufixo:
                        p.idade != null && !_editando
                            ? BadgeStatus(
                              texto: '${p.idade} anos',
                              cor: corPrimariaEscura,
                            )
                            : null,
                  ),
                  _campoPerfil(
                    icone: Icons.lock_outline,
                    rotulo: 'Senha',
                    valor: p.senha.isEmpty ? '••••••••' : '••••••••',
                    controller: _senhaController,
                    senha: true,
                  ),
                  _campoPerfil(
                    icone: Icons.phone_outlined,
                    rotulo: 'Número de telefone',
                    valor: p.telefone,
                    controller: _telefoneController,
                  ),
                  const SizedBox(height: 18),
                  const RotuloSecao('Endereço residencial'),
                  const SizedBox(height: 8),
                  _campoPerfil(
                    icone: Icons.location_on_outlined,
                    rotulo: 'CEP',
                    valor: p.cep,
                    controller: _cepController,
                  ),
                  _campoPerfil(
                    icone: Icons.home_outlined,
                    rotulo: 'Rua / Avenida',
                    valor: p.logradouro,
                    controller: _logradouroController,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _campoPerfil(
                          icone: Icons.tag,
                          rotulo: 'Número',
                          valor: p.numero,
                          controller: _numeroController,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _campoPerfil(
                          icone: Icons.map_outlined,
                          rotulo: 'Bairro',
                          valor: p.bairro,
                          controller: _bairroController,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _campoPerfil(
                          icone: Icons.location_city_outlined,
                          rotulo: 'Cidade',
                          valor: p.cidade,
                          controller: _cidadeController,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _campoPerfil(
                          icone: Icons.flag_outlined,
                          rotulo: 'UF',
                          valor: p.estado,
                          controller: _estadoController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const RotuloSecao('Informações clínicas'),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: sombraCard,
                        ),
                        child: const Text(
                          'OPCIONAL',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: corTextoCinzaClaro,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _campoPerfil(
                    icone: Icons.favorite_outline,
                    rotulo: 'Tipo Sanguíneo',
                    valor: p.tipoSanguineo,
                    dica: 'Ex: O+',
                    controller: _tipoSanguineoController,
                  ),
                  _campoPerfil(
                    icone: Icons.health_and_safety_outlined,
                    rotulo: 'Convênio Médico',
                    valor: p.convenio,
                    dica: 'Ex: Unimed',
                    controller: _convenioController,
                  ),
                  _campoPerfil(
                    icone: Icons.credit_card_outlined,
                    rotulo: 'Número do Cartão SUS',
                    valor: p.cartaoSus,
                    controller: _cartaoSusController,
                  ),
                  _campoPerfil(
                    icone: Icons.warning_amber_outlined,
                    rotulo: 'Restrições ou Alergias',
                    valor: p.alergias,
                    dica: 'Observações...',
                    controller: _alergiasController,
                    corIcone: corEmergencia,
                    maxLinhas: 3,
                  ),
                  const SizedBox(height: 18),
                  _cardCodigoVinculacao(p),
                  const SizedBox(height: 18),
                  if (_editando)
                    Row(
                      children: [
                        Expanded(
                          child: BotaoPrimario(
                            texto: 'Cancelar',
                            contorno: true,
                            cor: corPrimariaEscura,
                            onPressed: () => setState(() => _editando = false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BotaoPrimario(
                            texto: 'Salvar',
                            carregando: _salvando,
                            onPressed: _salvar,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    BotaoPrimario(
                      texto: 'Editar informações',
                      onPressed: _iniciarEdicao,
                    ),
                    const SizedBox(height: 10),
                    BotaoPrimario(
                      texto: 'Sair da conta',
                      contorno: true,
                      cor: corEmergencia,
                      icone: Icons.logout,
                      onPressed: _confirmarLogout,
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerGradiente(PerfilUsuario p) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: gradientePrimario,
        borderRadius: BorderRadius.vertical(bottom: Radius.elliptical(240, 44)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6F0F1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x24000000),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                      image: _avatarProvider() != null
                          ? DecorationImage(
                              image: _avatarProvider()!,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _avatarProvider() == null
                        ? const Center(
                            child: Icon(
                              Icons.person_rounded,
                              size: 64,
                              color: corPrimariaEscura,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _escolherFoto,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: corPrimariaEscura,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_editando)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: TextField(
                    controller: _nomeController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.2),
                      hintText: 'Seu nome',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        p.nome,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _iniciarEdicao,
                      child: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoPerfil({
    required IconData icone,
    required String rotulo,
    required String valor,
    required TextEditingController controller,
    String? dica,
    bool senha = false,
    Widget? sufixo,
    Color corIcone = corPrimariaEscura,
    int maxLinhas = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _editando ? corPrimaria : Colors.transparent,
            width: 2,
          ),
          boxShadow: sombraCard,
        ),
        child: Row(
          crossAxisAlignment:
              maxLinhas > 1
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
          children: [
            Icon(icone, size: 20, color: corIcone),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rotulo,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: corTextoCinzaClaro,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (_editando)
                    TextField(
                      controller: controller,
                      obscureText: senha,
                      maxLines: senha ? 1 : maxLinhas,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1F2937),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: dica,
                        hintStyle: const TextStyle(color: corTextoCinzaClaro),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  else
                    Text(
                      valor.isEmpty ? '—' : (senha ? '••••••••' : valor),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                ],
              ),
            ),
            if (sufixo != null) sufixo,
          ],
        ),
      ),
    );
  }

  Widget _cardCodigoVinculacao(PerfilUsuario p) {
    final codigo = p.codigoVinculacao;
    final codigoFormatado =
        codigo.length == 6
            ? '${codigo.substring(0, 3)} ${codigo.substring(3)}'
            : codigo;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: corPrimaria.withValues(alpha: 0.5), width: 2),
        boxShadow: sombraCard,
      ),
      child: Column(
        children: [
          const RotuloSecao('Código de vinculação (cuidador)'),
          const SizedBox(height: 8),
          Text(
            codigoFormatado.isEmpty ? '— — —' : codigoFormatado,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              color: corPrimariaEscura,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            codigo.isEmpty
                ? 'Código indisponível. Rode o SQL no Supabase para gerar.'
                : 'Forneça este código de segurança para o seu cuidador '
                    'ativar o monitoramento remoto.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
              color: corTextoCinzaClaro,
            ),
          ),
        ],
      ),
    );
  }
}
