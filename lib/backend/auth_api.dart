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

  Future<void> logout() async {
    await SupabaseBackend.client.auth.signOut();
  }

  /// Dispara o envio do codigo OTP de recuperacao para o e-mail informado.
  /// Para mitigar Account Enumeration, nao revela se o e-mail existe no banco.
  Future<void> solicitarCodigoRecuperacao(String email) async {
    final emailFormatado = email.trim().toLowerCase();
    try {
      await SupabaseBackend.client.auth
          .resetPasswordForEmail(emailFormatado)
          .timeout(_authTimeout);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      // Silencia "user not found" para prevenir enumeracao de contas
      if (msg.contains('user not found') || msg.contains('not found')) {
        return;
      }
      rethrow;
    }
  }

  /// Valida o codigo OTP de 6 digitos recebido por e-mail.
  /// Se valido, o Supabase autentica uma sessao temporaria de recuperacao.
  Future<AuthResponse> verificarCodigoRecuperacao({
    required String email,
    required String codigo,
  }) async {
    return await SupabaseBackend.client.auth
        .verifyOTP(
          email: email.trim().toLowerCase(),
          token: codigo.trim(),
          type: OtpType.recovery,
        )
        .timeout(_authTimeout);
  }

  /// Atualiza a senha do usuario na sessao de recuperacao
  /// e encerra a sessao temporaria para exigir novo login manual.
  Future<void> atualizarSenha(String novaSenha) async {
    await SupabaseBackend.client.auth
        .updateUser(UserAttributes(password: novaSenha))
        .timeout(_authTimeout);
    await logout();
  }
}
