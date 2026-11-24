import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/backend/cuidador_api.dart';
import 'package:lembrebem/backend/whatsapp_api.dart';
import 'package:lembrebem/telas/tela_cuidador_painel.dart';
import 'package:lembrebem/widgets/componentes.dart';

class _CuidadorMemoria extends CuidadorApi {
  @override
  Future<Map<String, dynamic>?> buscarCuidadorAtual() async => {
    'id': 'cuidador',
    'nome': 'Cuidador Teste',
  };

  @override
  Future<List<Map<String, dynamic>>> listarPacientes() async => [
    {'id': 'paciente-1', 'nome': 'Paciente Teste', 'telefone': '45999999999'},
  ];

  @override
  Future<List<Map<String, dynamic>>> listarDosesDeHoje({
    required String pacienteId,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> adesaoSemanal({
    required String pacienteId,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> listarDosesPeriodo({
    required String pacienteId,
    required int dias,
  }) {
    throw StateError('O relatório deve ser calculado no servidor.');
  }
}

class _WhatsAppMemoria extends WhatsAppApi {
  final resposta = Completer<ResultadoEnvioWhatsApp>();
  final chamadas = <(String, int)>[];

  @override
  Future<ResultadoEnvioWhatsApp> enviarRelatorio({
    required String pacienteId,
    required int dias,
  }) {
    chamadas.add((pacienteId, dias));
    return resposta.future;
  }
}

void main() {
  Future<BotaoPrimario> abrirEnvio(
    WidgetTester tester,
    _WhatsAppMemoria api,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: TelaCuidadorPainel(
          cuidadorApi: _CuidadorMemoria(),
          whatsAppApi: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paciente Teste'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar relatório via WhatsApp'));
    await tester.pumpAndSettle();
    return tester.widget<BotaoPrimario>(
      find.widgetWithText(BotaoPrimario, 'Enviar relatório para paciente'),
    );
  }

  testWidgets(
    'Botão chama servidor uma vez e confirma encaminhamento, não entrega',
    (tester) async {
      final api = _WhatsAppMemoria();
      final botao = await abrirEnvio(tester, api);
      botao.onPressed!();
      botao.onPressed!();
      await tester.pumpAndSettle();
      expect(api.chamadas, [('paciente-1', 1)]);
      expect(find.text('Solicitando envio do relatório…'), findsOneWidget);

      api.resposta.complete(const ResultadoEnvioWhatsApp(status: 'accepted'));
      await tester.pumpAndSettle();
      expect(
        find.text('Relatório encaminhado para envio pelo WhatsApp.'),
        findsOneWidget,
      );
      expect(find.textContaining('entregue'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Opt-in ausente aparece como orientação, sem sucesso falso', (
    tester,
  ) async {
    final api = _WhatsAppMemoria();
    final botao = await abrirEnvio(tester, api);
    botao.onPressed!();
    await tester.pump();
    api.resposta.completeError(const WhatsAppException('OPT_IN_REQUIRED'));
    await tester.pumpAndSettle();
    expect(find.textContaining('precisa enviar ACEITO'), findsOneWidget);
    expect(find.textContaining('encaminhado para envio'), findsNothing);
  });

  testWidgets('Resultado desconhecido preserva a informação de incerteza', (
    tester,
  ) async {
    final api = _WhatsAppMemoria();
    final botao = await abrirEnvio(tester, api);
    botao.onPressed!();
    await tester.pump();
    api.resposta.complete(const ResultadoEnvioWhatsApp(status: 'unknown'));
    await tester.pumpAndSettle();
    expect(find.textContaining('não foi possível confirmar'), findsOneWidget);
    expect(find.textContaining('encaminhado para envio'), findsNothing);
  });
}
