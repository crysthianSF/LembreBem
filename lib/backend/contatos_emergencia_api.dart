import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContatosEmergenciaApi {
  static const Duration _timeout = Duration(seconds: 10);

  SupabaseQuerySchema get _app => SupabaseBackend.appSchema;

  Future<List<Map<String, dynamic>>> listarContatos({
    required String usuarioId,
  }) async {
    final response = await _app
        .from('contatos_emergencia')
        .select()
        .eq('usuario_id', usuarioId)
        .order('criado_em', ascending: true)
        .timeout(_timeout);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> salvarContato({
    required String usuarioId,
    required String nome,
    required String telefone,
  }) async {
    final response = await _app
        .from('contatos_emergencia')
        .insert({'usuario_id': usuarioId, 'nome': nome, 'telefone': telefone})
        .select()
        .maybeSingle()
        .timeout(_timeout);

    if (response == null) {
      throw StateError('Falha ao salvar contato de emergencia.');
    }
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> deletarContato({required String contatoId}) async {
    await _app
        .from('contatos_emergencia')
        .delete()
        .eq('id', contatoId)
        .timeout(_timeout);
  }
}
