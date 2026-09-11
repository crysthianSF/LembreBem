import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/widgets/componentes.dart';

Finder campo(String rotulo) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is CampoComIcone && widget.rotulo == rotulo,
    description: 'CampoComIcone com rótulo "$rotulo"',
  ),
  matching: find.byType(TextFormField),
);

Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

Future<void> preencher(WidgetTester tester, String rotulo, String valor) async {
  final alvo = campo(rotulo);
  await tester.ensureVisible(alvo);
  await tester.enterText(alvo, valor);
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

Future<void> preencherDadosPessoais(WidgetTester tester) async {
  await preencher(tester, 'Nome completo *', 'Pessoa Teste');
  await preencher(tester, 'CPF *', '12345678901');
  await preencher(tester, 'Email', 'pessoa@example.com');
  await preencher(tester, 'Data de nascimento *', '01021990');
  await preencher(tester, 'Senha *', 'Teste1234');
}
