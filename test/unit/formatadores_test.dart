import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/telas/tela_cadastro1.dart';
import 'package:lembrebem/telas/tela_cadastro2.dart';

void main() {
  final casos = <String, (TextInputFormatter, Map<String, String>)>{
    'CPF': (
      CpfInputFormatter(),
      {
        '': '',
        '1234': '123.4',
        '12345678901': '123.456.789-01',
        '123.456.789-01 extra 99': '123.456.789-01',
      },
    ),
    'data de nascimento': (
      DataNascimentoInputFormatter(),
      {
        '': '',
        '010': '01/0',
        '01021990': '01/02/1990',
        '01/02/1990 extra 99': '01/02/1990',
      },
    ),
    'CEP': (
      CepInputFormatter(),
      {
        '': '',
        '85801': '85801',
        '85801000': '85801-000',
        '85801-000 extra 99': '85801-000',
      },
    ),
  };

  for (final tipo in casos.entries) {
    group('Máscara de ${tipo.key}', () {
      for (final caso in tipo.value.$2.entries) {
        test('formata "${caso.key}" como "${caso.value}"', () {
          final resultado = tipo.value.$1.formatEditUpdate(
            TextEditingValue.empty,
            TextEditingValue(text: caso.key),
          );
          expect(resultado.text, caso.value);
          expect(resultado.selection.baseOffset, caso.value.length);
          expect(resultado.selection.isCollapsed, isTrue);
        });
      }

      test('permite apagar o conteúdo', () {
        final resultado = tipo.value.$1.formatEditUpdate(
          const TextEditingValue(text: '123'),
          TextEditingValue.empty,
        );
        expect(resultado.text, isEmpty);
        expect(resultado.selection.baseOffset, 0);
      });
    });
  }
}
