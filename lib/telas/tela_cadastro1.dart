import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/widgets/componentes.dart';

import 'tela_cadastro2.dart';

class DataNascimentoInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (text.length >= 3 && text.length <= 4) {
      text = '${text.substring(0, 2)}/${text.substring(2)}';
    } else if (text.length > 4) {
      text =
          '${text.substring(0, 2)}/${text.substring(2, 4)}/${text.substring(4)}';
    }

    if (text.length > 10) {
      text = text.substring(0, 10);
    }

    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (text.length >= 4 && text.length <= 6) {
      text = '${text.substring(0, 3)}.${text.substring(3)}';
    } else if (text.length >= 7 && text.length <= 9) {
      text =
          '${text.substring(0, 3)}.${text.substring(3, 6)}.'
          '${text.substring(6)}';
    } else if (text.length > 9) {
      text =
          '${text.substring(0, 3)}.${text.substring(3, 6)}.'
          '${text.substring(6, 9)}-${text.substring(9)}';
    }

    if (text.length > 14) {
      text = text.substring(0, 14);
    }

    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class TelaCadastro1 extends StatefulWidget {
  const TelaCadastro1({super.key});

  @override
  State<TelaCadastro1> createState() => _TelaCadastro1State();
}

class _TelaCadastro1State extends State<TelaCadastro1> {
  final _formKey = GlobalKey<FormState>();
  final nomeController = TextEditingController();
  final cpfController = TextEditingController();
  final emailController = TextEditingController();
  final dataNascimentoController = TextEditingController();
  final senhaController = TextEditingController();

  @override
  void dispose() {
    nomeController.dispose();
    cpfController.dispose();
    emailController.dispose();
    dataNascimentoController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  void avancarCadastro(BuildContext context) {
    final dadosCadastro = <String, dynamic>{
      'nome': nomeController.text,
      'cpf': cpfController.text,
      'email': emailController.text,
      'dataNascimento': dataNascimentoController.text,
      'senha': senhaController.text,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TelaCadastro2(dadosCadastro: dadosCadastro),
      ),
    );
  }

  bool validarMinimo(String senha) => senha.length >= 8;
  bool validarMaiuscula(String senha) => senha.contains(RegExp(r'[A-Z]'));
  bool validarMinuscula(String senha) => senha.contains(RegExp(r'[a-z]'));
  bool validarNumero(String senha) => senha.contains(RegExp(r'[0-9]'));

  Widget _criterio(String texto, bool valido) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          valido ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: valido ? corSucesso : corEmergencia,
        ),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 12, color: corTextoCinza)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final senha = senhaController.text;

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
                  Center(
                    child: Image.asset(
                      'assets/images/logo_lembrebem.png',
                      height: 150,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Passo 1: Suas informações.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: corPrimariaEscura,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CampoComIcone(
                    controller: nomeController,
                    rotulo: 'Nome completo *',
                    dica: 'Seu nome completo',
                    icone: Icons.person_outline,
                    validador: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Este campo é obrigatório.';
                      }
                      if (!RegExp(r"^[a-zA-ZÀ-ÿ\s]+$").hasMatch(value)) {
                        return 'Digite um nome válido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  CampoComIcone(
                    controller: cpfController,
                    rotulo: 'CPF *',
                    dica: '000.000.000-00',
                    icone: Icons.badge_outlined,
                    teclado: TextInputType.number,
                    formatadores: [CpfInputFormatter()],
                    validador: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Este campo é obrigatório.';
                      }
                      final cpf = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (cpf.length != 11) {
                        return 'Digite um CPF válido (11 números).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  CampoComIcone(
                    controller: emailController,
                    rotulo: 'Email',
                    dica: 'seu@email.com',
                    icone: Icons.mail_outline,
                    teclado: TextInputType.emailAddress,
                    validador: (value) {
                      final valor = value?.trim() ?? '';
                      if (valor.isEmpty) {
                        return 'Este campo é obrigatório.';
                      }
                      if (!RegExp(
                        r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$",
                      ).hasMatch(valor)) {
                        return 'Digite um email válido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  CampoComIcone(
                    controller: dataNascimentoController,
                    rotulo: 'Data de nascimento *',
                    dica: 'dd/mm/aaaa',
                    icone: Icons.calendar_today_outlined,
                    teclado: TextInputType.datetime,
                    formatadores: [DataNascimentoInputFormatter()],
                    validador: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Este campo é obrigatório.';
                      }
                      if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(value)) {
                        return 'Digite uma data válida (dd/mm/aaaa).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  CampoComIcone(
                    controller: senhaController,
                    rotulo: 'Senha *',
                    dica: '••••••••',
                    icone: Icons.lock_outline,
                    senha: true,
                    aoMudar: (_) => setState(() {}),
                    validador: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Este campo é obrigatório.';
                      }
                      if (!validarMinimo(value) ||
                          !validarMaiuscula(value) ||
                          !validarMinuscula(value) ||
                          !validarNumero(value)) {
                        return 'A senha não atende aos critérios abaixo.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _criterio('8 caracteres', validarMinimo(senha)),
                      _criterio('Maiúscula', validarMaiuscula(senha)),
                      _criterio('Minúscula', validarMinuscula(senha)),
                      _criterio('Número', validarNumero(senha)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  BotaoPrimario(
                    texto: 'Próximo',
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        avancarCadastro(context);
                      }
                    },
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
