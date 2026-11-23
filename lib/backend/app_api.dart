import 'package:lembrebem/backend/local_cache.dart';
import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppApi {
  static const Duration _requestTimeout = Duration(seconds: 10);

  SupabaseQuerySchema get _app => SupabaseBackend.appSchema;
  final LocalCache _localCache = LocalCache();

  Future<void> handleNewUser() async {
    await _comTimeout(
      _app.rpc('handle_new_user'),
      duration: const Duration(seconds: 6),
    );
  }

  Future<void> ensureUsuarioAtual() async {
    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null) {
      throw StateError('Nenhum usuario autenticado para sincronizar perfil.');
    }

    try {
      await handleNewUser();
      return;
    } catch (_) {}

    final existente = await _comTimeout(
      _app.from('usuarios').select('id').eq('id', user.id).maybeSingle(),
      duration: const Duration(seconds: 6),
    );

    if (existente != null) {
      return;
    }

    await _comTimeout(
      _app.from('usuarios').insert({
        'id': user.id,
        'email': user.email,
        'nome': user.userMetadata?['name'] ?? user.email ?? '',
      }),
      duration: const Duration(seconds: 6),
    );
  }

  Future<Map<String, dynamic>> buscarUsuarioAtual() async {
    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null) {
      throw StateError('Nenhum usuario autenticado.');
    }

    await ensureUsuarioAtual();

    final response = await _comTimeout(
      _app.from('usuarios').select().eq('id', user.id).maybeSingle(),
    );

    if (response == null) {
      throw StateError('Perfil do usuario nao encontrado em app.usuarios.');
    }

    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> salvarUsuarioAtual({
    required Map<String, dynamic> payload,
  }) async {
    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null) {
      throw StateError('Nenhum usuario autenticado.');
    }

    await ensureUsuarioAtual();

    final response = await _comTimeout(
      _app
          .from('usuarios')
          .update(payload)
          .eq('id', user.id)
          .select()
          .maybeSingle(),
    );

    if (response == null) {
      throw StateError('Falha ao salvar dados do perfil.');
    }

    return Map<String, dynamic>.from(response as Map);
  }

  Future<List<Map<String, dynamic>>> listarAlarmesDoUsuario({
    required String usuarioId,
  }) async {
    try {
      final response = await _comTimeout(
        _app
            .from('alarmes')
            .select()
            .eq('usuario_id', usuarioId)
            .order('hora_alarme', ascending: true),
      );

      final dados = _asListOfMap(response);
      await _localCache.salvarAlarmesUsuario(usuarioId, dados);
      return dados;
    } catch (_) {
      return _localCache.carregarAlarmesUsuario(usuarioId);
    }
  }

  Future<Map<String, dynamic>> criarAlarme({
    required Map<String, dynamic> payload,
  }) async {
    final response = await _comTimeout(
      _app.from('alarmes').insert(payload).select().maybeSingle(),
    );

    if (response == null) {
      throw StateError('Falha ao inserir alarme.');
    }

    final salvo = Map<String, dynamic>.from(response as Map);
    final usuarioId = payload['usuario_id']?.toString();
    if (usuarioId != null && usuarioId.isNotEmpty) {
      await _localCache.upsertAlarmeUsuario(usuarioId, salvo);
    }
    return salvo;
  }

  Future<Map<String, dynamic>> atualizarAlarme({
    required String usuarioId,
    required String alarmeId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _comTimeout(
      _app
          .from('alarmes')
          .update(payload)
          .eq('id', alarmeId)
          .eq('usuario_id', usuarioId)
          .select()
          .maybeSingle(),
    );

    if (response == null) {
      throw StateError('Falha ao atualizar alarme $alarmeId.');
    }

    final atualizado = Map<String, dynamic>.from(response as Map);
    await _localCache.upsertAlarmeUsuario(usuarioId, atualizado);
    return atualizado;
  }

  Future<void> alternarStatusAlarme({
    required String usuarioId,
    required String alarmeId,
    required bool ativo,
  }) async {
    await _comTimeout(
      _app
          .from('alarmes')
          .update({'ativo': ativo})
          .eq('id', alarmeId)
          .eq('usuario_id', usuarioId),
    );
    await _localCache.alternarStatusAlarmeUsuario(usuarioId, alarmeId, ativo);
  }

  Future<void> deletarAlarme({
    required String usuarioId,
    required String alarmeId,
  }) async {
    await _comTimeout(
      _app
          .from('alarmes')
          .delete()
          .eq('id', alarmeId)
          .eq('usuario_id', usuarioId),
    );
    await _localCache.removerAlarmeUsuario(usuarioId, alarmeId);
  }

  Future<List<Map<String, dynamic>>> listarUsuarioMedicamentos({
    required String usuarioId,
  }) async {
    try {
      final response = await _comTimeout(
        _app.from('usuario_medicamentos').select().eq('usuario_id', usuarioId),
      );
      final dados = _asListOfMap(response);
      await _localCache.salvarUsuarioMedicamentos(usuarioId, dados);
      return dados;
    } catch (_) {
      return _localCache.carregarUsuarioMedicamentos(usuarioId);
    }
  }

  Future<Map<String, dynamic>> salvarUsuarioMedicamento({
    required Map<String, dynamic> payload,
  }) async {
    final response = await _comTimeout(
      _app.from('usuario_medicamentos').insert(payload).select().maybeSingle(),
    );

    if (response == null) {
      throw StateError('Falha ao inserir usuario_medicamentos.');
    }

    final salvo = Map<String, dynamic>.from(response as Map);
    final usuarioId = payload['usuario_id']?.toString();
    if (usuarioId != null && usuarioId.isNotEmpty) {
      await _localCache.upsertUsuarioMedicamento(usuarioId, salvo);
    }
    return salvo;
  }

  Future<Map<String, dynamic>?> buscarUsuarioMedicamentoPorMedicamentoId({
    required String usuarioId,
    required int medicamentoId,
  }) async {
    try {
      final response = await _comTimeout(
        _app
            .from('usuario_medicamentos')
            .select()
            .eq('usuario_id', usuarioId)
            .eq('medicamento_id', medicamentoId)
            .limit(1)
            .maybeSingle(),
      );

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response as Map);
    } catch (_) {
      final cache = await _localCache.carregarUsuarioMedicamentos(usuarioId);
      for (final item in cache) {
        final id = item['medicamento_id'];
        if (id is num && id.toInt() == medicamentoId) {
          return item;
        }
        if (id?.toString() == medicamentoId.toString()) {
          return item;
        }
      }
      return null;
    }
  }

  Future<void> deletarUsuarioMedicamento({
    required String usuarioId,
    required String usuarioMedicamentoId,
    int? medicamentoId,
  }) async {
    final respostaPorId = await _comTimeout(
      _app
          .from('usuario_medicamentos')
          .delete()
          .eq('id', usuarioMedicamentoId)
          .eq('usuario_id', usuarioId)
          .select('id, medicamento_id'),
    );
    await _localCache.removerUsuarioMedicamento(
      usuarioId,
      usuarioMedicamentoId,
    );

    final removidosPorId = _asListOfMap(respostaPorId);
    if (removidosPorId.isNotEmpty) {
      if (medicamentoId != null) {
        await _localCache.removerUsuarioMedicamentoPorMedicamentoId(
          usuarioId,
          medicamentoId,
        );
      }
      return;
    }

    if (medicamentoId == null) {
      throw StateError('Medicamento nao encontrado para exclusao.');
    }

    final respostaPorMedicamentoId = await _comTimeout(
      _app
          .from('usuario_medicamentos')
          .delete()
          .eq('usuario_id', usuarioId)
          .eq('medicamento_id', medicamentoId)
          .select('id, medicamento_id'),
    );

    final removidosPorMedicamentoId = _asListOfMap(respostaPorMedicamentoId);
    if (removidosPorMedicamentoId.isEmpty) {
      throw StateError('Medicamento nao encontrado para exclusao.');
    }

    await _localCache.removerUsuarioMedicamentoPorMedicamentoId(
      usuarioId,
      medicamentoId,
    );
  }

  Future<Map<String, dynamic>> salvarRegistroDose({
    required Map<String, dynamic> payload,
  }) async {
    final response = await _comTimeout(
      _app.from('registro_doses').insert(payload).select().maybeSingle(),
    );

    if (response == null) {
      throw StateError('Falha ao salvar registro de dose.');
    }

    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>> atualizarRegistroDose({
    required String doseId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _comTimeout(
      _app
          .from('registro_doses')
          .update(payload)
          .eq('id', doseId)
          .select()
          .maybeSingle(),
    );

    if (response == null) {
      throw StateError('Falha ao atualizar registro de dose.');
    }

    return Map<String, dynamic>.from(response as Map);
  }

  Future<Map<String, dynamic>?> buscarRegistroDoseHojePorAlarme({
    required String usuarioId,
    required String alarmeId,
    required DateTime data,
  }) async {
    final inicioDia = DateTime(data.year, data.month, data.day);
    final fimDia = inicioDia.add(const Duration(days: 1));

    try {
      final response = await _comTimeout(
        _app
            .from('registro_doses')
            .select()
            .eq('usuario_id', usuarioId)
            .eq('alarme_id', alarmeId)
            .gte('horario_previsto', inicioDia.toIso8601String())
            .lt('horario_previsto', fimDia.toIso8601String())
            .order('horario_previsto', ascending: false)
            .limit(1)
            .maybeSingle(),
      );

      if (response == null) {
        return null;
      }
      return Map<String, dynamic>.from(response as Map);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> buscarContatosNotificacaoCuidador({
    required String pacienteId,
  }) async {
    final contatos = <Map<String, dynamic>>[];

    try {
      final respostaEmergencia = await _comTimeout(
        _app
            .from('contatos_emergencia')
            .select('nome, telefone')
            .eq('usuario_id', pacienteId),
      );
      for (final item in _asListOfMap(respostaEmergencia)) {
        contatos.add({
          'tipo': 'emergencia',
          'nome': item['nome']?.toString() ?? '',
          'telefone': item['telefone']?.toString() ?? '',
        });
      }
    } catch (_) {}

    try {
      final vinculos = await _comTimeout(
        _app
            .from('cuidador_pacientes')
            .select('cuidador_id')
            .eq('paciente_id', pacienteId),
      );
      final ids =
          _asListOfMap(vinculos)
              .map((v) => v['cuidador_id']?.toString())
              .whereType<String>()
              .toList();

      if (ids.isNotEmpty) {
        final cuidadores = await _comTimeout(
          _app
              .from('cuidadores')
              .select('id, nome, email')
              .inFilter('id', ids),
        );
        for (final c in _asListOfMap(cuidadores)) {
          contatos.add({
            'tipo': 'cuidador',
            'id': c['id']?.toString() ?? '',
            'nome': c['nome']?.toString() ?? '',
            'email': c['email']?.toString() ?? '',
          });
        }
      }
    } catch (_) {}

    return contatos;
  }

  Future<T> _comTimeout<T>(Future<T> request, {Duration? duration}) {
    return request.timeout(duration ?? _requestTimeout);
  }

  List<Map<String, dynamic>> _asListOfMap(dynamic data) {
    if (data == null) {
      return const [];
    }
    final list = data as List;
    return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
