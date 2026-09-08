import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/backend/alarmes_api.dart';
import 'package:lembrebem/backend/app_api.dart';
import 'package:lembrebem/modelo_alarme.dart';

class _AppApiMemoria extends AppApi {
  Map<String, dynamic>? alarmeSalvo;
  Map<String, dynamic>? medicamentoSalvo;
  Map<String, dynamic>? medicamentoExistente;
  int consultas = 0;

  @override
  Future<Map<String, dynamic>> criarAlarme({
    required Map<String, dynamic> payload,
  }) async {
    alarmeSalvo = payload;
    return {'id': 'alarme', ...payload};
  }

  @override
  Future<Map<String, dynamic>?> buscarUsuarioMedicamentoPorMedicamentoId({
    required String usuarioId,
    required int medicamentoId,
  }) async {
    consultas++;
    expect(usuarioId, 'usuario');
    expect(medicamentoId, 42);
    return medicamentoExistente;
  }

  @override
  Future<Map<String, dynamic>> salvarUsuarioMedicamento({
    required Map<String, dynamic> payload,
  }) async {
    medicamentoSalvo = payload;
    return {'id': 'novo-vinculo', ...payload};
  }
}

void main() {
  late _AppApiMemoria app;
  late AlarmesApi alarmes;

  setUp(() {
    app = _AppApiMemoria();
    alarmes = AlarmesApi(appApi: app);
  });

  Future<void> salvar({
    String usuario = 'usuario',
    int? medicamentoId,
    String? vinculo,
  }) {
    return alarmes.salvarNovoAlarme(
      nome: 'Medicamento',
      observacoes: 'Depois do almoco',
      horario: const TimeOfDay(hour: 8, minute: 5),
      diasDeUso: 'Todo dia',
      ativado: true,
      intervalo: '8 em 8h',
      usuarioId: usuario,
      medicamentoId: medicamentoId,
      usuarioMedicamentoId: vinculo,
    );
  }

  test('Criacao mantem o contrato de campos existente no Supabase', () async {
    await salvar();
    final payload = app.alarmeSalvo!;
    expect(payload.keys.toSet(), {
      'usuario_id',
      'titulo',
      'descricao',
      'data_alarme',
      'hora_alarme',
      'repetir',
      'ativo',
      'created_at',
    });
    expect(payload['usuario_id'], 'usuario');
    expect(payload['hora_alarme'], '08:05:00');
    expect(payload['ativo'], isTrue);
    expect(payload['repetir'], isFalse);
    expect(DateTime.tryParse(payload['data_alarme']), isNotNull);
    expect(DateTime.tryParse(payload['created_at']), isNotNull);
    expect(app.consultas, 0);
  });

  test('Medicamento ja vinculado e reutilizado', () async {
    app.medicamentoExistente = {'id': 'vinculo-existente'};
    await salvar(medicamentoId: 42);
    expect(app.alarmeSalvo!['usuario_medicamento_id'], 'vinculo-existente');
    expect(app.medicamentoSalvo, isNull);
  });

  test(
    'Medicamento sem vinculo e associado antes de salvar o alarme',
    () async {
      await salvar(medicamentoId: 42);
      expect(app.medicamentoSalvo, {
        'usuario_id': 'usuario',
        'medicamento_id': 42,
        'apelido': 'Medicamento',
        'ativo': true,
      });
      expect(app.alarmeSalvo!['usuario_medicamento_id'], 'novo-vinculo');
    },
  );

  test('Vinculo informado dispensa nova consulta', () async {
    await salvar(medicamentoId: 42, vinculo: 'informado');
    expect(app.consultas, 0);
    expect(app.alarmeSalvo!['usuario_medicamento_id'], 'informado');
  });

  test('Usuario vazio nao gera gravacoes', () async {
    await expectLater(salvar(usuario: ''), throwsStateError);
    expect(app.alarmeSalvo, isNull);
    expect(app.medicamentoSalvo, isNull);
  });

  test('Modelo continua lendo os campos e IDs retornados pelo Supabase', () {
    final alarme = Alarme.fromJson({
      'id': 7,
      'titulo': 'Medicamento',
      'descricao': 'Descricao',
      'hora_alarme': '23:09:00',
      'dias_uso': 'Segunda',
      'ativo': true,
      'intervalo': '12 em 12h',
      'medicamento_id': 42,
      'usuario_medicamento_id': 'vinculo',
    });
    expect(alarme.id, '7');
    expect(alarme.horario, const TimeOfDay(hour: 23, minute: 9));
    expect(alarme.diasDeUso, 'Segunda');
    expect(alarme.intervalo, '12 em 12h');
    expect(alarme.medicamentoId, 42);
    expect(alarme.usuarioMedicamentoId, 'vinculo');
  });
}
