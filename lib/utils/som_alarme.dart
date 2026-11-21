import 'package:flutter/services.dart';
import 'som_alarme_stub.dart'
    if (dart.library.html) 'som_alarme_web.dart';

class GerenciadorSomAlarme {
  static void tocarBeepAlarme() {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    try {
      tocarAlarmePlataforma();
    } catch (_) {}
  }
}
