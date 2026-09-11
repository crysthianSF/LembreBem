import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/utils/normalizacao.dart';

void main() {
  group('Normalização da busca de medicamentos', () {
    test('ignora maiúsculas e acentos', () {
      expect(normalizarTexto('ÁCIDO FÓLICO'), 'acido folico');
      expect(normalizarTexto('Solução com AÇÚCAR'), 'solucao com acucar');
    });

    test('remove espaços nas pontas e agrupa espaços internos', () {
      expect(
        normalizarTexto('  Ácido\t Fólico\n  5 mg  '),
        'acido folico 5 mg',
      );
    });

    test('aceita busca vazia e preserva números e pontuação', () {
      expect(normalizarTexto(' \n\t '), isEmpty);
      expect(
        normalizarTexto('Vitamina B12 - 1.000 mcg'),
        'vitamina b12 - 1.000 mcg',
      );
    });
  });
}
