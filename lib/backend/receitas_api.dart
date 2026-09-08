import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReceitasApi {
  static const Duration _timeout = Duration(seconds: 20);

  SupabaseQuerySchema get _app => SupabaseBackend.appSchema;

  Future<List<Map<String, dynamic>>> listarReceitas({
    required String usuarioId,
  }) async {
    final response = await _app
        .from('receitas')
        .select('id, nome, nome_arquivo, criado_em')
        .eq('usuario_id', usuarioId)
        .order('criado_em', ascending: false)
        .timeout(_timeout);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> salvarReceita({
    required String usuarioId,
    required String nome,
    required String nomeArquivo,
    String? arquivoBase64,
  }) async {
    final response = await _app
        .from('receitas')
        .insert({
          'usuario_id': usuarioId,
          'nome': nome,
          'nome_arquivo': nomeArquivo,
          'arquivo_base64': arquivoBase64,
        })
        .select('id, nome, nome_arquivo, criado_em')
        .maybeSingle()
        .timeout(_timeout);

    if (response == null) {
      throw StateError('Falha ao salvar receita.');
    }
    return Map<String, dynamic>.from(response as Map);
  }

  Future<String?> buscarArquivoBase64({required String receitaId}) async {
    final response = await _app
        .from('receitas')
        .select('arquivo_base64')
        .eq('id', receitaId)
        .maybeSingle()
        .timeout(_timeout);

    if (response == null) {
      return null;
    }
    return (response as Map)['arquivo_base64'] as String?;
  }

  Future<void> deletarReceita({required String receitaId}) async {
    await _app.from('receitas').delete().eq('id', receitaId).timeout(_timeout);
  }
}
