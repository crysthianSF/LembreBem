import 'package:flutter/material.dart';

const Color corPrimaria = Color(0xFF55C2C3);
const Color corPrimariaEscura = Color(0xFF2D8687);
const Color corFundo = Color(0xFFEAF5F8);
const Color corTextoEscuro = Color(0xFF4A4A4A);
const Color corCard = Colors.white;
const Color corEmergencia = Color(0xFFEF4444);
const Color corEmergenciaForte = Color(0xFFDC2626);
const Color corSucesso = Color(0xFF22C55E);
const Color corAviso = Color(0xFFF59E0B);
const Color corTextoCinza = Color(0xFF6B7280);
const Color corTextoCinzaClaro = Color(0xFF9CA3AF);
const LinearGradient gradientePrimario = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [corPrimariaEscura, corPrimaria],
);
const List<BoxShadow> sombraCard = [
  BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 5)),
];
BoxDecoration cardDecoracao({Color? borda, double radius = 16}) {
  return BoxDecoration(
    color: corCard,
    borderRadius: BorderRadius.circular(radius),
    border: borda != null ? Border.all(color: borda) : null,
    boxShadow: sombraCard,
  );
}

class FundoDecorado extends StatelessWidget {
  const FundoDecorado({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: corFundo,
      child: Stack(
        children: [
          Positioned(
            top: -60,
            left: -70,
            child: _circulo(220, const Color(0xFF9FDEDF)),
          ),
          Positioned(
            top: 90,
            right: -50,
            child: _circulo(200, const Color(0xFFBDEAEB)),
          ),
          Positioned(
            top: 30,
            right: 30,
            child: _circulo(90, const Color(0xFF9FDEDF)),
          ),
          Positioned(
            bottom: -52,
            left: -45,
            child: _circulo(160, const Color(0xFFBDEAEB)),
          ),
          Positioned(
            bottom: 70,
            left: 24,
            child: _circulo(120, const Color(0xFFCBEFF0)),
          ),
          Positioned.fill(child: SafeArea(child: child)),
        ],
      ),
    );
  }

  Widget _circulo(double size, Color color) {
    return Opacity(
      opacity: 0.35,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class LinkVoltar extends StatelessWidget {
  const LinkVoltar({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_ios_new, size: 18, color: corPrimariaEscura),
            SizedBox(width: 3),
            Text(
              'Voltar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: corPrimariaEscura,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
