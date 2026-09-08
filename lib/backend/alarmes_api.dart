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
