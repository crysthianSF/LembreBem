import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef InvocarFuncaoWhatsApp =
    Future<FunctionResponse> Function(String nome, Map<String, dynamic> corpo);

class ResultadoEnvioWhatsApp {
  const ResultadoEnvioWhatsApp({
    required this.status,
    this.messageId,
    this.aceitos = 0,
    this.falhas = 0,
    this.ignorados = 0,
  });

  factory ResultadoEnvioWhatsApp.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString();
    if (!const {
      'accepted',
      'processing',
      'sent',
      'delivered',
      'read',
      'unknown',
      'failed',
      'partial',
      'skipped',
    }.contains(status)) {
      throw const WhatsAppException('INVALID_RESPONSE');
    }
    int quantidade(String chave) =>
        json[chave] is num ? (json[chave] as num).toInt() : 0;
    return ResultadoEnvioWhatsApp(
      status: status!,
      messageId: json['message_id']?.toString(),
      aceitos: quantidade('accepted'),
      falhas: quantidade('failed'),
      ignorados: quantidade('skipped'),
    );
  }

  final String status;
  final String? messageId;
  final int aceitos;
  final int falhas;
  final int ignorados;

  bool get encaminhado =>
      const {'accepted', 'sent', 'delivered', 'read'}.contains(status);

  String get mensagemRelatorio {
    if (encaminhado) {
      return 'Relatório encaminhado para envio pelo WhatsApp.';
    }
    return switch (status) {
      'processing' => 'O envio do relatório ainda está em processamento.',
      'failed' => 'Não foi possível enviar o relatório pelo WhatsApp.',
      _ =>
        'Ainda não foi possível confirmar o envio do relatório. '
            'Tente consultar novamente em instantes.',
    };
  }

  String get mensagemAlerta {
    if (encaminhado) {
      return 'Aviso encaminhado para envio aos contatos de confiança.';
    }
    return switch (status) {
      'partial' =>
        'Aviso encaminhado a alguns contatos. '
            'Outros não puderam receber.',
      'processing' => 'O aviso aos contatos ainda está em processamento.',
      'skipped' => 'Nenhum contato com WhatsApp autorizado está disponível.',
      'failed' => 'Não foi possível enviar o aviso pelo WhatsApp.',
      _ => 'Ainda não foi possível confirmar o envio do aviso pelo WhatsApp.',
    };
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    if (messageId != null) 'message_id': messageId,
    'accepted': aceitos,
    'failed': falhas,
    'skipped': ignorados,
  };
}

class WhatsAppException implements Exception {
  const WhatsAppException(this.codigo);

  final String codigo;

  String get mensagem => switch (codigo) {
    'UNAUTHORIZED' => 'Entre novamente na sua conta para enviar pelo WhatsApp.',
    'FORBIDDEN' => 'Você não tem acesso ao relatório deste paciente.',
    'OPT_IN_REQUIRED' =>
      'O paciente precisa enviar ACEITO para o WhatsApp '
          'do LembreBem antes de receber relatórios.',
    'INVALID_PHONE' => 'Confira o telefone com DDD no cadastro do paciente.',
    'RATE_LIMITED' => 'Aguarde alguns minutos antes de solicitar outro envio.',
    'NOT_CONFIGURED' || 'TEMPLATE_ERROR' || 'FUNCTION_NOT_FOUND' =>
      'O envio pelo WhatsApp ainda não está disponível. '
          'Entre em contato com a equipe do LembreBem.',
    'INVALID_REQUEST' =>
      'Não foi possível solicitar este relatório. '
          'Confira o paciente e o período.',
    'IDEMPOTENCY_CONFLICT' =>
      'Já existe uma solicitação para este relatório. '
          'Aguarde a confirmação do envio.',
    'TIMEOUT' || 'NETWORK_ERROR' || 'INVALID_RESPONSE' =>
      'Não foi possível confirmar o envio. Confira sua conexão e tente '
          'novamente para consultar a mesma solicitação.',
    _ =>
      'Não foi possível enviar pelo WhatsApp agora. Tente novamente mais tarde.',
  };

  @override
  String toString() => mensagem;
}

class WhatsAppApi {
  WhatsAppApi({
    InvocarFuncaoWhatsApp? invocar,
    String? Function()? usuarioAtual,
    DateTime Function()? agora,
    Duration timeout = const Duration(seconds: 45),
  }) : _invocar = invocar ?? _invocarSupabase,
       _usuarioAtual = usuarioAtual ?? _usuarioSupabase,
       _agora = agora ?? DateTime.now,
       _timeout = timeout;

