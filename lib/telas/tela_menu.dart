import 'package:flutter/material.dart';
import 'package:lembrebem/botoes.dart';
import 'package:lembrebem/menu_rodape.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/telas/tela_emergencia.dart';
import 'package:lembrebem/telas/tela_medicamentos.dart';

class TelaMenu extends StatelessWidget {
  const TelaMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FundoDecorado(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    Image.asset(
                      'assets/images/menu_lembrebem.png',
                      height: 150,
                    ),
                    const Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 30,
                        color: corPrimariaEscura,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 42),
                    const Text(
                      'O que gostaria de fazer hoje?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: corTextoEscuro,
                      ),
                    ),
                    const SizedBox(height: 34),
                    BotaoPersonalizado(
                      texto: 'Emergencia',
                      cor: const Color(0xFFE42B2B),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TelaEmergencia(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    BotaoPersonalizado(
                      texto: 'Meus Medicamentos',
                      cor: corPrimaria,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TelaMedicamentos(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            const BarraNavegacaoApp(),
          ],
        ),
      ),
    );
  }
}
