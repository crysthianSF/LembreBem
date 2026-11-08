import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lembrebem/backend/auth_api.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/widgets/componentes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum EtapaRecuperacao {
  solicitarEmail,
  validarCodigo,
  novaSenha,
}

class TelaRedefinirSenha extends StatefulWidget {
  const TelaRedefinirSenha({super.key});

  @override
  State<TelaRedefinirSenha> createState() => _TelaRedefinirSenhaState();
}

class _TelaRedefinirSenhaState extends State<TelaRedefinirSenha> {
  final AuthApi _authApi = AuthApi();

  EtapaRecuperacao _etapaAtual = EtapaRecuperacao.solicitarEmail;

  final _formKeyEmail = GlobalKey<FormState>();
  final _formKeyCodigo = GlobalKey<FormState>();
  final _formKeySenha = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();

  bool _carregando = false;
  String? _mensagemErro;

  // Rate Limiting Progressivo (60s -> 120s -> 240s ...)
  Timer? _timerCooldown;
  int _segundosRestantes = 0;
  int _proximoCooldown = 60;

  @override
  void dispose() {
    _timerCooldown?.cancel();
    _emailController.dispose();
    _codigoController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  void _iniciarCooldown() {
    _timerCooldown?.cancel();
    setState(() {
      _segundosRestantes = _proximoCooldown;
      _proximoCooldown *= 2; // escalona: 60s -> 120s -> 240s...
    });

    _timerCooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_segundosRestantes > 1) {
        setState(() {
          _segundosRestantes--;
        });
      } else {
        timer.cancel();
        setState(() {
          _segundosRestantes = 0;
        });
      }
    });
  }

  // ETAPA 1: Enviar código para o e-mail
  Future<void> _solicitarCodigo() async {
    if (_carregando || !_formKeyEmail.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    final email = _emailController.text.trim();

    try {
      await _authApi.solicitarCodigoRecuperacao(email);
    } catch (_) {
      // Falha tratada silenciosamente para preservar anti-enumeração
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
          _etapaAtual = EtapaRecuperacao.validarCodigo;
        });
        _iniciarCooldown();
      }
    }
  }

  // ETAPA 2: Reenviar código com cooldown
  Future<void> _reenviarCodigo() async {
    if (_segundosRestantes > 0 || _carregando) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    final email = _emailController.text.trim();

    try {
      await _authApi.solicitarCodigoRecuperacao(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código reenviado com sucesso!'),
            backgroundColor: corPrimariaEscura,
          ),
        );
      }
    } catch (_) {
      // Preserva anti-enumeração
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
        _iniciarCooldown();
      }
    }
  }

  // ETAPA 2: Validar o código OTP de 6 dígitos
  Future<void> _validarCodigo() async {
    if (_carregando || !_formKeyCodigo.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    final email = _emailController.text.trim();
    final codigo = _codigoController.text.trim();

    try {
      final resposta = await _authApi.verificarCodigoRecuperacao(
        email: email,
        codigo: codigo,
      );

      if (!mounted) return;

      if (resposta.session != null || resposta.user != null) {
        setState(() {
          _etapaAtual = EtapaRecuperacao.novaSenha;
          _mensagemErro = null;
        });
      } else {
        setState(() {
          _mensagemErro = 'Código incorreto ou expirado. Tente novamente.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensagemErro = 'Código incorreto ou expirado. Verifique e tente novamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  // ETAPA 3: Salvar a nova senha
  Future<void> _salvarNovaSenha() async {
    if (_carregando || !_formKeySenha.currentState!.validate()) {
      return;
    }

    final senha = _senhaController.text;
    if (!_validarTodosCriterios(senha)) {
      setState(() {
        _mensagemErro = 'A senha não atende a todos os critérios de segurança.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      await _authApi.atualizarSenha(senha);

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: corSucesso, size: 28),
              SizedBox(width: 8),
              Text('Senha redefinida!'),
            ],
          ),
          content: const Text(
            'Sua nova senha foi gravada com sucesso. Você já pode fazer login na sua conta.',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // fecha o diálogo
                Navigator.pop(context); // volta para a tela de login
              },
              child: const Text(
                'Ir para o Login',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: corPrimariaEscura,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensagemErro = 'Não foi possível atualizar a senha. Tente novamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _carregando = false;
        });
      }
    }
  }

  // Validações de critérios de senha
  bool _validarMinimo(String senha) => senha.length >= 8;
  bool _validarMaiuscula(String senha) => senha.contains(RegExp(r'[A-Z]'));
  bool _validarMinuscula(String senha) => senha.contains(RegExp(r'[a-z]'));
  bool _validarNumero(String senha) => senha.contains(RegExp(r'[0-9]'));

  bool _validarTodosCriterios(String senha) {
    return _validarMinimo(senha) &&
        _validarMaiuscula(senha) &&
        _validarMinuscula(senha) &&
        _validarNumero(senha);
  }

  Widget _criterio(String texto, bool valido) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          valido ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 14,
          color: valido ? corSucesso : corTextoCinzaClaro,
        ),
        const SizedBox(width: 4),
        Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            color: valido ? corSucesso : corTextoCinza,
            fontWeight: valido ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: FundoDecorado(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoAltura = constraints.maxHeight < 720 ? 120.0 : 160.0;

            return ConteudoCentralizado(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: corPrimariaEscura),
                          onPressed: () {
                            if (_etapaAtual == EtapaRecuperacao.validarCodigo) {
                              setState(() {
                                _etapaAtual = EtapaRecuperacao.solicitarEmail;
                                _mensagemErro = null;
                              });
                            } else {
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
                      const SizedBox(height: 16),
                      if (_etapaAtual == EtapaRecuperacao.solicitarEmail)
                        _construirEtapaEmail()
                      else if (_etapaAtual == EtapaRecuperacao.validarCodigo)
                        _construirEtapaCodigo()
                      else
                        _construirEtapaNovaSenha(),
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

  // WIDGET: Etapa 1 - Solicitar E-mail
  Widget _construirEtapaEmail() {
    return Form(
      key: _formKeyEmail,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Recuperar Senha',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: corPrimariaEscura,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Informe o e-mail cadastrado. Caso esteja registrado no sistema, enviaremos um código de 6 dígitos para redefinir sua senha.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: corTextoCinza),
          ),
          const SizedBox(height: 24),
          CampoComIcone(
            controller: _emailController,
            rotulo: 'E-mail cadastrado',
            dica: 'seu@email.com',
            icone: Icons.mail_outline,
            teclado: TextInputType.emailAddress,
            validador: (value) {
              final val = value?.trim() ?? '';
              if (val.isEmpty) {
                return 'Informe o seu e-mail.';
              }
              if (!RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(val)) {
                return 'Digite um e-mail válido.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          BotaoPrimario(
            texto: 'Enviar código',
            carregando: _carregando,
            onPressed: _solicitarCodigo,
          ),
        ],
      ),
    );
  }

  // WIDGET: Etapa 2 - Código de 6 dígitos
  Widget _construirEtapaCodigo() {
    final minutos = (_segundosRestantes ~/ 60).toString().padLeft(2, '0');
    final segundos = (_segundosRestantes % 60).toString().padLeft(2, '0');

    return Form(
      key: _formKeyCodigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Verificação de Código',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: corPrimariaEscura,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Se o e-mail ${_emailController.text.trim()} estiver cadastrado, um código de 6 dígitos foi enviado para ele.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: corTextoCinza),
          ),
          const SizedBox(height: 24),
          CampoComIcone(
            controller: _codigoController,
            rotulo: 'Código de 6 dígitos',
            dica: '123456',
            icone: Icons.security_outlined,
            teclado: TextInputType.number,
            formatadores: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validador: (value) {
              final val = value?.trim() ?? '';
              if (val.isEmpty) {
                return 'Digite o código recebido.';
              }
              if (val.length != 6) {
                return 'O código deve ter 6 dígitos.';
              }
              return null;
            },
          ),
          if (_mensagemErro != null) ...[
            const SizedBox(height: 10),
            Text(
              _mensagemErro!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: corEmergencia,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          BotaoPrimario(
            texto: 'Verificar código',
            carregando: _carregando,
            onPressed: _validarCodigo,
          ),
          const SizedBox(height: 16),
          Center(
            child: _segundosRestantes > 0
                ? Text(
                    'Reenviar código em $minutos:$segundos',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: corTextoCinza,
                    ),
                  )
                : TextButton(
                    onPressed: _carregando ? null : _reenviarCodigo,
                    child: const Text(
                      'Reenviar código',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: corPrimariaEscura,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // WIDGET: Etapa 3 - Nova Senha
  Widget _construirEtapaNovaSenha() {
    final senha = _senhaController.text;

    return Form(
      key: _formKeySenha,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Criar Nova Senha',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: corPrimariaEscura,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Defina uma nova senha que atenda aos critérios de segurança.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: corTextoCinza),
          ),
          const SizedBox(height: 24),
          CampoComIcone(
            controller: _senhaController,
            rotulo: 'Nova senha *',
            dica: '••••••••',
            icone: Icons.lock_outline,
            senha: true,
            aoMudar: (_) => setState(() {}),
            validador: (value) {
              if (value == null || value.isEmpty) {
                return 'Este campo é obrigatório.';
              }
              if (!_validarTodosCriterios(value)) {
                return 'A senha não atende aos critérios abaixo.';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _criterio('8 caracteres', _validarMinimo(senha)),
              _criterio('Maiúscula', _validarMaiuscula(senha)),
              _criterio('Minúscula', _validarMinuscula(senha)),
              _criterio('Número', _validarNumero(senha)),
            ],
          ),
          const SizedBox(height: 16),
          CampoComIcone(
            controller: _confirmarSenhaController,
            rotulo: 'Confirmar nova senha *',
            dica: '••••••••',
            icone: Icons.lock_outline,
            senha: true,
            validador: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirme sua nova senha.';
              }
              if (value != _senhaController.text) {
                return 'As senhas não coincidem.';
              }
              return null;
            },
          ),
          if (_mensagemErro != null) ...[
            const SizedBox(height: 10),
            Text(
              _mensagemErro!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: corEmergencia,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 24),
          BotaoPrimario(
            texto: 'Salvar nova senha',
            carregando: _carregando,
            onPressed: _salvarNovaSenha,
          ),
        ],
      ),
    );
  }
}

