import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/main.dart';
import 'package:lembrebem/telas/tela_login.dart';
import 'package:lembrebem/telas/tela_selecao_perfil.dart';

void main() {
  testWidgets('A tela inicial abre o login', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Gerencie os seus medicamentos'), findsOneWidget);
    await tester.ensureVisible(find.text('Fazer login'));
    await tester.tap(find.text('Fazer login'));
    await tester.pumpAndSettle();
    expect(find.byType(TelaLogin), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('O cadastro permite selecionar o perfil', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.ensureVisible(find.text('Fazer cadastro'));
    await tester.tap(find.text('Fazer cadastro'));
    await tester.pumpAndSettle();
    expect(find.byType(TelaSelecaoPerfil), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Falhas na inicializacao exibem uma tela de erro', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp(startupError: 'Falha de conexao'));
    expect(find.textContaining('Falha de conexao'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
