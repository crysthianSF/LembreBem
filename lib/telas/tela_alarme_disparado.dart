import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lembrebem/backend/alarmes_api.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/utils/som_alarme.dart';
import 'package:lembrebem/widgets/componentes.dart';

class TelaAlarmeDisparado extends StatefulWidget {
  const TelaAlarmeDisparado({
    super.key,
    required this.alarmeId,
    required this.medicamentoNome,
    required this.horarioFormatado,
    this.dose,
    this.observacoes,
    this.tentativa = 1,
    this.horarioPrevisto,
    this.aoTomarMedicamento,
    this.aoPedirSoneca,
    this.aoEscalarCuidador,
  });

  final String alarmeId;
  final String medicamentoNome;
  final String horarioFormatado;
  final String? dose;
  final String? observacoes;
  final int tentativa;
  final DateTime? horarioPrevisto;
  final Future<void> Function()? aoTomarMedicamento;
  final void Function(int minutos)? aoPedirSoneca;
  final Future<void> Function()? aoEscalarCuidador;

  @override
  State<TelaAlarmeDisparado> createState() => _TelaAlarmeDisparadoState();
}

class _TelaAlarmeDisparadoState extends State<TelaAlarmeDisparado>
    with SingleTickerProviderStateMixin {
  final AlarmesApi _alarmesApi = AlarmesApi();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _countdownTimer;
  Timer? _efeitoSonoroTimer;
  int _segundosRestantes = 60;
  bool _processando = false;
  bool _permitirFechar = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _iniciarEfeitosSonorosEVibracao();
    _iniciarContagemRegressiva();
  }

  void _iniciarEfeitosSonorosEVibracao() {
    // Toca imediatamente ao abrir a tela
    GerenciadorSomAlarme.tocarBeepAlarme();
    HapticFeedback.heavyImpact();

    // Repete o bipe sonoro e vibração a cada 1.5s enquanto o alarme estiver tocando
    _efeitoSonoroTimer?.cancel();
    _efeitoSonoroTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted) return;
      GerenciadorSomAlarme.tocarBeepAlarme();
      HapticFeedback.heavyImpact();
    });
  }

  void _iniciarContagemRegressiva() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_segundosRestantes > 1) {
          _segundosRestantes--;
        } else {
          _segundosRestantes = 0;
          timer.cancel();
          _tratarTimeout();
        }
      });
    });
  }

  void _pararEfeitos() {
    _efeitoSonoroTimer?.cancel();
    _efeitoSonoroTimer = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _pulseController.stop();
  }

  void _fecharComResultado(String resultado) {
    _permitirFechar = true;
    _pararEfeitos();
    if (mounted) {
      Navigator.of(context).pop(resultado);
    }
  }

  Future<void> _tratarTimeout() async {
    _pararEfeitos();
    if (widget.tentativa == 1) {
      // 1ª chamada sem resposta -> ativa soneca automática de 10 min
      if (widget.aoPedirSoneca != null) {
        widget.aoPedirSoneca!(10);
      }
      _fecharComResultado('soneca_10');
    } else {
      // 2ª chamada sem resposta -> dose perdida e aciona cuidador
      await _escalarDosePerdida();
    }
  }

  Future<void> _confirmarDoseTomada() async {
    if (_processando) return;
    setState(() => _processando = true);
    _pararEfeitos();

    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      if (widget.aoTomarMedicamento != null) {
        await widget.aoTomarMedicamento!();
      } else {
        final horario = widget.horarioPrevisto ?? DateTime.now();
        await _alarmesApi.registrarDoseTomada(
          alarmeId: widget.alarmeId,
          medicamentoNome: widget.medicamentoNome,
          horarioPrevisto: horario,
          dose: widget.dose,
        );
      }

      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Medicamento registrado como tomado com sucesso!'),
          backgroundColor: Color(0xFF1B8F45),
        ),
      );
      _fecharComResultado('tomada');
    } catch (_) {
      if (mounted) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Erro ao registrar dose. Verifique sua conexao.'),
            backgroundColor: Color(0xFFC0392B),
          ),
        );
        setState(() => _processando = false);
      }
    }
  }

  void _ativarSoneca({int minutos = 10}) {
    if (_processando) return;
    _pararEfeitos();

    final messenger = ScaffoldMessenger.maybeOf(context);

    if (widget.aoPedirSoneca != null) {
      widget.aoPedirSoneca!(minutos);
    }

    messenger?.showSnackBar(
      SnackBar(
        content: Text('Soneca ativada. O alarme tocará novamente em $minutos minuto${minutos > 1 ? 's' : ''}.'),
        backgroundColor: const Color(0xFF0284C7),
      ),
    );

    _fecharComResultado('soneca_$minutos');
  }

  Future<void> _escalarDosePerdida() async {
    if (_processando) return;
    setState(() => _processando = true);
    _pararEfeitos();

    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      if (widget.aoEscalarCuidador != null) {
        await widget.aoEscalarCuidador!();
      } else {
        final horario = widget.horarioPrevisto ?? DateTime.now();
        await _alarmesApi.registrarDosePerdidaEEscalar(
          alarmeId: widget.alarmeId,
          medicamentoNome: widget.medicamentoNome,
          horarioPrevisto: horario,
          dose: widget.dose,
        );
      }

      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Dose registrada como perdida. Notificação enviada ao cuidador.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      _fecharComResultado('perdida');
    } catch (_) {
      _fecharComResultado('perdida');
    }
  }

  @override
  void dispose() {
    _pararEfeitos();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool eSegundaTentativa = widget.tentativa >= 2;

    return PopScope(
      canPop: _permitirFechar,
      child: Scaffold(
        backgroundColor: corFundo,
        body: FundoDecorado(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Badge indicando chamada
                  _badgeTentativa(eSegundaTentativa),

                  const Spacer(),

                  // Ícone animado
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: eSegundaTentativa
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFE0F2FE),
                        boxShadow: [
                          BoxShadow(
                            color: (eSegundaTentativa
                                    ? const Color(0xFFF59E0B)
                                    : corPrimaria)
                                .withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        eSegundaTentativa
                            ? Icons.warning_amber_rounded
                            : Icons.alarm,
                        size: 58,
                        color: eSegundaTentativa
                            ? const Color(0xFFD97706)
                            : corPrimariaEscura,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Título principal
                  Text(
                    eSegundaTentativa
                        ? 'Atenção: 2ª Chamada!'
                        : 'Hora do Medicamento!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: eSegundaTentativa
                          ? const Color(0xFFB45309)
                          : corPrimariaEscura,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Horário: ${widget.horarioFormatado}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: corTextoCinza,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Cartão com detalhes do medicamento
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: cardDecoracao(
                      borda: eSegundaTentativa
                          ? const Color(0xFFF59E0B)
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.medicamentoNome,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: corTextoEscuro,
                          ),
                        ),
                        if (widget.dose != null && widget.dose!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Dose: ${widget.dose}',
                            style: const TextStyle(
                              fontSize: 15,
                              color: corTextoCinza,
                            ),
                          ),
                        ],
                        if (widget.observacoes != null &&
                            widget.observacoes!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: corTextoCinza,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.observacoes!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: corTextoEscuro,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Alerta para 2ª chamada sobre notificação via WhatsApp ao cuidador
                  if (eSegundaTentativa) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.contact_phone_outlined,
                            color: Color(0xFFDC2626),
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Se não confirmar agora, seu cuidador vinculado receberá um aviso via WhatsApp!',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Contador regressivo
                  Text(
                    'Silenciando automaticamente em ${_segundosRestantes}s',
                    style: const TextStyle(
                      fontSize: 12,
                      color: corTextoCinzaClaro,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botão principal: Tomei o medicamento
                  BotaoPrimario(
                    texto: 'Tomei o medicamento',
                    cor: const Color(0xFF16A34A),
                    carregando: _processando,
                    onPressed: _confirmarDoseTomada,
                  ),

                  const SizedBox(height: 12),

                  // Botão secundário: Soneca na 1ª tentativa ou Desligar na 2ª tentativa
                  if (!eSegundaTentativa) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.snooze, size: 20),
                        label: const Text(
                          'Lembrar em 10 minutos',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: corPrimariaEscura,
                          side: const BorderSide(color: corPrimaria, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _processando ? null : () => _ativarSoneca(minutos: 10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Atalho para teste rápido de 1 minuto (facilita muito testar a 2ª chamada sem esperar 10 min)
                    TextButton.icon(
                      icon: const Icon(Icons.flash_on, size: 16, color: Color(0xFF0284C7)),
                      label: const Text(
                        'Testar 2ª chamada em 1 minuto',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      onPressed: _processando ? null : () => _ativarSoneca(minutos: 1),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.close,
                          size: 20,
                          color: Color(0xFFDC2626),
                        ),
                        label: const Text(
                          'Desligar alarme',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(
                            color: Color(0xFFEF4444),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _processando ? null : _escalarDosePerdida,
                      ),
                    ),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badgeTentativa(bool eSegundaTentativa) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: eSegundaTentativa
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: eSegundaTentativa
              ? const Color(0xFFF59E0B)
              : const Color(0xFF38BDF8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            eSegundaTentativa ? Icons.priority_high : Icons.notifications_active,
            size: 16,
            color: eSegundaTentativa
                ? const Color(0xFFB45309)
                : const Color(0xFF0369A1),
          ),
          const SizedBox(width: 6),
          Text(
            eSegundaTentativa ? '2ª Chamada' : '1ª Chamada',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: eSegundaTentativa
                  ? const Color(0xFFB45309)
                  : const Color(0xFF0369A1),
            ),
          ),
        ],
      ),
    );
  }
}
