import 'package:flutter/material.dart';

class BotaoPersonalizado extends StatelessWidget {
  final String texto;
  final Color cor;
  final IconData? icone;
  final VoidCallback? onPressed;
  final bool carregando;

  const BotaoPersonalizado({
    required this.texto,
    required this.cor,
    this.icone,
    required this.onPressed,
    this.carregando = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: carregando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: cor,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: cor.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (carregando)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Text(
                  texto,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),

              if (!carregando && icone != null) ...[
                SizedBox(width: 10),
                Icon(icone, color: Colors.white),
                SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
