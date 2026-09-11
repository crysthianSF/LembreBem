import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lembrebem/backend/local_cache.dart';
import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:lembrebem/main.dart' as app;
import 'package:lembrebem/telas/tela_cadastro1.dart';
import 'package:lembrebem/telas/tela_cadastro2.dart';
import 'package:lembrebem/telas/tela_cadastro_cuidador.dart';
import 'package:lembrebem/telas/tela_login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../test/support/interacoes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    expect(
      SupabaseBackend.supabaseUrl,
      'http://127.0.0.1:54321',
      reason:
          'Use --dart-define-from-file=integration_test/config/test_env.json',
    );
    expect(
      SupabaseBackend.supabaseAnonKey,
      'sb_publishable_apenas_para_testes_locais_sem_backend',
    );
  });

  testWidgets(
    'E2E: inicialização, login vazio e cadastro de paciente e cuidador',
    (tester) async {
      await app.main();
      addTearDown(() => Supabase.instance.dispose());
      await tester.pumpAndSettle();
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
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Sistema: cache de alarmes grava e remove pelo plugin nativo', (
    tester,
  ) async {
    const usuario = 'ci-e2e-cache';
    final preferencias = await SharedPreferences.getInstance();
    addTearDown(() => preferencias.remove('cache_alarmes_$usuario'));
    await preferencias.remove('cache_alarmes_$usuario');

    await LocalCache().salvarAlarmesUsuario(usuario, [
      {'id': 'alarme-e2e', 'titulo': 'Medicamento de teste', 'ativo': true},
    ]);
    await preferencias.reload();
    final cache = LocalCache();
    final itens = await cache.carregarAlarmesUsuario(usuario);
    expect(itens.single['titulo'], 'Medicamento de teste');
    await cache.alternarStatusAlarmeUsuario(usuario, 'alarme-e2e', false);
    await preferencias.reload();
    expect(
      (await cache.carregarAlarmesUsuario(usuario)).single['ativo'],
      isFalse,
    );
    await cache.removerAlarmeUsuario(usuario, 'alarme-e2e');
    await preferencias.reload();
    expect(await cache.carregarAlarmesUsuario(usuario), isEmpty);
  });
}
