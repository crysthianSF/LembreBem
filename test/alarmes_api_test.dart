import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lembrebem/backend/alarmes_api.dart';
import 'package:lembrebem/backend/app_api.dart';
import 'package:lembrebem/backend/whatsapp_api.dart';
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

  Map<String, dynamic>? doseSalva;
  Map<String, dynamic>? doseAtualizada;
  Map<String, dynamic>? doseHoje;
  List<Map<String, dynamic>> contatosNotificacao = [];
  bool falharAoSalvarDose = false;

  @override
  Future<Map<String, dynamic>> salvarRegistroDose({
    required Map<String, dynamic> payload,
  }) async {
    if (falharAoSalvarDose) throw StateError('Falha ao salvar');
    doseSalva = payload;
    return {'id': 'dose-1', ...payload};
  }

  @override
  Future<Map<String, dynamic>> atualizarRegistroDose({
    required String doseId,
    required Map<String, dynamic> payload,
  }) async {
    doseAtualizada = {'id': doseId, ...payload};
    return doseAtualizada!;
  }

  @override
  Future<Map<String, dynamic>?> buscarRegistroDoseHojePorAlarme({
    required String usuarioId,
    required String alarmeId,
    required DateTime data,
  }) async {
    return doseHoje;
  }

  @override
  Future<List<Map<String, dynamic>>> buscarContatosNotificacaoCuidador({
    required String pacienteId,
  }) async {
    return contatosNotificacao;
  }
}

class _WhatsAppMemoria extends WhatsAppApi {
  String? doseId;
  Object? erro;
  ResultadoEnvioWhatsApp resultado = const ResultadoEnvioWhatsApp(
    status: 'accepted',
    aceitos: 1,
  );

  @override
  Future<ResultadoEnvioWhatsApp> enviarAlertaDosePerdida({
    required String doseId,
  }) async {
    this.doseId = doseId;
    if (erro != null) throw erro!;
    return resultado;
  }
}

