import 'package:flutter/material.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';
import 'package:lembrebem/telas/tela_cadastro1.dart';
import 'package:lembrebem/telas/tela_cadastro_cuidador.dart';
import 'package:lembrebem/widgets/componentes.dart';

class TelaSelecaoPerfil extends StatelessWidget {
  const TelaSelecaoPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FundoDecorado(
        child: ConteudoCentralizado(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                LinkVoltar(onTap: () => Navigator.pop(context)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        const Text(
                          'Seja bem-vindo ao LEMBREBEM!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: corPrimariaEscura,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Para começarmos, selecione qual tipo de perfil '
                          'melhor descreve a sua necessidade hoje.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: corTextoCinza,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _CartaoPerfil(
                          icone: Icons.person_outline,
                          titulo: 'Sou Paciente',
                          descricao:
                              'Quero gerenciar meus medicamentos, configurar '
                              'alarmes diários e cuidar da minha saúde.',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TelaCadastro1(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _CartaoPerfil(
                          icone: Icons.group_outlined,
                          titulo: 'Sou Cuidador',
                          descricao:
                              'Acompanhamento profissional. Monitoramento '
                              'remoto de múltiplos pacientes, alarmes e '
                              'evolução clínica.',
                          premium: true,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TelaCadastroCuidador(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'LEMBREBEM Technology • Suporte à Saúde e '
                          'Aderência Medicamentosa',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: corTextoCinzaClaro,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartaoPerfil extends StatelessWidget {
  const _CartaoPerfil({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.onTap,
    this.premium = false,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: sombraCard,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: corFundo,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icone, color: corPrimaria, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: corPrimariaEscura,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          descricao,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: corTextoCinza,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (premium)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: const BoxDecoration(
                    color: corPrimaria,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'PREMIUM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
