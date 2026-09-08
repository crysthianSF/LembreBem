import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lembrebem/backend/cuidador_api.dart';
import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/telas/tela_cuidador_painel.dart';
import 'package:lembrebem/telas/tela_login.dart';
import 'package:lembrebem/widgets/componentes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TelaCadastroCuidador extends StatefulWidget {
  const TelaCadastroCuidador({super.key});

  @override
  State<TelaCadastroCuidador> createState() => _TelaCadastroCuidadorState();
}

class _TelaCadastroCuidadorState extends State<TelaCadastroCuidador> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _registroController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final CuidadorApi _cuidadorApi = CuidadorApi();

  bool _carregando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _registroController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _criarConta() async {
    if (_carregando || !_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _carregando = true);

    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    final registro = _registroController.text.trim();

    try {
      final resposta = await SupabaseBackend.client.auth
          .signUp(email: email, password: senha, data: {'name': nome})
          .timeout(const Duration(seconds: 15));

      if (resposta.user == null) {
        throw StateError('Nao foi possivel criar a conta.');
      }

      await _cuidadorApi.registrarCuidador(
        nome: nome,
        email: email,
        registroProfissional: registro.isEmpty ? null : registro,
      );

      if (!mounted) {
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const TelaCuidadorPainel()),
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
        return 'Senha fraca. Use pelo menos 6 caracteres.';
      }
    }
    if (texto.contains('cuidadores')) {
      return 'Tabela de cuidadores não encontrada. Rode o SQL '
          '(sql/prototipo_novas_tabelas.sql) no Supabase.';
    }
    return 'Erro ao criar conta. Tente novamente.';
  }

  void _mostrarErro(String mensagem) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: FundoDecorado(
        child: ConteudoCentralizado(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: LinkVoltar(onTap: () => Navigator.pop(context)),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Image.asset(
                      'assets/images/logo_lembrebem.png',
                      height: 130,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cadastro de Cuidador',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: corPrimariaEscura,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Preencha seus dados para continuar',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: corTextoCinza),
                  ),
                  const SizedBox(height: 24),
                  CampoComIcone(
                    controller: _nomeController,
                    rotulo: 'Nome completo',
                    dica: 'Seu nome completo',
                    icone: Icons.person_outline,
                    validador:
                        (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Informe seu nome.'
                                : null,
                  ),
                  const SizedBox(height: 16),
                  CampoComIcone(
                    controller: _registroController,
                    rotulo: 'COREN / CRM (opcional)',
                    dica: 'Ex: COREN-SP 000000',
                    icone: Icons.verified_outlined,
                  ),
                  const SizedBox(height: 16),
                  CampoComIcone(
                    controller: _emailController,
                    rotulo: 'E-mail',
                    dica: 'seu@email.com',
                    icone: Icons.mail_outline,
                    teclado: TextInputType.emailAddress,
                    validador: (v) {
                      final valor = v?.trim() ?? '';
                      if (valor.isEmpty) {
                        return 'Informe seu e-mail.';
                      }
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(valor)) {
                        return 'E-mail inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CampoComIcone(
                    controller: _senhaController,
                    rotulo: 'Senha',
                    dica: 'Mínimo 6 caracteres',
                    icone: Icons.lock_outline,
                    senha: true,
                    validador:
                        (v) =>
                            (v == null || v.length < 6)
                                ? 'Mínimo de 6 caracteres'
                                : null,
                  ),
                  const SizedBox(height: 28),
                  BotaoPrimario(
                    texto: 'Criar conta de cuidador',
                    carregando: _carregando,
                    onPressed: _criarConta,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Já tem uma conta? ',
                        style: TextStyle(fontSize: 14, color: corTextoCinza),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TelaLogin(),
                            ),
                          );
                        },
                        child: const Text(
                          'Entrar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: corPrimariaEscura,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
