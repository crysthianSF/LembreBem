import 'package:flutter/material.dart';
import 'package:lembrebem/backend/app_api.dart';
import 'package:lembrebem/backend/supabase_backend.dart';

class AlarmesApi {
  AlarmesApi({AppApi? appApi}) : _appApi = appApi ?? AppApi();

  final AppApi _appApi;

  Future<void> salvarNovoAlarme({
    required String nome,
    required String observacoes,
    required TimeOfDay horario,
    required String diasDeUso,
    required bool ativado,
    required String intervalo,
    required String usuarioId,
    int? medicamentoId,
    String? usuarioMedicamentoId,
  }) async {
    if (usuarioId.isEmpty) {
      throw StateError('Usuario nao autenticado para salvar alarme.');
    }

    final dataHoje = DateTime.now();
    final dataAlarme =
        "${dataHoje.year.toString().padLeft(4, '0')}-${dataHoje.month.toString().padLeft(2, '0')}-${dataHoje.day.toString().padLeft(2, '0')}";
    final horaAlarme =
        "${horario.hour.toString().padLeft(2, '0')}:${horario.minute.toString().padLeft(2, '0')}:00";

    String? usuarioMedicamentoIdFinal = usuarioMedicamentoId;
    if (usuarioMedicamentoIdFinal == null && medicamentoId != null) {
      usuarioMedicamentoIdFinal = await _garantirUsuarioMedicamento(
        usuarioId: usuarioId,
        medicamentoId: medicamentoId,
        apelido: nome,
      );
    }

    final novoAlarme = {
      'usuario_id': usuarioId,
      'titulo': nome,
      'descricao': observacoes,
      'data_alarme': dataAlarme,
      'hora_alarme': horaAlarme,
      'repetir': false,
      'ativo': ativado,
      'created_at': DateTime.now().toIso8601String(),
      if (usuarioMedicamentoIdFinal != null)
        'usuario_medicamento_id': usuarioMedicamentoIdFinal,
    };

    await _appApi.criarAlarme(payload: novoAlarme);
  }

  Future<void> atualizarAlarme({
    required String id,
    required String nome,
    required String observacoes,
    required TimeOfDay horario,
    required bool ativado,
    String? diasDeUso,
    String? intervalo,
    int? medicamentoId,
    String? usuarioMedicamentoId,
  }) async {
    final usuarioId = SupabaseBackend.client.auth.currentUser?.id;
    if (usuarioId == null) {
      throw StateError('Usuario nao autenticado para atualizar alarme.');
    }

    final horaAlarme =
        "${horario.hour.toString().padLeft(2, '0')}:${horario.minute.toString().padLeft(2, '0')}:00";

    final dadosAtualizados = <String, dynamic>{
      'titulo': nome,
      'descricao': observacoes,
      'hora_alarme': horaAlarme,
      'ativo': ativado,
    };

    String? usuarioMedicamentoIdFinal = usuarioMedicamentoId;
    if (usuarioMedicamentoIdFinal == null && medicamentoId != null) {
      usuarioMedicamentoIdFinal = await _garantirUsuarioMedicamento(
        usuarioId: usuarioId,
        medicamentoId: medicamentoId,
        apelido: nome,
      );
    }
    if (usuarioMedicamentoIdFinal != null) {
      dadosAtualizados['usuario_medicamento_id'] = usuarioMedicamentoIdFinal;
    }

    await _appApi.atualizarAlarme(
      usuarioId: usuarioId,
      alarmeId: id,
      payload: dadosAtualizados,
    );
  }

  Future<Map<String, dynamic>> registrarDoseTomada({
    required String alarmeId,
    required String medicamentoNome,
    required DateTime horarioPrevisto,
    String? dose,
    String? usuarioId,
  }) async {
    final uid = usuarioId ?? SupabaseBackend.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw StateError('Usuario nao autenticado para registrar dose.');
    }

    final existente = await _appApi.buscarRegistroDoseHojePorAlarme(
      usuarioId: uid,
      alarmeId: alarmeId,
      data: horarioPrevisto,
    );

    if (existente != null && existente['id'] != null) {
      return await _appApi.atualizarRegistroDose(
        doseId: existente['id'].toString(),
        payload: {
          'status': 'tomada',
          'registrado_em': DateTime.now().toIso8601String(),
          if (dose != null && dose.isNotEmpty) 'dose': dose,
        },
      );
    }

    return await _appApi.salvarRegistroDose(
      payload: {
        'usuario_id': uid,
        'alarme_id': alarmeId,
        'medicamento_nome': medicamentoNome,
        if (dose != null && dose.isNotEmpty) 'dose': dose,
        'horario_previsto': horarioPrevisto.toIso8601String(),
        'status': 'tomada',
        'registrado_em': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<Map<String, dynamic>> registrarDosePerdidaEEscalar({
    required String alarmeId,
    required String medicamentoNome,
    required DateTime horarioPrevisto,
    String? dose,
    String? usuarioId,
  }) async {
    final uid = usuarioId ?? SupabaseBackend.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw StateError('Usuario nao autenticado para registrar dose perdida.');
    }

    Map<String, dynamic> doseSalva;
    final existente = await _appApi.buscarRegistroDoseHojePorAlarme(
      usuarioId: uid,
      alarmeId: alarmeId,
      data: horarioPrevisto,
    );

    if (existente != null && existente['id'] != null) {
      doseSalva = await _appApi.atualizarRegistroDose(
        doseId: existente['id'].toString(),
        payload: {
          'status': 'perdida',
          'registrado_em': DateTime.now().toIso8601String(),
          if (dose != null && dose.isNotEmpty) 'dose': dose,
        },
      );
    } else {
      doseSalva = await _appApi.salvarRegistroDose(
        payload: {
          'usuario_id': uid,
          'alarme_id': alarmeId,
          'medicamento_nome': medicamentoNome,
          if (dose != null && dose.isNotEmpty) 'dose': dose,
          'horario_previsto': horarioPrevisto.toIso8601String(),
          'status': 'perdida',
          'registrado_em': DateTime.now().toIso8601String(),
        },
      );
    }

    final contatosNotificacao = await _appApi.buscarContatosNotificacaoCuidador(
      pacienteId: uid,
    );

    return {
      'sucesso': true,
      'dose': doseSalva,
      'precisa_notificar': true,
      'motivo': 'Paciente nao confirmou o medicamento apos os avisos do alarme.',
      'medicamento': medicamentoNome,
      'horario_previsto': horarioPrevisto.toIso8601String(),
      'destinatarios': contatosNotificacao,
    };
  }

  Future<bool> verificarDoseJaTomadaHoje({
    required String alarmeId,
    required DateTime data,
    String? usuarioId,
  }) async {
    final uid = usuarioId ?? SupabaseBackend.client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      return false;
    }

    final registro = await _appApi.buscarRegistroDoseHojePorAlarme(
      usuarioId: uid,
      alarmeId: alarmeId,
      data: data,
    );

    return registro != null && registro['status'] == 'tomada';
  }

  Future<String?> _garantirUsuarioMedicamento({
    required String usuarioId,
    required int medicamentoId,
    required String apelido,
  }) async {
    final existente = await _appApi.buscarUsuarioMedicamentoPorMedicamentoId(
      usuarioId: usuarioId,
      medicamentoId: medicamentoId,
    );

    if (existente != null) {
      return existente['id']?.toString();
    }

    final criado = await _appApi.salvarUsuarioMedicamento(
      payload: {
        'usuario_id': usuarioId,
        'medicamento_id': medicamentoId,
        'apelido': apelido,
        'ativo': true,
      },
    );

    return criado['id']?.toString();
  }
}
