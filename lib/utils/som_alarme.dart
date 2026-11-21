import 'package:flutter/services.dart';

class GerenciadorSomAlarme {
  static void tocarBeepAlarme() {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }
}
