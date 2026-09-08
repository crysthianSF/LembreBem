import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/widgets/componentes.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import 'tela_cadastro3.dart';

class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 5) {
      text = '${text.substring(0, 5)}-${text.substring(5)}';
    }
    if (text.length > 9) {
      text = text.substring(0, 9);
    }
    return newValue.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class TelaCadastro2 extends StatefulWidget {
  const TelaCadastro2({super.key, required this.dadosCadastro});

  final Map<String, dynamic> dadosCadastro;

  @override
  State<TelaCadastro2> createState() => _TelaCadastro2State();
}

class _TelaCadastro2State extends State<TelaCadastro2> {
  final _formKey = GlobalKey<FormState>();
  final telefoneController = TextEditingController();
  final cidadeController = TextEditingController();
  final ruaController = TextEditingController();
  final numeroController = TextEditingController();
  final cepController = TextEditingController();

  String? estadoSelecionado;
  static const List<String> estados = [
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO',
  ];

  final telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void dispose() {
    telefoneController.dispose();
    cidadeController.dispose();
    ruaController.dispose();
    numeroController.dispose();
    cepController.dispose();
    super.dispose();
  }

  void finalizarCadastro2() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    widget.dadosCadastro['telefone'] = telefoneController.text;
    widget.dadosCadastro['estado'] = estadoSelecionado;
    widget.dadosCadastro['cidade'] = cidadeController.text.trim();
    widget.dadosCadastro['rua'] = ruaController.text.trim();
    widget.dadosCadastro['numero'] = numeroController.text.trim();
    widget.dadosCadastro['cep'] = cepController.text;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TelaCadastro3(dadosCadastro: widget.dadosCadastro),
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
                  Center(
                    child: Image.asset(
                      'assets/images/logo_lembrebem.png',
                      height: 150,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Passo 2: Endereço e Contato.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: corPrimariaEscura,
                    ),
                  ),
                  const SizedBox(height: 24),
                  CampoComIcone(
                    controller: telefoneController,
                    rotulo: 'Número de telefone *',
                    dica: '(00) 00000-0000',
                    icone: Icons.phone_outlined,
                    teclado: TextInputType.phone,
                    formatadores: [telefoneFormatter],
                    validador: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Este campo é obrigatório.';
                      }
                      if (telefoneFormatter.getUnmaskedText().length != 11) {
                        return 'Digite um telefone válido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estado *',
                        style: TextStyle(
                          color: corPrimariaEscura,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: estadoSelecionado,
                        hint: const Text(
                          'Selecione',
                          style: TextStyle(color: corTextoCinzaClaro),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                              width: 2,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: corPrimaria,
                              width: 2,
                            ),
                          ),
                        ),
                        items:
                            estados
                                .map(
                                  (estado) => DropdownMenuItem<String>(
                                    value: estado,
                                    child: Text(estado),
                                  ),
                                )
                                .toList(),
                        onChanged: (novoEstado) {
                          setState(() => estadoSelecionado = novoEstado);
                        },
                        validator:
                            (value) =>
                                value == null ? 'Selecione um estado.' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CampoComIcone(
                    controller: cidadeController,
                    rotulo: 'Cidade *',
                    dica: 'Sua cidade',
                    icone: Icons.location_city_outlined,
                    validador: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Este campo é obrigatório.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  CampoComIcone(
                    controller: ruaController,
                    rotulo: 'Rua *',
                    dica: 'Nome da rua',
                    icone: Icons.home_outlined,
                    validador: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Este campo é obrigatório.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CampoComIcone(
                          controller: numeroController,
                          rotulo: 'Número *',
                          dica: '123',
                          teclado: TextInputType.number,
                          formatadores: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validador: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Obrigatório.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: CampoComIcone(
                          controller: cepController,
                          rotulo: 'CEP *',
                          dica: '00000-000',
                          teclado: TextInputType.number,
                          formatadores: [
                            FilteringTextInputFormatter.digitsOnly,
                            CepInputFormatter(),
                          ],
                          validador: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Obrigatório.';
                            }
                            if (!RegExp(r"^\d{5}-\d{3}$").hasMatch(value)) {
                              return 'CEP inválido.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  BotaoPrimario(
                    texto: 'Próximo',
                    onPressed: finalizarCadastro2,
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
