import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/telas/tela_alarme_disparado.dart';

void main() {
  Widget criarWidgetTeste(WidgetTester tester, Widget child) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    return MaterialApp(home: child);
  }

  testWidgets(
    'TelaAlarmeDisparado renderiza primeira chamada e aciona soneca',
    (tester) async {
      bool tomou = false;
      bool soneca = false;

      await tester.pumpWidget(
        criarWidgetTeste(
          tester,
          TelaAlarmeDisparado(
            alarmeId: 'alarme-1',
            medicamentoNome: 'Paracetamol',
            horarioFormatado: '08:00',
            dose: '500mg',
            observacoes: 'Tomar com água',
            tentativa: 1,
            aoTomarMedicamento: () async {
              tomou = true;
            },
            aoPedirSoneca: (minutos) {
              soneca = true;
            },
          ),
        ),
      );

      expect(find.text('1ª Chamada'), findsOneWidget);
      expect(find.text('Hora do Medicamento!'), findsOneWidget);
      expect(find.text('Paracetamol'), findsOneWidget);
      expect(find.text('Dose: 500mg'), findsOneWidget);
      expect(find.text('Tomar com água'), findsOneWidget);
      expect(find.text('Tomei o medicamento'), findsOneWidget);
      expect(find.text('Lembrar em 10 minutos'), findsOneWidget);
      expect(find.text('Testar 2ª chamada em 1 minuto'), findsOneWidget);

      // Clica em Soneca
      await tester.tap(find.text('Lembrar em 10 minutos'));
      await tester.pump();
      expect(soneca, isTrue);
      expect(tomou, isFalse);
    },
  );

  testWidgets(
    'TelaAlarmeDisparado confirma dose tomada ao clicar no botão principal',
    (tester) async {
      bool tomou = false;

      await tester.pumpWidget(
        criarWidgetTeste(
          tester,
          TelaAlarmeDisparado(
            alarmeId: 'alarme-1',
            medicamentoNome: 'Paracetamol',
            horarioFormatado: '08:00',
            tentativa: 1,
            aoTomarMedicamento: () async {
              tomou = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('Tomei o medicamento'));
      await tester.pump();
      expect(tomou, isTrue);
    },
  );

  testWidgets(
    'TelaAlarmeDisparado renderiza segunda chamada com aviso de cuidador',
    (tester) async {
      bool escalou = false;

      await tester.pumpWidget(
        criarWidgetTeste(
          tester,
          TelaAlarmeDisparado(
            alarmeId: 'alarme-1',
            medicamentoNome: 'Losartana',
            horarioFormatado: '14:00',
            tentativa: 2,
            aoEscalarCuidador: () async {
              escalou = true;
              return {
                'mensagem_notificacao':
                    'Nenhum contato com WhatsApp autorizado está disponível.',
              };
            },
          ),
        ),
      );

      expect(find.text('2ª Chamada'), findsOneWidget);
      expect(
        find.text(
          'Se não confirmar, tentaremos avisar os contatos de confiança que autorizaram receber mensagens pelo WhatsApp.',
        ),
        findsOneWidget,
      );
      expect(find.text('Desligar alarme'), findsOneWidget);

      // Clica no botao de desligar / escalar
      await tester.tap(find.text('Desligar alarme'));
      await tester.pump();
      expect(escalou, isTrue);
    },
  );

  testWidgets(
    'Falha na gravação mantém o alarme aberto e permite tentar de novo',
    (tester) async {
      var chamadas = 0;
      await tester.pumpWidget(
        criarWidgetTeste(
          tester,
          TelaAlarmeDisparado(
            alarmeId: 'alarme-1',
            medicamentoNome: 'Losartana',
            horarioFormatado: '14:00',
            tentativa: 2,
            aoEscalarCuidador: () async {
              chamadas++;
              throw StateError('Falha no banco');
            },
          ),
        ),
      );
      await tester.tap(find.text('Desligar alarme'));
      await tester.pumpAndSettle();
      expect(find.byType(TelaAlarmeDisparado), findsOneWidget);
      expect(
        find.textContaining('Não foi possível registrar a dose perdida'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Dose registrada como perdida.'),
        findsNothing,
      );
      expect(find.textContaining('Notificação enviada'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desligar alarme'));
      await tester.pump();
      expect(chamadas, 2);
    },
  );
}
