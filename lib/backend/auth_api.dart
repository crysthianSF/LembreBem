import 'dart:async';

import 'package:lembrebem/backend/app_api.dart';
import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthApi {
  AuthApi({AppApi? appApi}) : _appApi = appApi ?? AppApi();

  static const Duration _authTimeout = Duration(seconds: 12);
  static const Duration _profileSyncTimeout = Duration(seconds: 8);

  final AppApi _appApi;

  Future<User?> loginComEmailSenha({
    required String email,
    required String senha,
  }) async {
    final response = await SupabaseBackend.client.auth
        .signInWithPassword(email: email, password: senha)
        .timeout(_authTimeout);

    if (response.user != null) {
      unawaited(_sincronizarPerfilAposLogin());
    }

    return response.user;
  }

  Future<void> _sincronizarPerfilAposLogin() async {
    try {
      await _appApi.ensureUsuarioAtual().timeout(_profileSyncTimeout);
    } catch (_) {}
  }

  Future<void> alterarSenha({
    required String novaSenha,
  }) async {
    if (novaSenha.isEmpty) {
      throw ArgumentError('A nova senha não pode estar vazia.');
    }

    final auth = SupabaseBackend.client.auth;

    // Confere se existe uma sessão e um usuário autenticado.
    if (auth.currentSession == null || auth.currentUser == null) {
      throw StateError(
        'Sua sessão expirou. Entre novamente na sua conta.',
      );
    }

    final response = await auth
        .updateUser(
          UserAttributes(password: novaSenha),
        )
        .timeout(_authTimeout);

    if (response.user == null) {
      throw StateError(
        'Não foi possível confirmar a alteração da senha.',
      );
    }
  }

  Future<void> logout() async {
    await SupabaseBackend.client.auth.signOut();
  }
}