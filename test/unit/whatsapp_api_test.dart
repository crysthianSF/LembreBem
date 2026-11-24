import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/backend/whatsapp_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  FunctionResponse responder(String status) => FunctionResponse(
    status: 200,
    data: {'status': status, 'message_id': 'wamid.teste'},
  );

  test(
    'Relatório envia somente IDs e período, com UUID v4 de idempotência',
    () async {
      late String funcao;
      late Map<String, dynamic> payload;
      final api = WhatsAppApi(
        usuarioAtual: () => 'cuidador-1',
        invocar: (nome, corpo) async {
          funcao = nome;
          payload = corpo;
          return responder('accepted');
        },
      );

      final resultado = await api.enviarRelatorio(
        pacienteId: 'paciente-1',
        dias: 7,
      );

      expect(funcao, 'enviar-relatorio-whatsapp');
      expect(payload.keys.toSet(), {'paciente_id', 'dias', 'request_id'});
      expect(payload['paciente_id'], 'paciente-1');
      expect(payload['dias'], 7);
      expect(
        payload['request_id'],
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(resultado.mensagemRelatorio, contains('encaminhado para envio'));
      expect(resultado.mensagemRelatorio, isNot(contains('entregue')));
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );

  test('Cliques concorrentes compartilham uma única solicitação', () async {
    final entrou = Completer<void>();
    final resposta = Completer<FunctionResponse>();
    var chamadas = 0;
    final api = WhatsAppApi(
      usuarioAtual: () => 'cuidador-1',
      invocar: (_, _) {
        chamadas++;
        entrou.complete();
        return resposta.future;
      },
    );
    final primeiro = api.enviarRelatorio(pacienteId: 'paciente-1', dias: 1);
    final segundo = api.enviarRelatorio(pacienteId: 'paciente-1', dias: 1);
    await entrou.future;
    expect(chamadas, 1);
    expect(identical(primeiro, segundo), isTrue);
    resposta.complete(responder('accepted'));
    await Future.wait([primeiro, segundo]);
  });

  test(
    'Timeout preserva o ID em armazenamento para retry após recriar cliente',
    () async {
      final ids = <String>[];
      final api = WhatsAppApi(
        usuarioAtual: () => 'cuidador-1',
        timeout: const Duration(milliseconds: 1),
        invocar: (_, corpo) {
          ids.add(corpo['request_id'] as String);
          return Completer<FunctionResponse>().future;
        },
      );
      await expectLater(
        api.enviarRelatorio(pacienteId: 'paciente-1', dias: 30),
        throwsA(
          isA<WhatsAppException>().having((e) => e.codigo, 'codigo', 'TIMEOUT'),
        ),
      );

      final reiniciado = WhatsAppApi(
        usuarioAtual: () => 'cuidador-1',
        invocar: (_, corpo) async {
          ids.add(corpo['request_id'] as String);
          return responder('accepted');
        },
      );
      await reiniciado.enviarRelatorio(pacienteId: 'paciente-1', dias: 30);
      expect(ids, hasLength(2));
      expect(ids[1], ids[0]);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    },
  );

  for (final estado in ['unknown', 'processing']) {
    test(
      '$estado mantém a mesma intenção até confirmação definitiva',
      () async {
        final ids = <String>[];
        var chamadas = 0;
        final api = WhatsAppApi(
          usuarioAtual: () => 'cuidador-1',
          invocar: (_, corpo) async {
            ids.add(corpo['request_id'] as String);
            return responder(chamadas++ == 0 ? estado : 'accepted');
          },
        );
        expect(
          (await api.enviarRelatorio(pacienteId: 'p', dias: 7)).status,
          estado,
        );
        await api.enviarRelatorio(pacienteId: 'p', dias: 7);
        await api.enviarRelatorio(pacienteId: 'p', dias: 7);
        expect(ids[1], ids[0]);
        expect(ids[2], isNot(ids[0]));
      },
    );
  }

  test('Falha definitiva permite nova intenção no próximo toque', () async {
    final ids = <String>[];
    final api = WhatsAppApi(
      usuarioAtual: () => 'cuidador-1',
      invocar: (_, corpo) async {
        ids.add(corpo['request_id'] as String);
        return responder('failed');
      },
    );
    await api.enviarRelatorio(pacienteId: 'p', dias: 1);
    await api.enviarRelatorio(pacienteId: 'p', dias: 1);
    expect(ids[1], isNot(ids[0]));
  });

  test(
    'Resultado incerto é consultado hoje e não bloqueia relatório amanhã',
    () async {
      final ids = <String>[];
      var agora = DateTime(2026, 11, 23, 10);
      WhatsAppApi criarApi() => WhatsAppApi(
        usuarioAtual: () => 'cuidador-1',
        agora: () => agora,
        invocar: (_, corpo) async {
          ids.add(corpo['request_id'] as String);
          return responder('unknown');
        },
      );
      await criarApi().enviarRelatorio(pacienteId: 'p', dias: 7);
      agora = DateTime(2026, 11, 23, 23, 59);
      await criarApi().enviarRelatorio(pacienteId: 'p', dias: 7);
      agora = DateTime(2026, 11, 24, 0, 1);
      await criarApi().enviarRelatorio(pacienteId: 'p', dias: 7);
      expect(ids[1], ids[0]);
      expect(ids[2], isNot(ids[0]));
    },
  );

  test('Requisições pendentes ficam isoladas por usuário e período', () async {
    final ids = <String>[];
    var usuario = 'cuidador-1';
    final api = WhatsAppApi(
      usuarioAtual: () => usuario,
      invocar: (_, corpo) async {
        ids.add(corpo['request_id'] as String);
        return responder('unknown');
      },
    );
    await api.enviarRelatorio(pacienteId: 'p', dias: 1);
    usuario = 'cuidador-2';
    await api.enviarRelatorio(pacienteId: 'p', dias: 1);
    await api.enviarRelatorio(pacienteId: 'p', dias: 7);
    usuario = 'cuidador-1';
    await api.enviarRelatorio(pacienteId: 'p', dias: 1);
    expect(ids.take(3).toSet(), hasLength(3));
    expect(ids[3], ids[0]);
  });

  test('Sessão ausente e período inválido não chamam a função', () async {
    var chamadas = 0;
    final api = WhatsAppApi(
      usuarioAtual: () => null,
      invocar: (_, _) async {
        chamadas++;
        return responder('accepted');
      },
    );
    await expectLater(
      api.enviarRelatorio(pacienteId: 'p', dias: 1),
      throwsA(
        isA<WhatsAppException>().having(
          (e) => e.codigo,
          'codigo',
          'UNAUTHORIZED',
        ),
      ),
    );
    await expectLater(
      api.enviarRelatorio(pacienteId: 'p', dias: 2),
      throwsA(
        isA<WhatsAppException>().having(
          (e) => e.codigo,
          'codigo',
          'INVALID_REQUEST',
        ),
      ),
    );
    expect(chamadas, 0);
  });

  test(
    'Opt-in ausente orienta ACEITO e não expõe detalhes retornados',
    () async {
      final api = WhatsAppApi(
        usuarioAtual: () => 'cuidador',
        invocar:
            (_, _) async =>
                throw const FunctionException(
                  status: 409,
                  details: {
                    'error': 'OPT_IN_REQUIRED',
                    'message': 'segredo-do-servidor',
                  },
                ),
      );
      await expectLater(
        api.enviarRelatorio(pacienteId: 'p', dias: 1),
        throwsA(
          isA<WhatsAppException>()
              .having((e) => e.mensagem, 'mensagem', contains('ACEITO'))
              .having(
                (e) => e.mensagem,
                'mensagem',
                isNot(contains('segredo')),
              ),
        ),
      );
    },
  );

  test(
    'Configuração ausente não vira confirmação de envio e preserva request_id',
    () async {
      final ids = <String>[];
      final api = WhatsAppApi(
        usuarioAtual: () => 'cuidador',
        invocar: (_, corpo) async {
          ids.add(corpo['request_id'] as String);
          return FunctionResponse(
            status: 503,
            data: {'error': 'NOT_CONFIGURED'},
          );
        },
      );
      for (var i = 0; i < 2; i++) {
        await expectLater(
          api.enviarRelatorio(pacienteId: 'p', dias: 1),
          throwsA(
            isA<WhatsAppException>().having(
              (e) => e.mensagem,
              'mensagem',
              contains('ainda não está disponível'),
            ),
          ),
        );
      }
      expect(ids[0], ids[1]);
    },
  );

  test('Alerta envia apenas dose_id e mantém resultado parcial', () async {
    final api = WhatsAppApi(
      invocar: (nome, corpo) async {
        expect(nome, 'enviar-alerta-whatsapp');
        expect(corpo, {'dose_id': 'dose-1'});
        return FunctionResponse(
          status: 200,
          data: {'status': 'partial', 'accepted': 1, 'failed': 1, 'skipped': 2},
        );
      },
    );
    final resultado = await api.enviarAlertaDosePerdida(doseId: 'dose-1');
    expect(resultado.aceitos, 1);
    expect(resultado.falhas, 1);
    expect(resultado.ignorados, 2);
    expect(resultado.mensagemAlerta, contains('alguns contatos'));
    expect(resultado.mensagemAlerta, isNot(contains('entregue')));
  });

  test('Resposta de formato inesperado não é tratada como sucesso', () async {
    final api = WhatsAppApi(
      invocar:
          (_, _) async =>
              FunctionResponse(status: 200, data: {'status': 'inventado'}),
    );
    await expectLater(
      api.enviarAlertaDosePerdida(doseId: 'dose-1'),
      throwsA(
        isA<WhatsAppException>().having(
          (e) => e.codigo,
          'codigo',
          'INVALID_RESPONSE',
        ),
      ),
    );
  });
}
