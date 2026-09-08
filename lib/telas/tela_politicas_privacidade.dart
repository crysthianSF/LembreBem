import 'package:flutter/material.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';

class TelaPoliticasPrivacidade extends StatelessWidget {
  const TelaPoliticasPrivacidade({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FundoDecorado(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: LinkVoltar(onTap: () => Navigator.pop(context)),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Politicas de Privacidade',
              style: TextStyle(
                color: corPrimariaEscura,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                child: Text(
                  'Esta Politica de Privacidade foi elaborada em conformidade com a '
                  'Lei Federal n 13.709/2018 (Lei Geral de Protecao de Dados Pessoais '
                  '- LGPD).\n\n'
                  '1. Quais dados nos utilizamos\n'
                  'Ao utilizar funcionalidades do aplicativo, sera necessario realizar '
                  'um cadastro com dados pessoais como nome, endereco de e-mail, '
                  'numero de telefone, CPF e data de nascimento.\n\n'
                  '2. Por que coletamos seus dados\n'
                  'A coleta de dados pessoais ocorre para identificar o usuario, '
                  'garantir acesso seguro as funcionalidades e personalizar recursos do app.\n\n'
                  '- Facilitar o cumprimento de contratos e servicos.\n'
                  '- Melhorar a qualidade e funcionamento do aplicativo.\n'
                  '- Executar atividades relacionadas a prestacao do servico.\n'
                  '- Cumprir obrigacoes legais e regulatórias.\n\n'
                  '3. Compartilhamento e seguranca\n'
                  'Os dados nao sao vendidos. O tratamento respeita os principios de '
                  'necessidade, adequacao e transparencia.\n\n'
                  '4. Direitos do titular\n'
                  'Voce pode solicitar acesso, correcao, exclusao ou portabilidade dos '
                  'dados pessoais a qualquer momento pelos canais de contato.\n\n'
                  '5. Atualizacoes desta politica\n'
                  'Este documento pode ser atualizado periodicamente para refletir '
                  'melhorias ou mudancas legais.',
                  style: TextStyle(
                    color: Color(0xFF5C5C5C),
                    fontSize: 16,
                    height: 1.45,
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
