import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/main.dart';
import 'package:lembrebem/telas/tela_cadastro1.dart';
import 'package:lembrebem/telas/tela_cadastro2.dart';
import 'package:lembrebem/telas/tela_cadastro3.dart';

import '../support/interacoes.dart';

void main() {
  testWidgets('Cadastro integra navegação, máscaras e dados das três etapas', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tocar(tester, find.text('Fazer cadastro'));
    await tocar(tester, find.text('Sou Paciente'));
    expect(find.byType(TelaCadastro1), findsOneWidget);

    await preencherDadosPessoais(tester);
    await tocar(tester, find.text('Próximo'));
    expect(find.byType(TelaCadastro2), findsOneWidget);
    expect(
      tester.widget<TelaCadastro2>(find.byType(TelaCadastro2)).dadosCadastro,
      {
        'nome': 'Pessoa Teste',
        'cpf': '123.456.789-01',
        'email': 'pessoa@example.com',
        'dataNascimento': '01/02/1990',
        'senha': 'Teste1234',
      },
    );

    await tocar(tester, find.text('Voltar'));
    expect(
      tester.widget<TextFormField>(campo('Nome completo *')).controller!.text,
      'Pessoa Teste',
    );
    await tocar(tester, find.text('Próximo'));
    await tocar(tester, find.text('Próximo'));
    expect(find.text('Selecione um estado.'), findsOneWidget);
    expect(find.byType(TelaCadastro3), findsNothing);

    await preencher(tester, 'Número de telefone *', '45999990000');
    await tocar(tester, find.byType(DropdownButtonFormField<String>));
    await tocar(tester, find.text('AC').last);
    await preencher(tester, 'Cidade *', 'Rio Branco');
    await preencher(tester, 'Rua *', 'Rua de Teste');
    await preencher(tester, 'Número *', '123');
    await preencher(tester, 'CEP *', '69900000');
    await tocar(tester, find.text('Próximo'));

    final dados =
        tester.widget<TelaCadastro3>(find.byType(TelaCadastro3)).dadosCadastro;
    expect(dados['nome'], 'Pessoa Teste');
    expect(dados['cpf'], '123.456.789-01');
    expect(dados['telefone'], '(45) 99999-0000');
    expect(dados['estado'], 'AC');
    expect(dados['cidade'], 'Rio Branco');
    expect(dados['rua'], 'Rua de Teste');
    expect(dados['numero'], '123');
    expect(dados['cep'], '69900-000');

    await tocar(tester, find.text('Finalizar cadastro'));
    expect(
      find.text(
        'Você precisa aceitar as Políticas de Privacidade para continuar.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
