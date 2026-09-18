import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/telas/tela_cadastro1.dart';
import 'package:lembrebem/telas/tela_cadastro2.dart';
import 'package:lembrebem/telas/tela_login.dart';

import '../support/interacoes.dart';

void main() {
  testWidgets('Login vazio mostra os campos obrigatórios e permanece na tela', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TelaLogin()));
    await tocar(tester, find.text('Entrar'));

    expect(find.text('Este campo é obrigatório.'), findsNWidgets(2));
    expect(find.byType(TelaLogin), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A senha pode ser revelada e ocultada sem perder seu valor', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TelaLogin()));
    await preencher(tester, 'Senha', 'Teste1234');
    final senha = find.descendant(
      of: campo('Senha'),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(senha).obscureText, isTrue);

    await tocar(tester, find.byIcon(Icons.visibility_outlined));
    expect(tester.widget<EditableText>(senha).obscureText, isFalse);
    expect(tester.widget<EditableText>(senha).controller.text, 'Teste1234');

    await tocar(tester, find.byIcon(Icons.visibility_off_outlined));
    expect(tester.widget<EditableText>(senha).obscureText, isTrue);
  });

  testWidgets('Cadastro vazio não avança para o endereço', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TelaCadastro1()));
    await tocar(tester, find.text('Próximo'));

    expect(find.text('Este campo é obrigatório.'), findsNWidgets(5));
    expect(find.byType(TelaCadastro2), findsNothing);
  });

  testWidgets('Cadastro recusa email inválido e senha fraca', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TelaCadastro1()));
    await preencherDadosPessoais(tester);
    await preencher(tester, 'Email', 'email-invalido');
    await preencher(tester, 'Senha *', 'abc');
    await tocar(tester, find.text('Próximo'));

    expect(find.text('Digite um email válido.'), findsOneWidget);
    expect(
      find.text('A senha não atende aos critérios abaixo.'),
      findsOneWidget,
    );
    expect(find.byType(TelaCadastro2), findsNothing);
  });
}
