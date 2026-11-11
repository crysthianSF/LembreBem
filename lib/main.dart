import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/telas/tela_inicial.dart';
import 'package:lembrebem/telas/tela_redefinir_senha.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? startupError;
  try {
    await SupabaseBackend.initialize();
  } catch (e) {
    startupError = e.toString();
  }

  runApp(MyApp(startupError: startupError));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.startupError});

  final String? startupError;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = SupabaseBackend.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const TelaRedefinirSenha(
              etapaInicial: EtapaRecuperacao.novaSenha,
            ),
          ),
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'LembreBem',
      debugShowCheckedModeBanner: false,
      theme: _temaLembreBem(),
      home:
          widget.startupError == null
              ? const TelaInicial()
              : _TelaErroInicializacao(erro: widget.startupError!),
    );
  }

  ThemeData _temaLembreBem() {
    final base = ThemeData(
      colorSchemeSeed: corPrimaria,
      scaffoldBackgroundColor: corFundo,
      useMaterial3: true,
    );

    return base.copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: corPrimaria,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x3355C2C3),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: corPrimariaEscura),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x1A000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: corPrimaria, width: 2),
        ),
        labelStyle: const TextStyle(color: corPrimariaEscura),
        floatingLabelStyle: const TextStyle(color: corPrimariaEscura),
      ),
    );
  }
}

class _TelaErroInicializacao extends StatelessWidget {
  const _TelaErroInicializacao({required this.erro});

  final String erro;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuracao do Supabase pendente',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Para abrir o app no Chrome, rode com sua chave publica '
                  'sb_publishable.',
                ),
                const SizedBox(height: 12),
                const SelectableText(
                  '1) Edite lib/backend/supabase_local_config.dart '
                  'com sua chave publica\n'
                  '2) Rode: flutter run -d chrome',
                ),
                const SizedBox(height: 12),
                Text('Opcional: sobrescrever pela linha de comando'),
                const SizedBox(height: 8),
                const SelectableText(
                  'flutter run -d chrome '
                  '--dart-define=SUPABASE_URL=https://xhtuoeiirivriwhoymog.supabase.co '
                  '--dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx',
                ),
                const SizedBox(height: 16),
                Text(
                  'Detalhe tecnico: $erro',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