void main() {
  late _AppApiMemoria app;
  late AlarmesApi alarmes;
  late _WhatsAppMemoria whatsapp;

  setUp(() {
    app = _AppApiMemoria();
    whatsapp = _WhatsAppMemoria();
    alarmes = AlarmesApi(appApi: app, whatsAppApi: whatsapp);
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

  test(
    'registrarDoseTomada salva novo registro quando nao existe registro previo',
    () async {
      final horario = DateTime(2026, 11, 21, 8, 0);
      final resultado = await alarmes.registrarDoseTomada(
        alarmeId: 'alarme-1',
        medicamentoNome: 'Dipirona',
        horarioPrevisto: horario,
        dose: '500mg',
        usuarioId: 'user-123',
      );

      expect(resultado['id'], 'dose-1');
      expect(app.doseSalva, isNotNull);
      expect(app.doseSalva!['usuario_id'], 'user-123');
      expect(app.doseSalva!['alarme_id'], 'alarme-1');
      expect(app.doseSalva!['medicamento_nome'], 'Dipirona');
      expect(app.doseSalva!['dose'], '500mg');
      expect(app.doseSalva!['status'], 'tomada');
      expect(app.doseSalva!['horario_previsto'], horario.toIso8601String());
    },
  );

  test(
    'registrarDoseTomada atualiza registro previo pendente para tomada',
    () async {
      final horario = DateTime(2026, 11, 21, 8, 0);
      app.doseHoje = {
        'id': 'dose-existente',
        'usuario_id': 'user-123',
        'alarme_id': 'alarme-1',
        'status': 'pendente',
      };

      final resultado = await alarmes.registrarDoseTomada(
        alarmeId: 'alarme-1',
        medicamentoNome: 'Dipirona',
        horarioPrevisto: horario,
        dose: '1cp',
        usuarioId: 'user-123',
      );

      expect(resultado['id'], 'dose-existente');
      expect(resultado['status'], 'tomada');
      expect(resultado['dose'], '1cp');
      expect(app.doseAtualizada, isNotNull);
      expect(app.doseAtualizada!['status'], 'tomada');
    },
  );

  test(
    'Dose perdida é salva e encaminhada ao servidor pelo ID persistido',
    () async {
      final horario = DateTime(2026, 11, 21, 8, 0);
      app.contatosNotificacao = [
        {
          'tipo': 'cuidador',
          'nome': 'Maria Cuidadora',
          'email': 'maria@teste.com',
        },
        {
          'tipo': 'emergencia',
          'nome': 'Carlos Filho',
          'telefone': '11999999999',
        },
      ];

      final resultado = await alarmes.registrarDosePerdidaEEscalar(
        alarmeId: 'alarme-1',
        medicamentoNome: 'Losartana',
        horarioPrevisto: horario,
        usuarioId: 'user-123',
      );

      expect(resultado['sucesso'], isTrue);
      expect(resultado['notificacao']['status'], 'accepted');
      expect(resultado['medicamento'], 'Losartana');
      expect(whatsapp.doseId, 'dose-1');
      expect(app.doseSalva!['status'], 'perdida');
    },
  );

  test(
    'Falha no WhatsApp preserva a dose perdida e informa falha real',
    () async {
      whatsapp.erro = const WhatsAppException('NOT_CONFIGURED');
      final resultado = await alarmes.registrarDosePerdidaEEscalar(
        alarmeId: 'a',
        medicamentoNome: 'Medicamento',
        horarioPrevisto: DateTime(2026, 11, 23, 8),
        usuarioId: 'u',
      );
      expect(app.doseSalva!['status'], 'perdida');
      expect(resultado['sucesso'], isTrue);
      expect(resultado['notificacao']['status'], 'failed');
      expect(resultado['erro_notificacao'], 'NOT_CONFIGURED');
      expect(resultado['mensagem_notificacao'], contains('Não foi possível'));
    },
  );

  test(
    'Timeout no aviso mantém a dose e sinaliza envio desconhecido',
    () async {
      whatsapp.erro = const WhatsAppException('TIMEOUT');
      final resultado = await alarmes.registrarDosePerdidaEEscalar(
        alarmeId: 'a',
        medicamentoNome: 'Medicamento',
        horarioPrevisto: DateTime(2026, 11, 23, 8),
        usuarioId: 'u',
      );
      expect(app.doseSalva!['status'], 'perdida');
      expect(resultado['notificacao']['status'], 'unknown');
      expect(resultado['mensagem_notificacao'], contains('confirmar'));
    },
  );

  test(
    'Sem contatos autorizados não afirma que um aviso foi enviado',
    () async {
      whatsapp.resultado = const ResultadoEnvioWhatsApp(
        status: 'skipped',
        ignorados: 1,
      );
      final resultado = await alarmes.registrarDosePerdidaEEscalar(
        alarmeId: 'a',
        medicamentoNome: 'Medicamento',
        horarioPrevisto: DateTime(2026, 11, 23, 8),
        usuarioId: 'u',
      );
      expect(resultado['notificacao']['status'], 'skipped');
      expect(resultado['mensagem_notificacao'], contains('Nenhum contato'));
    },
  );

  test('Falha ao gravar a dose impede tentativa de WhatsApp', () async {
    app.falharAoSalvarDose = true;
    await expectLater(
      alarmes.registrarDosePerdidaEEscalar(
        alarmeId: 'a',
        medicamentoNome: 'Medicamento',
        horarioPrevisto: DateTime(2026, 11, 23, 8),
        usuarioId: 'u',
      ),
      throwsStateError,
    );
    expect(whatsapp.doseId, isNull);
  });

  test(
    'verificarDoseJaTomadaHoje retorna true se status for tomada e false caso contrario',
    () async {
      final hoje = DateTime.now();

      // Sem registro
      app.doseHoje = null;
      expect(
        await alarmes.verificarDoseJaTomadaHoje(
          alarmeId: 'a1',
          data: hoje,
          usuarioId: 'u1',
        ),
        isFalse,
      );

      // Registro pendente
      app.doseHoje = {'id': 'd1', 'status': 'pendente'};
      expect(
        await alarmes.verificarDoseJaTomadaHoje(
          alarmeId: 'a1',
          data: hoje,
          usuarioId: 'u1',
        ),
        isFalse,
      );

      // Registro tomada
      app.doseHoje = {'id': 'd1', 'status': 'tomada'};
      expect(
        await alarmes.verificarDoseJaTomadaHoje(
          alarmeId: 'a1',
          data: hoje,
          usuarioId: 'u1',
        ),
        isTrue,
      );
    },
  );
}
