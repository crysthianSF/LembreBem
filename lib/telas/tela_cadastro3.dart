import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lembrebem/backend/app_api.dart';
import 'package:lembrebem/backend/contatos_emergencia_api.dart';
import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/telas/tela_politicas_privacidade.dart';
import 'package:lembrebem/widgets/componentes.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tela_menu.dart';

class TelaCadastro3 extends StatefulWidget {
  const TelaCadastro3({super.key, required this.dadosCadastro});

  final Map<String, dynamic> dadosCadastro;

  @override
  State<TelaCadastro3> createState() => _TelaCadastro3State();
}

class _TelaCadastro3State extends State<TelaCadastro3> {
  final nomeController = TextEditingController();
  final telefoneController = TextEditingController();
  final AppApi _appApi = AppApi();
  final ContatosEmergenciaApi _contatosApi = ContatosEmergenciaApi();

  final telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  bool cadastrarDepois = false;
  bool aceitouPoliticas = false;
  bool _carregando = false;

  @override
  void dispose() {
    nomeController.dispose();
    telefoneController.dispose();
    super.dispose();
  }

  String? _dataBrParaIso(String? dataBr) {
    if (dataBr == null || dataBr.isEmpty) {
      return null;
    }
    final partes = dataBr.split('/');
    if (partes.length != 3) {
      return null;
    }
    return '${partes[2]}-${partes[1].padLeft(2, '0')}-'
        '${partes[0].padLeft(2, '0')}';
  }

  Future<void> _finalizarCadastro() async {
    if (_carregando) {
      return;
    }

    if (!aceitouPoliticas) {
      _mostrarErro(
        'Você precisa aceitar as Políticas de Privacidade para continuar.',
      );
      return;
    }

    final temContato =
        nomeController.text.trim().isNotEmpty ||
        telefoneController.text.trim().isNotEmpty;
    if (!cadastrarDepois && !temContato) {
      _mostrarErro(
        'Preencha o contato de confiança ou marque '
        '"Cadastrar contato mais tarde".',
      );
      return;
    }

    setState(() => _carregando = true);

    final email = widget.dadosCadastro['email']?.toString().trim() ?? '';
    final senha = widget.dadosCadastro['senha']?.toString() ?? '';
    final nome = widget.dadosCadastro['nome']?.toString().trim() ?? '';

    try {
      final resposta = await SupabaseBackend.client.auth
          .signUp(email: email, password: senha, data: {'name': nome})
          .timeout(const Duration(seconds: 15));

      if (resposta.user == null) {
        throw StateError('Nao foi possivel criar a conta.');
      }
      try {
        await _appApi.ensureUsuarioAtual();
        await _appApi.salvarUsuarioAtual(
          payload: {
            'nome': nome,
            'cpf': widget.dadosCadastro['cpf']?.toString().replaceAll(
              RegExp(r'[^0-9]'),
              '',
            ),
            'data_nascimento': _dataBrParaIso(
              widget.dadosCadastro['dataNascimento']?.toString(),
            ),
            'telefone': widget.dadosCadastro['telefone'],
            'cep': widget.dadosCadastro['cep'],
            'logradouro': widget.dadosCadastro['rua'],
            'numero': widget.dadosCadastro['numero'],
            'cidade': widget.dadosCadastro['cidade'],
            'estado': widget.dadosCadastro['estado'],
          },
        );
      } catch (_) {}
      if (temContato && !cadastrarDepois) {
        try {
          final user = SupabaseBackend.client.auth.currentUser;
          if (user != null) {
            await _contatosApi.salvarContato(
              usuarioId: user.id,
              nome: nomeController.text.trim(),
              telefone: telefoneController.text.trim(),
            );
          }
        } catch (_) {}
      }

      if (!mounted) {
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const TelaMenu()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      _mostrarErro(_mensagemErro(e));
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  String _mensagemErro(Object erro) {
    final texto = erro.toString().toLowerCase();
    if (erro is TimeoutException || texto.contains('timeout')) {
      return 'Tempo de resposta excedido. Verifique sua internet.';
    }
    if (erro is AuthException) {
      if (texto.contains('already registered') ||
          texto.contains('already exists')) {
        return 'Este email já possui cadastro. Faça login.';
      }
      if (texto.contains('password')) {
        return 'Senha não atende aos requisitos do servidor.';
      }
      if (texto.contains('invalid') && texto.contains('email')) {
        return 'Email inválido.';
      }
    }
    return 'Erro ao criar a conta. Tente novamente.';
  }

  void _mostrarErro(String mensagem) {
    showDialog<void>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Atenção'),
            content: Text(mensagem),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: FundoDecorado(
        child: ConteudoCentralizado(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: LinkVoltar(onTap: () => Navigator.pop(context)),
                ),
                Center(
                  child: Image.asset(
                    'assets/images/logo_lembrebem.png',
                    height: 150,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Passo 3: Contatos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: corPrimariaEscura,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Adicione um contato de confiança que será notificado '
                  'em caso de emergência.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: corTextoCinza,
                  ),
                ),
                const SizedBox(height: 24),
                CampoComIcone(
                  controller: nomeController,
                  rotulo: 'Nome',
                  dica: 'Nome do contato',
                  icone: Icons.person_outline,
                ),
                const SizedBox(height: 14),
                CampoComIcone(
                  controller: telefoneController,
                  rotulo: 'Número de telefone',
                  dica: '(00) 00000-0000',
                  icone: Icons.phone_outlined,
                  teclado: TextInputType.phone,
                  formatadores: [telefoneFormatter],
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: cadastrarDepois,
                  onChanged: (value) {
                    setState(() => cadastrarDepois = value ?? false);
                  },
                  title: const Text(
                    'Cadastrar contato mais tarde',
                    style: TextStyle(fontSize: 14, color: corTextoEscuro),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: corPrimaria,
                  contentPadding: EdgeInsets.zero,
                  checkboxShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                CheckboxListTile(
                  value: aceitouPoliticas,
                  onChanged: (value) {
                    setState(() => aceitouPoliticas = value ?? false);
                  },
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Li e concordo com as ',
                        style: TextStyle(fontSize: 14, color: corTextoEscuro),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TelaPoliticasPrivacidade(),
                            ),
                          );
                        },
                        child: const Text(
                          'Políticas de Privacidade.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: corPrimariaEscura,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: corPrimaria,
                  contentPadding: EdgeInsets.zero,
                  checkboxShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 20),
                BotaoPrimario(
                  texto: 'Finalizar cadastro',
                  carregando: _carregando,
                  onPressed: _finalizarCadastro,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
