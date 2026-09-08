import 'dart:convert';

import 'package:lembrebem/backend/supabase_local_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBackend {
  SupabaseBackend._();

  static const String defaultUrl = 'https://xhtuoeiirivriwhoymog.supabase.co';
  static const String defaultAnonKeyPlaceholder =
      'sb_publishable_REPLACE_WITH_YOUR_PUBLIC_KEY';

  static const String _supabaseUrlFromEnv = String.fromEnvironment(
    'SUPABASE_URL',
  );

  static const String _supabaseAnonKeyFromEnv = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static String get supabaseUrl {
    if (_supabaseUrlFromEnv.trim().isNotEmpty) {
      return _supabaseUrlFromEnv.trim();
    }
    if (localSupabaseUrl.trim().isNotEmpty) {
      return localSupabaseUrl.trim();
    }
    return defaultUrl;
  }

  static String get supabaseAnonKey {
    if (_supabaseAnonKeyFromEnv.trim().isNotEmpty) {
      return _supabaseAnonKeyFromEnv.trim();
    }
    return localSupabaseAnonKey.trim();
  }

  static Future<void> initialize() async {
    final anonKey = supabaseAnonKey;

    if (anonKey.isEmpty ||
        anonKey == defaultAnonKeyPlaceholder ||
        anonKey == 'sb_publishable_REPLACE_WITH_YOUR_KEY' ||
        anonKey.endsWith('...')) {
      throw StateError(
        'Missing Supabase key. Set localSupabaseAnonKey in '
        'lib/backend/supabase_local_config.dart or run with '
        '--dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx',
      );
    }

    _validateSupabaseKeyProjectMatch(anonKey);

    await Supabase.initialize(url: supabaseUrl, anonKey: anonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;

  static SupabaseQuerySchema get appSchema => client.schema('app');
  static SupabaseQuerySchema get catalogoSchema => client.schema('catalogo');

  static void _validateSupabaseKeyProjectMatch(String anonKey) {
    if (anonKey.startsWith('sb_publishable_')) {
      if (anonKey.length < 40) {
        throw StateError(
          'SUPABASE_ANON_KEY parece invalida. Use a chave publica completa '
          'copiada de Settings > API.',
        );
      }
      return;
    }

    if (!anonKey.startsWith('eyJ')) {
      throw StateError(
        'SUPABASE_ANON_KEY invalida. Use uma chave publica sb_publishable_... '
        'ou a anon key JWT completa do projeto.',
      );
    }

    final keyProjectRef = _extractProjectRefFromJwt(anonKey);
    final urlProjectRef = _extractProjectRefFromUrl(supabaseUrl);

    if (keyProjectRef != null &&
        urlProjectRef != null &&
        keyProjectRef != urlProjectRef) {
      throw StateError(
        'SUPABASE_ANON_KEY pertence ao projeto "$keyProjectRef", mas '
        'SUPABASE_URL aponta para "$urlProjectRef".',
      );
    }
  }

  static String? _extractProjectRefFromUrl(String url) {
    try {
      final host = Uri.parse(url).host;
      if (host.isEmpty) {
        return null;
      }
      return host.split('.').first;
    } catch (_) {
      return null;
    }
  }

  static String? _extractProjectRefFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) {
        return null;
      }
      final payloadPart = parts[1];
      final normalized = base64Url.normalize(payloadPart);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) {
        final ref = payload['ref'];
        if (ref is String && ref.isNotEmpty) {
          return ref;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
