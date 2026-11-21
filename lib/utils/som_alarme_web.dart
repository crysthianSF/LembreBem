// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void tocarAlarmePlataforma() {
  try {
    final audioCtx = html.AudioContext();
    final osc = audioCtx.createOscillator();
    final gain = audioCtx.createGain();

    osc.type = 'sine';
    osc.frequency?.setValueAtTime(880, audioCtx.currentTime ?? 0);
    gain.gain?.setValueAtTime(0.35, audioCtx.currentTime ?? 0);

    osc.connect(gain);
    gain.connect(audioCtx.destination!);

    osc.start(0);
    Future.delayed(const Duration(milliseconds: 350), () {
      try {
        osc.stop(0);
        audioCtx.close();
      } catch (_) {}
    });
  } catch (_) {}
}
