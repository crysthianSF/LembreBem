import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/main.dart';

import '../support/fluxo_inicial.dart';

void main() {
  final telas = <String, (Size, double)>{
    'Pixel 2': (const Size(1080, 1920), 2.75),
    'celular compacto': (const Size(720, 1280), 2),
  };

  for (final tela in telas.entries) {
    testWidgets('Fluxo inicial e cadastro em ${tela.key}', (tester) async {
      tester.view.physicalSize = tela.value.$1;
      tester.view.devicePixelRatio = tela.value.$2;
      addTearDown(tester.view.reset);

      final avisosFatais = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() {
        WidgetController.hitTestWarningShouldBeFatal = avisosFatais;
      });

      await tester.pumpWidget(const MyApp());
      await validarFluxoInicialECadastro(tester);
    });
  }
}
