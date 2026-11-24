import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lembrebem/backend/alarmes_api.dart';
import 'package:lembrebem/backend/app_api.dart';
import 'package:lembrebem/backend/supabase_backend.dart';
import 'package:lembrebem/modelo_alarme.dart';
import 'package:lembrebem/telas/tela_alarme_disparado.dart';

class ServicoAlarme {
  ServicoAlarme._interno({AppApi? appApi, AlarmesApi? alarmesApi})
    : _appApi = appApi ?? AppApi(),
      _alarmesApi = alarmesApi ?? AlarmesApi();

  static final ServicoAlarme instancia = ServicoAlarme._interno();
  factory ServicoAlarme({AppApi? appApi, AlarmesApi? alarmesApi}) {
    if (appApi != null || alarmesApi != null) {
      return ServicoAlarme._interno(appApi: appApi, alarmesApi: alarmesApi);
    }
    return instancia;
  }

  final AppApi _appApi;
  final AlarmesApi _alarmesApi;

  GlobalKey<NavigatorState>? _navigatorKey;
  Timer? _timerVerificacao;
  List<Alarme> _alarmesAtivos = [];
  bool _inicializado = false;
  bool _alarmeEmExibicao = false;

  /// Armazena o número da tentativa atual de cada alarme (1 para 1ª chamada, 2 para 2ª chamada/insistência)
  final Map<String, int> _tentativasPorAlarme = {};

  /// Registra alarmes que já dispararam no dia/minuto atual para evitar múltiplos disparos no mesmo minuto
  final Set<String> _disparosRecentes = {};

  /// Armazena alarmes em modo soneca com o horário exato em que devem tocar novamente
  final Map<String, DateTime> _sonecasAtivas = {};

  /// Armazena o objeto Alarme associado a cada soneca para manter os dados na 2ª chamada
  final Map<String, Alarme> _alarmesSoneca = {};

  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;
  List<Alarme> get alarmesAtivos => List.unmodifiable(_alarmesAtivos);
  bool get inicializado => _inicializado;
  bool get alarmeEmExibicao => _alarmeEmExibicao;

  void definirNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Inicializa o serviço de verificação periódica de alarmes.
  Future<void> inicializar({GlobalKey<NavigatorState>? navKey}) async {
    if (navKey != null) {
      _navigatorKey = navKey;
    }

    if (_inicializado) {
      await recarregarAlarmes();
      return;
    }

    _inicializado = true;
    await recarregarAlarmes();

    // Executa verificação a cada 15 segundos para precisão no minuto
    _timerVerificacao?.cancel();
    _timerVerificacao = Timer.periodic(
      const Duration(seconds: 15),
      (_) => verificarAlarmes(),
    );
  }

