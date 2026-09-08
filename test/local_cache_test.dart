import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/backend/local_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalCache cache;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = LocalCache();
  });

  test('Excluir itens sem cache local nao impede a operacao', () async {
    await cache.removerAlarmeUsuario('usuario', 'alarme');
    await cache.removerUsuarioMedicamento('usuario', 'vinculo');
    await cache.removerUsuarioMedicamentoPorMedicamentoId('usuario', 12);
    expect(await cache.carregarAlarmesUsuario('usuario'), isEmpty);
    expect(await cache.carregarUsuarioMedicamentos('usuario'), isEmpty);
  });

  test('Cache corrompido e recuperado sem impedir exclusoes', () async {
    SharedPreferences.setMockInitialValues({
      'cache_alarmes_usuario': '{invalido',
      'cache_usuario_medicamentos_usuario': jsonEncode({'id': 1}),
    });
    await cache.removerAlarmeUsuario('usuario', '1');
    await cache.removerUsuarioMedicamento('usuario', '1');
    expect(await cache.carregarAlarmesUsuario('usuario'), isEmpty);
    expect(await cache.carregarUsuarioMedicamentos('usuario'), isEmpty);
  });

  test(
    'Alarmes ficam isolados por usuario e preservam as chaves salvas',
    () async {
      SharedPreferences.setMockInitialValues({
        'cache_alarmes_a': jsonEncode([
          {'id': '1', 'ativo': true},
        ]),
        'cache_alarmes_b': jsonEncode([
          {'id': '1', 'ativo': true},
        ]),
      });
      await cache.alternarStatusAlarmeUsuario('a', '1', false);
      expect(
        (await cache.carregarAlarmesUsuario('a')).single['ativo'],
        isFalse,
      );
      expect((await cache.carregarAlarmesUsuario('b')).single['ativo'], isTrue);
      await cache.removerAlarmeUsuario('a', '1');
      expect(await cache.carregarAlarmesUsuario('a'), isEmpty);
      expect(await cache.carregarAlarmesUsuario('b'), hasLength(1));
    },
  );

  test(
    'Catalogo substitui duplicados e respeita o limite de armazenamento',
    () async {
      await cache.salvarCatalogoMedicamentos([
        {'id': 1, 'nome_produto': 'Antigo'},
        {'id': 2, 'nome_produto': 'Segundo'},
      ]);
      await cache.salvarCatalogoMedicamentos([
        {'id': '1', 'nome_produto': 'Atualizado'},
        {'id': 3, 'nome_produto': 'Terceiro'},
        {'nome_produto': 'Sem ID'},
      ], limite: 2);
      final itens = await cache.carregarCatalogoMedicamentos();
      expect(itens.map((item) => item['id'].toString()), ['1', '3']);
      expect(
        (await cache.buscarMedicamentoPorId('1'))!['nome_produto'],
        'Atualizado',
      );
    },
  );

  test(
    'Busca offline ignora acentos e prioriza o nome do medicamento',
    () async {
      await cache.salvarCatalogoMedicamentos([
        {'id': 1, 'nome_produto': 'Outro', 'principio_ativo': 'ÁCIDO FÓLICO'},
        {'id': 2, 'nome_produto': 'Ácido Fólico'},
        {'id': 3, 'nome_produto': 'Não relacionado'},
      ]);
      final itens = await cache.buscarMedicamentosNoCache('  ACIDO   FOLICO  ');
      expect(itens.map((item) => item['id']), [2, 1]);
      expect(await cache.buscarMedicamentosNoCache('   '), isEmpty);
    },
  );

  test('Exclusao por medicamento aceita IDs numericos e textuais', () async {
    await cache.salvarUsuarioMedicamentos('a', [
      {'id': '1', 'medicamento_id': 12},
      {'id': '2', 'medicamento_id': '12'},
      {'id': '3', 'medicamento_id': 13},
    ]);
    await cache.removerUsuarioMedicamentoPorMedicamentoId('a', 12);
    expect((await cache.carregarUsuarioMedicamentos('a')).single['id'], '3');
  });
}
