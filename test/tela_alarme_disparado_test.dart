import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/telas/tela_alarme_disparado.dart';

void main() {
  Widget criarWidgetTeste(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  testWidgets('TelaAlarmeDisparado renderiza primeira chamada corretamente', (tester) async {
    bool tomou = false;
    bool soneca = false;

    await tester.pumpWidget(
      criarWidgetTeste(
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
          aoPedirSoneca: () {
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
    expect(find.text('✓ Tomei o medicamento'), findsOneWidget);
    expect(find.text('Lembrar em 10 minutos (Soneca)'), findsOneWidget);

    // Clica em Tomei o medicamento
    await tester.tap(find.text('✓ Tomei o medicamento'));
    await tester.pump();
    expect(tomou, isTrue);
  });

  testWidgets('TelaAlarmeDisparado renderiza segunda chamada com aviso de cuidador', (tester) async {
    bool escalou = false;

    await tester.pumpWidget(
      criarWidgetTeste(
        TelaAlarmeDisparado(
          alarmeId: 'alarme-1',
          medicamentoNome: 'Losartana',
          horarioFormatado: '14:00',
          tentativa: 2,
          aoEscalarCuidador: () async {
            escalou = true;
          },
        ),
      ),
    );

    expect(find.text('2ª Chamada (Insistência)'), findsOneWidget);
    expect(find.text('Atenção: 2ª Chamada!'), findsOneWidget);
    expect(
      find.text('Se não confirmar agora, seu cuidador vinculado receberá um aviso via WhatsApp!'),
      findsOneWidget,
    );
    expect(find.text('Não vou tomar / Desligar alarme'), findsOneWidget);

    // Clica no botao de desligar / escalar
    await tester.tap(find.text('Não vou tomar / Desligar alarme'));
    await tester.pump();
    expect(escalou, isTrue);
  });
}
