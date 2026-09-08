import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritosApi {
  static const Duration _timeout = Duration(seconds: 10);

  SupabaseQuerySchema get _app => SupabaseBackend.appSchema;

  Future<List<Map<String, dynamic>>> listarFavoritos({
    required String usuarioId,
  }) async {
    final response = await _app
        .from('favoritos')
        .select()
        .eq('usuario_id', usuarioId)
        .order('criado_em', ascending: false)
        .timeout(_timeout);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Set<int>> listarIdsFavoritos({required String usuarioId}) async {
    final favoritos = await listarFavoritos(usuarioId: usuarioId);
    return favoritos
        .map((f) => (f['medicamento_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
  }

  Future<void> adicionarFavorito({
    required String usuarioId,
    required int medicamentoId,
  }) async {
    await _app
        .from('favoritos')
        .upsert({
          'usuario_id': usuarioId,
          'medicamento_id': medicamentoId,
        }, onConflict: 'usuario_id,medicamento_id')
        .timeout(_timeout);
  }

  Future<void> removerFavorito({
    required String usuarioId,
    required int medicamentoId,
  }) async {
    await _app
        .from('favoritos')
        .delete()
        .eq('usuario_id', usuarioId)
        .eq('medicamento_id', medicamentoId)
        .timeout(_timeout);
  }

  Future<bool> alternarFavorito({
    required String usuarioId,
    required int medicamentoId,
    required bool favoritadoAtual,
  }) async {
    if (favoritadoAtual) {
      await removerFavorito(usuarioId: usuarioId, medicamentoId: medicamentoId);
      return false;
    }
    await adicionarFavorito(usuarioId: usuarioId, medicamentoId: medicamentoId);
    return true;
  }
}
