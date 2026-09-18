import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lembrebem/backend/auth_api.dart';
import 'package:lembrebem/backend/cuidador_api.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/telas/tela_cuidador_painel.dart';
import 'package:lembrebem/telas/tela_selecao_perfil.dart';
import 'package:lembrebem/widgets/componentes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tela_menu.dart';

class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final AuthApi _authApi = AuthApi();
  final CuidadorApi _cuidadorApi = CuidadorApi();

  bool _carregando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_carregando || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _carregando = true;
    });

    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    try {
      final user = await _authApi.loginComEmailSenha(
        email: email,
        senha: senha,
      );
      if (!mounted) {
        return;
      }

      if (user == null) {
        _mostrarDialogoErro(
          'Nao foi possivel autenticar. Verifique seus dados.',
        );
        return;
      }
      var ehCuidador = false;
      try {
        ehCuidador = await _cuidadorApi.buscarCuidadorAtual() != null;
      } catch (_) {}

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => ehCuidador ? const TelaCuidadorPainel() : const TelaMenu(),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      _mostrarDialogoErro(_mensagemErroAutenticacao(e));
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  String _mensagemErroAutenticacao(Object erro) {
    if (erro is TimeoutException) {
      return 'Tempo de resposta excedido. Verifique sua internet e tente novamente.';
    }

    final texto = erro.toString();
    final lower = texto.toLowerCase();

    if (erro is AuthException) {
      if (lower.contains('invalid login credentials') ||
          lower.contains('invalid_credentials')) {
        return 'Email ou senha incorretos.';
      }
      if (lower.contains('email not confirmed')) {
        return 'Confirme seu email antes de entrar.';
      }
      if (lower.contains('user not found')) {
        return 'Usuario nao encontrado.';
      }
    }

    if (texto.contains('Invalid API key') ||
        texto.contains('statusCode: 401')) {
      return 'Chave publica do Supabase invalida ou de outro projeto.';
    }
    if (texto.contains('PGRST106') || texto.contains('Invalid schema: app')) {
      return 'Schema "app" nao esta exposto na API do Supabase.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('network')) {
      return 'Sem internet no momento. Verifique sua conexao.';
    }
    if (lower.contains('timeout')) {
      return 'Tempo de resposta excedido. Tente novamente.';
    }
    return 'Erro ao autenticar. Tente novamente.';
  }

  void _mostrarDialogoErro(String mensagem) {
    showDialog<void>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Erro'),
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

  void _esqueciSenha() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Entre em contato com o suporte para redefinir sua senha.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: FundoDecorado(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tecladoAltura = MediaQuery.of(context).viewInsets.bottom;
            final logoAltura = constraints.maxHeight < 720 ? 160.0 : 210.0;

            return ConteudoCentralizado(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + tecladoAltura),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: LinkVoltar(
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                      Center(
                        child: Image.asset(
                          'assets/images/logo_lembrebem.png',
                          height: logoAltura,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Bem-vindo de volta!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: corPrimariaEscura,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Entre com seus dados para continuar',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: corTextoCinza),
                      ),
                      const SizedBox(height: 28),
                      CampoComIcone(
                        controller: _emailController,
                        rotulo: 'E-mail',
                        dica: 'seu@email.com',
                        icone: Icons.mail_outline,
                        teclado: TextInputType.emailAddress,
                        validador: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Este campo é obrigatório.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CampoComIcone(
                        controller: _senhaController,
                        rotulo: 'Senha',
                        dica: '••••••••',
                        icone: Icons.lock_outline,
                        senha: true,
                        validador: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Este campo é obrigatório.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _esqueciSenha,
                          child: const Text(
                            'Esqueci minha senha',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: corPrimariaEscura,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      BotaoPrimario(
                        texto: 'Entrar',
                        carregando: _carregando,
                        onPressed: _login,
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Não tem uma conta? ',
                            style: TextStyle(
                              fontSize: 14,
                              color: corTextoCinza,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TelaSelecaoPerfil(),
                                ),
                              );
                            },
                            child: const Text(
                              'Cadastre-se',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: corPrimariaEscura,
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
          },
        ),
      ),
    );
  }
}
