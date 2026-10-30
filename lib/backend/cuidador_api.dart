import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CuidadorApi {
  static const Duration _timeout = Duration(seconds: 10);

  SupabaseQuerySchema get _app => SupabaseBackend.appSchema;
  Future<Map<String, dynamic>?> buscarCuidadorAtual() async {
    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null) {
      return null;
    }

    final response = await _app
        .from('cuidadores')
        .select()
        .eq('id', user.id)
        .maybeSingle()
        .timeout(_timeout);

    if (response == null) {
      return null;
    }
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> registrarCuidador({
    required String nome,
    required String email,
    String? registroProfissional,
  }) async {
    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null) {
      throw StateError('Nenhum usuario autenticado.');
    }

    await _app
        .from('cuidadores')
        .upsert({
          'id': user.id,
          'nome': nome,
          'email': email,
          'registro_profissional': registroProfissional,
        })
        .timeout(_timeout);
  }

  Future<void> vincularPaciente({required String codigo}) async {
    await _app
        .rpc('vincular_paciente', params: {'codigo': codigo})
        .timeout(_timeout);
  }

  Future<List<Map<String, dynamic>>> listarPacientes() async {
    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null) {
      throw StateError('Nenhum usuario autenticado.');
    }

    final vinculos = await _app
        .from('cuidador_pacientes')
        .select('paciente_id, vinculado_em')
        .eq('cuidador_id', user.id)
        .timeout(_timeout);

    final ids =
        (vinculos as List)
            .map((v) => (v as Map)['paciente_id']?.toString())
            .whereType<String>()
            .toList();

    if (ids.isEmpty) {
      return const [];
    }

    final pacientes = await _app
        .from('usuarios')
        .select()
        .inFilter('id', ids)
        .timeout(_timeout);

    return (pacientes as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> desvincularPaciente({required String pacienteId}) async {
    final user = SupabaseBackend.client.auth.currentUser;
    if (user == null) {
      throw StateError('Nenhum usuario autenticado.');
    }

    await _app
        .from('cuidador_pacientes')
        .delete()
        .eq('cuidador_id', user.id)
        .eq('paciente_id', pacienteId)
        .timeout(_timeout);
  }

  Future<List<Map<String, dynamic>>> listarDosesDeHoje({
    required String pacienteId,
  }) async {
    final inicio = DateTime.now();
    final inicioDia = DateTime(inicio.year, inicio.month, inicio.day);
    final fimDia = inicioDia.add(const Duration(days: 1));

    final response = await _app
        .from('registro_doses')
        .select()
        .eq('usuario_id', pacienteId)
        .gte('horario_previsto', inicioDia.toIso8601String())
        .lt('horario_previsto', fimDia.toIso8601String())
        .order('horario_previsto', ascending: true)
        .timeout(_timeout);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listarDosesPeriodo({
    required String pacienteId,
    required int dias,
  }) async {
    final agora = DateTime.now();
    final inicio = DateTime(
      agora.year,
      agora.month,
      agora.day,
    ).subtract(Duration(days: dias - 1));

    final response = await _app
        .from('registro_doses')
        .select()
        .eq('usuario_id', pacienteId)
        .gte('horario_previsto', inicio.toIso8601String())
        .order('horario_previsto', ascending: true)
        .timeout(_timeout);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> adesaoSemanal({
    required String pacienteId,
  }) async {
    final doses = await listarDosesPeriodo(pacienteId: pacienteId, dias: 7);
    const rotulos = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];

    final porDia = <int, List<Map<String, dynamic>>>{};
    for (final dose in doses) {
      final horario = DateTime.tryParse(
        dose['horario_previsto']?.toString() ?? '',
      );
      if (horario == null) {
        continue;
      }
      porDia.putIfAbsent(horario.weekday, () => []).add(dose);
    }

    return List.generate(7, (i) {
      final weekday = i + 1;
      final dosesDia = porDia[weekday] ?? const [];
      if (dosesDia.isEmpty) {
        return {'dia': rotulos[i], 'taxa': null};
      }
      final tomadas =
          dosesDia
              .where(
                (d) => d['status'] == 'tomada' || d['status'] == 'atrasada',
              )
              .length;
      return {
        'dia': rotulos[i],
        'taxa': ((tomadas / dosesDia.length) * 100).round(),
      };
    });
  }

  /// Emite convite de vínculo SEC-01:
  Future<String> emitirConviteCuidador({required String cuidadorId}) async {
    final user = _app.auth.currentUser;
    if (user == null) {
      throw StateError('Usuário precisa estar autenticado como paciente.');
    }

    // Gera um token aleatório único para a tentativa
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final tokenOriginal = 'conv_${user.id.substring(0, 8)}_$timestamp';

    // Chama a RPC passando estritamente o cuidador de destino e o token gerado
    await _app.rpc('emitir_convite_paciente', params: {
      'p_cuidador_id': cuidadorId,
      'p_token_hash': tokenOriginal,
    }).timeout(_timeout);

    return tokenOriginal;
  }

}
