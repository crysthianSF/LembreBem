import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/telas/tela_cadastro1.dart';
import 'package:lembrebem/telas/tela_cadastro2.dart';
import 'package:lembrebem/telas/tela_cadastro_cuidador.dart';
import 'package:lembrebem/telas/tela_login.dart';

import 'interacoes.dart';

Future<void> validarFluxoInicialECadastro(WidgetTester tester) async {
  expect(find.text('Gerencie os seus medicamentos'), findsOneWidget);

  await tocar(tester, find.text('Fazer login'));
  await tocar(tester, find.text('Entrar'));
  expect(find.text('Este campo é obrigatório.'), findsNWidgets(2));
  expect(find.byType(TelaLogin), findsOneWidget);
  await tocar(tester, find.text('Esqueci minha senha'));
  expect(
    find.text('Entre em contato com o suporte para redefinir sua senha.'),
    findsOneWidget,
  );
  await tester.drag(find.byType(SnackBar), const Offset(0, 100));
  await tester.pumpAndSettle();
  expect(find.byType(SnackBar), findsNothing);

  await tocar(tester, find.text('Cadastre-se'));
  await tocar(tester, find.text('Sou Paciente'));
  expect(find.byType(TelaCadastro1), findsOneWidget);
  await preencherDadosPessoais(tester);
  await tocar(tester, find.text('Próximo'));
  expect(find.byType(TelaCadastro2), findsOneWidget);
  expect(find.text('Passo 2: Endereço e Contato.'), findsOneWidget);

  await tocar(tester, find.text('Voltar'));
  expect(
    tester.widget<TextFormField>(campo('Nome completo *')).controller!.text,
    'Pessoa Teste',
  );
  await tocar(tester, find.text('Voltar'));
  await tocar(tester, find.text('Sou Cuidador'));
  expect(find.byType(TelaCadastroCuidador), findsOneWidget);
  expect(find.text('Criar conta de cuidador'), findsOneWidget);
}