  final InvocarFuncaoWhatsApp _invocar;
  final String? Function() _usuarioAtual;
  final DateTime Function() _agora;
  final Duration _timeout;
  final Map<String, Future<ResultadoEnvioWhatsApp>> _emAndamento = {};

  static String? _usuarioSupabase() =>
      SupabaseBackend.client.auth.currentUser?.id;

  static Future<FunctionResponse> _invocarSupabase(
    String nome,
    Map<String, dynamic> corpo,
  ) => SupabaseBackend.client.functions.invoke(nome, body: corpo);

  Future<ResultadoEnvioWhatsApp> enviarRelatorio({
    required String pacienteId,
    required int dias,
  }) {
    if (pacienteId.trim().isEmpty || !const {1, 7, 30}.contains(dias)) {
      return Future.error(const WhatsAppException('INVALID_REQUEST'));
    }
    final usuario = _usuarioAtual();
    if (usuario == null || usuario.isEmpty) {
      return Future.error(const WhatsAppException('UNAUTHORIZED'));
    }
    final hoje = _agora().toLocal();
    final data =
        '${hoje.year}-${hoje.month.toString().padLeft(2, '0')}-'
        '${hoje.day.toString().padLeft(2, '0')}';
    final chave = 'whatsapp.relatorio.$usuario.$pacienteId.$dias.$data';
    // Cliques concorrentes compartilham o pedido, inclusive antes de carregar
    // o armazenamento local. A chave durável também cobre reinício do app.
    // No mesmo dia, um resultado incerto é consultado com o mesmo ID. Em outro
    // dia, o toque representa um novo relatório, sem bloquear envios futuros.
    return _emAndamento.putIfAbsent(
      chave,
      () => _enviarRelatorio(chave, pacienteId, dias).whenComplete(() {
        _emAndamento.remove(chave);
      }),
    );
  }

  Future<ResultadoEnvioWhatsApp> _enviarRelatorio(
    String chave,
    String pacienteId,
    int dias,
  ) async {
    final preferencias = await SharedPreferences.getInstance();
    final requestId = preferencias.getString(chave) ?? _novoUuid();
    if (!await preferencias.setString(chave, requestId)) {
      throw const WhatsAppException('LOCAL_STORAGE_ERROR');
    }
    final resultado = await _chamar('enviar-relatorio-whatsapp', {
      'paciente_id': pacienteId,
      'dias': dias,
      'request_id': requestId,
    });
    if (resultado.encaminhado || resultado.status == 'failed') {
      // Só uma resposta definitiva encerra esta intenção. Em timeout, erro de
      // rede, processing ou unknown, reutilizamos o ID sem reenviar às cegas.
      await preferencias.remove(chave);
    }
    return resultado;
  }

  Future<ResultadoEnvioWhatsApp> enviarAlertaDosePerdida({
    required String doseId,
  }) {
    if (doseId.trim().isEmpty) {
      return Future.error(const WhatsAppException('INVALID_REQUEST'));
    }
    return _chamar('enviar-alerta-whatsapp', {'dose_id': doseId});
  }

  Future<ResultadoEnvioWhatsApp> _chamar(
    String nome,
    Map<String, dynamic> corpo,
  ) async {
    try {
      final resposta = await _invocar(nome, corpo).timeout(_timeout);
      if (resposta.status < 200 || resposta.status >= 300) {
        throw FunctionException(
          status: resposta.status,
          details: resposta.data,
        );
      }
      if (resposta.data is! Map) {
        throw const WhatsAppException('INVALID_RESPONSE');
      }
      return ResultadoEnvioWhatsApp.fromJson(
        Map<String, dynamic>.from(resposta.data as Map),
      );
    } on WhatsAppException {
      rethrow;
    } on FunctionException catch (erro) {
      dynamic detalhes = erro.details;
      if (detalhes is String) {
        try {
          detalhes = jsonDecode(detalhes);
        } on FormatException {
          detalhes = null;
        }
      }
      final codigo = detalhes is Map ? detalhes['error']?.toString() : null;
      throw WhatsAppException(
        codigo ??
            switch (erro.status) {
              401 => 'UNAUTHORIZED',
              403 => 'FORBIDDEN',
              404 => 'FUNCTION_NOT_FOUND',
              429 => 'RATE_LIMITED',
              503 => 'NOT_CONFIGURED',
              _ => 'META_ERROR',
            },
      );
    } on TimeoutException {
      throw const WhatsAppException('TIMEOUT');
    } catch (_) {
      throw const WhatsAppException('NETWORK_ERROR');
    }
  }

  static String _novoUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
