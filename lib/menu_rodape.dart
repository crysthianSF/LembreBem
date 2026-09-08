import 'package:flutter/material.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/telas/tela_alarme.dart';
import 'package:lembrebem/telas/tela_emergencia.dart';
import 'package:lembrebem/telas/tela_medicamentos.dart';
import 'package:lembrebem/telas/tela_perfil.dart';
import 'package:lembrebem/telas/tela_pesquisar.dart';

class MenuRodape extends StatelessWidget {
  final IconData icon;
  final String opcao;
  final bool selecionado;
  final VoidCallback onTap;

  const MenuRodape({
    super.key,
    required this.icon,
    required this.opcao,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cor = selecionado ? corPrimaria : corPrimariaEscura;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: cor, size: 26),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                opcao,
                style: TextStyle(
                  color: cor,
                  fontWeight: selecionado ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum AbaApp { pesquisar, medicamentos, emergencia, alarme, perfil }

class BarraNavegacaoApp extends StatelessWidget {
  final AbaApp? ativa;

  const BarraNavegacaoApp({super.key, this.ativa});

  void _navegar(BuildContext context, AbaApp destino, Widget tela) {
    if (destino == ativa) {
      return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => tela));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: corFundo,
        border: Border(top: BorderSide(color: Color(0x14000000))),
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: MenuRodape(
                  icon: Icons.search,
                  opcao: 'Pesquisar',
                  selecionado: ativa == AbaApp.pesquisar,
                  onTap:
                      () => _navegar(
                        context,
                        AbaApp.pesquisar,
                        const TelaPesquisar(),
                      ),
                ),
              ),
              Expanded(
                child: MenuRodape(
                  icon: Icons.medication_outlined,
                  opcao: 'Favoritos',
                  selecionado: ativa == AbaApp.medicamentos,
                  onTap:
                      () => _navegar(
                        context,
                        AbaApp.medicamentos,
                        const TelaMedicamentos(),
                      ),
                ),
              ),
              Expanded(
                child: _BotaoEmergencia(
                  ativo: ativa == AbaApp.emergencia,
                  onTap:
                      () => _navegar(
                        context,
                        AbaApp.emergencia,
                        const TelaEmergencia(),
                      ),
                ),
              ),
              Expanded(
                child: MenuRodape(
                  icon: Icons.notifications_none,
                  opcao: 'Alarmes',
                  selecionado: ativa == AbaApp.alarme,
                  onTap:
                      () =>
                          _navegar(context, AbaApp.alarme, const TelaAlarme()),
                ),
              ),
              Expanded(
                child: MenuRodape(
                  icon: Icons.person_outline,
                  opcao: 'Perfil',
                  selecionado: ativa == AbaApp.perfil,
                  onTap:
                      () =>
                          _navegar(context, AbaApp.perfil, const TelaPerfil()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotaoEmergencia extends StatelessWidget {
  final bool ativo;
  final VoidCallback onTap;

  const _BotaoEmergencia({required this.ativo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cor = ativo ? corEmergenciaForte : corEmergencia;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: const Offset(0, -14),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: cor,
                shape: BoxShape.circle,
                border: Border.all(color: corFundo, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: cor.withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'EMERGENCIA',
                style: TextStyle(
                  color: cor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
