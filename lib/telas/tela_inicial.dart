import 'package:flutter/material.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/telas/tela_login.dart';
import 'package:lembrebem/telas/tela_selecao_perfil.dart';
import 'package:lembrebem/widgets/componentes.dart';

class TelaInicial extends StatelessWidget {
  const TelaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FundoDecorado(
        child: ConteudoCentralizado(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Image.asset('assets/images/logo_lembrebem.png', height: 230),
                const SizedBox(height: 28),
                const Text(
                  'Gerencie os seus medicamentos',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: corPrimariaEscura,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tenha seus remédios no seu celular, nunca mais se '
                  'esqueça de tomá-los e gerencie seu estoque.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: corTextoCinza,
                  ),
                ),
                const SizedBox(height: 36),
                BotaoPrimario(
                  texto: 'Fazer cadastro',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TelaSelecaoPerfil(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                BotaoPrimario(
                  texto: 'Fazer login',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TelaLogin()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
