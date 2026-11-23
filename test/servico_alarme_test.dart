import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/backend/alarmes_api.dart';
import 'package:lembrebem/backend/app_api.dart';
import 'package:lembrebem/backend/servico_alarme.dart';
import 'package:lembrebem/modelo_alarme.dart';

class _FakeAppApi extends AppApi {
  List<Map<String, dynamic>> alarmes = [];

  @override
  Future<List<Map<String, dynamic>>> listarAlarmesDoUsuario({
    required String usuarioId,
  }) async {
    return alarmes;
  }
}

class _FakeAlarmesApi extends AlarmesApi {
  bool jaTomouHoje = false;
  String? alarmeTomadoId;
  String? alarmeEscaladoId;

  @override
  Future<bool> verificarDoseJaTomadaHoje({
    required String alarmeId,
    required DateTime data,
    String? usuarioId,
  }) async {
    return jaTomouHoje;
  }

  @override
  Future<Map<String, dynamic>> registrarDoseTomada({
    required String alarmeId,
    required String medicamentoNome,
    required DateTime horarioPrevisto,
    String? dose,
    String? usuarioId,
  }) async {
    alarmeTomadoId = alarmeId;
    return {'id': 'd1', 'status': 'tomada'};
  }

  @override
  Future<Map<String, dynamic>> registrarDosePerdidaEEscalar({
    required String alarmeId,
    required String medicamentoNome,
    required DateTime horarioPrevisto,
    String? dose,
    String? usuarioId,
  }) async {
    alarmeEscaladoId = alarmeId;
    return {'id': 'd1', 'status': 'perdida', 'precisa_notificar': true};
  }
}

void main() {
  late _FakeAppApi fakeApp;
  late _FakeAlarmesApi fakeAlarmes;
  late ServicoAlarme servico;

  setUp(() {
    fakeApp = _FakeAppApi();
    fakeAlarmes = _FakeAlarmesApi();
    servico = ServicoAlarme(appApi: fakeApp, alarmesApi: fakeAlarmes);
  });

  tearDown(() {
    servico.parar();
  });

  test('Filtra alarmes inativos ao carregar', () {
    servico.definirAlarmesAtivos([
      Alarme(
        id: '1',
        nome: 'Remedio A',
        observacoes: '',
        horario: const TimeOfDay(hour: 8, minute: 0),
        diasDeUso: 'Todo dia',
        ativado: true,
        intervalo: '',
      ),
      Alarme(
        id: '2',
        nome: 'Remedio B',
        observacoes: '',
        horario: const TimeOfDay(hour: 12, minute: 0),
        diasDeUso: 'Todo dia',
        ativado: false,
        intervalo: '',
      ),
    ]);

    expect(servico.alarmesAtivos.length, 1);
    expect(servico.alarmesAtivos.first.nome, 'Remedio A');
  });

  test('Agendamento de soneca define tentativa 2 e horario futuro', () {
    servico.agendarSoneca('alarme-teste', minutos: 10);
    // Cancela soneca
    servico.cancelarSoneca('alarme-teste');
    expect(servico.alarmeEmExibicao, isFalse);
  });

  test('Parar limpa todos os timers e listas temporarias', () {
    servico.agendarSoneca('a1');
    servico.parar();
    expect(servico.inicializado, isFalse);
    expect(servico.alarmeEmExibicao, isFalse);
  });
}