  /// Recarrega a lista de alarmes ativos do usuário autenticado no Supabase/Cache.
  Future<void> recarregarAlarmes() async {
    try {
      final userId = SupabaseBackend.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        _alarmesAtivos = [];
        return;
      }

      final dados = await _appApi.listarAlarmesDoUsuario(usuarioId: userId);
      _alarmesAtivos =
          dados
              .map((json) => Alarme.fromJson(json))
              .where(
                (alarme) =>
                    alarme.ativado &&
                    alarme.id != null &&
                    alarme.id!.isNotEmpty,
              )
              .toList();
    } catch (_) {
      // Falha silenciosa em caso de sem rede; mantém lista em memória
    }
  }

  /// Define diretamente os alarmes ativos (útil para testes ou atualizações manuais de tela).
  void definirAlarmesAtivos(List<Alarme> alarmes) {
    _alarmesAtivos = alarmes.where((a) => a.ativado).toList();
  }

  /// Verifica se algum alarme agendado ou soneca deve ser disparado neste instante.
  Future<void> verificarAlarmes({DateTime? dataReferencia}) async {
    if (_alarmeEmExibicao) {
      return;
    }

    final agora = dataReferencia ?? DateTime.now();

    // 1. Verifica se há sonecas ativas que atingiram o horário de despertar (2ª chamada)
    final sonecasParaTocar = <String>[];
    _sonecasAtivas.forEach((alarmeId, horarioDespertar) {
      if (agora.isAfter(horarioDespertar) ||
          agora.isAtSameMomentAs(horarioDespertar)) {
        sonecasParaTocar.add(alarmeId);
      }
    });

    for (final alarmeId in sonecasParaTocar) {
      _sonecasAtivas.remove(alarmeId);
      final alarme =
          _alarmesSoneca.remove(alarmeId) ??
          _alarmesAtivos.firstWhere(
            (a) => a.id == alarmeId,
            orElse:
                () => Alarme(
                  id: alarmeId,
                  nome: 'Medicamento',
                  observacoes: '',
                  horario: TimeOfDay(hour: agora.hour, minute: agora.minute),
                  diasDeUso: '',
                  ativado: true,
                  intervalo: '',
                ),
          );

      await dispararAlarme(alarme, tentativa: 2, dataReferencia: agora);
      return; // Dispara um por vez para não sobrepor telas
    }

    // 2. Verifica se algum alarme ativo coincide com hora e minuto atuais (1ª chamada)
    for (final alarme in _alarmesAtivos) {
      final alarmeId = alarme.id;
      if (alarmeId == null || alarmeId.isEmpty) continue;

      if (alarme.horario.hour == agora.hour &&
          alarme.horario.minute == agora.minute) {
        if (!_alarmeDeveTocarHoje(alarme.diasDeUso, agora)) {
          continue;
        }

        final chaveDisparo =
            '${alarmeId}_${agora.year}_${agora.month}_${agora.day}_${agora.hour}_${agora.minute}';
        if (_disparosRecentes.contains(chaveDisparo)) {
          continue;
        }

        _disparosRecentes.add(chaveDisparo);

        // Limpa chaves antigas se o conjunto crescer muito
        if (_disparosRecentes.length > 50) {
          _disparosRecentes.clear();
          _disparosRecentes.add(chaveDisparo);
        }

        await dispararAlarme(alarme, tentativa: 1, dataReferencia: agora);
        return;
      }
    }
  }

  /// Dispara a tela visual de alarme e aguarda interação do paciente.
  Future<void> dispararAlarme(
    Alarme alarme, {
    required int tentativa,
    DateTime? dataReferencia,
  }) async {
    final alarmeId = alarme.id;
    if (alarmeId == null || alarmeId.isEmpty) return;

    final agora = dataReferencia ?? DateTime.now();

    // Verifica se a dose já foi confirmada hoje
    final jaTomou = await _alarmesApi.verificarDoseJaTomadaHoje(
      alarmeId: alarmeId,
      data: agora,
    );
    if (jaTomou) {
      _sonecasAtivas.remove(alarmeId);
      _tentativasPorAlarme.remove(alarmeId);
      return;
    }

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      return;
    }

    _alarmeEmExibicao = true;
    _tentativasPorAlarme[alarmeId] = tentativa;

    final horaFormatada =
        '${alarme.horario.hour.toString().padLeft(2, '0')}:${alarme.horario.minute.toString().padLeft(2, '0')}';

    try {
      final resultado = await navigator.push(
        MaterialPageRoute<String>(
          fullscreenDialog: true,
          builder:
              (_) => TelaAlarmeDisparado(
                alarmeId: alarmeId,
                medicamentoNome: alarme.nome,
                horarioFormatado: horaFormatada,
                observacoes: alarme.observacoes,
                tentativa: tentativa,
                horarioPrevisto: agora,
                aoTomarMedicamento: () async {
                  await _alarmesApi.registrarDoseTomada(
                    alarmeId: alarmeId,
                    medicamentoNome: alarme.nome,
                    horarioPrevisto: agora,
                  );
                },
                aoPedirSoneca: (minutos) {
                  agendarSoneca(alarmeId, alarme: alarme, minutos: minutos);
                },
                aoEscalarCuidador: () async {
                  return await _alarmesApi.registrarDosePerdidaEEscalar(
                    alarmeId: alarmeId,
                    medicamentoNome: alarme.nome,
                    horarioPrevisto: agora,
                  );
                },
              ),
        ),
      );

      if (resultado == 'tomada') {
        _sonecasAtivas.remove(alarmeId);
        _alarmesSoneca.remove(alarmeId);
        _tentativasPorAlarme.remove(alarmeId);
      } else if (resultado != null && resultado.startsWith('soneca')) {
        final partes = resultado.split('_');
        final minutos =
            partes.length > 1 ? (int.tryParse(partes[1]) ?? 10) : 10;
        agendarSoneca(alarmeId, alarme: alarme, minutos: minutos);
      } else if (resultado == 'perdida') {
        _sonecasAtivas.remove(alarmeId);
        _alarmesSoneca.remove(alarmeId);
        _tentativasPorAlarme.remove(alarmeId);
      }
    } finally {
      _alarmeEmExibicao = false;
    }
  }

  /// Agenda modo soneca para disparar novamente após `minutos`.
  void agendarSoneca(String alarmeId, {Alarme? alarme, int minutos = 10}) {
    _sonecasAtivas[alarmeId] = DateTime.now().add(Duration(minutes: minutos));
    _tentativasPorAlarme[alarmeId] = 2;
    if (alarme != null) {
      _alarmesSoneca[alarmeId] = alarme;
    }
  }

  /// Cancela qualquer soneca pendente para o alarme.
  void cancelarSoneca(String alarmeId) {
    _sonecasAtivas.remove(alarmeId);
    _alarmesSoneca.remove(alarmeId);
    _tentativasPorAlarme.remove(alarmeId);
  }

  /// Interrompe o timer e limpa o estado.
  void parar() {
    _timerVerificacao?.cancel();
    _timerVerificacao = null;
    _inicializado = false;
    _alarmeEmExibicao = false;
    _sonecasAtivas.clear();
    _alarmesSoneca.clear();
    _tentativasPorAlarme.clear();
    _disparosRecentes.clear();
  }

  /// Verifica se a regra de dias de uso do alarme é aplicável ao dia atual.
  bool _alarmeDeveTocarHoje(String diasDeUso, DateTime data) {
    final dias = diasDeUso.trim().toLowerCase();
    if (dias.isEmpty ||
        dias.contains('todo dia') ||
        dias.contains('todos os dias') ||
        dias.contains('contínuo') ||
        dias.contains('continuo')) {
      return true;
    }

    final weekday = data.weekday; // 1 = Monday ... 7 = Sunday
    if (dias.contains('seg') && weekday == DateTime.monday) return true;
    if (dias.contains('ter') && weekday == DateTime.tuesday) return true;
    if (dias.contains('qua') && weekday == DateTime.wednesday) return true;
    if (dias.contains('qui') && weekday == DateTime.thursday) return true;
    if (dias.contains('sex') && weekday == DateTime.friday) return true;
    if ((dias.contains('sab') || dias.contains('sáb')) &&
        weekday == DateTime.saturday) {
      return true;
    }
    if (dias.contains('dom') && weekday == DateTime.sunday) return true;

    return true;
  }
}
