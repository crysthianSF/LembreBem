import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lembrebem/telas/fundo_decorado.dart';

const double larguraMaximaConteudo = 480;

class ConteudoCentralizado extends StatelessWidget {
  const ConteudoCentralizado({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: larguraMaximaConteudo),
        child: child,
      ),
    );
  }
}

class CampoComIcone extends StatefulWidget {
  const CampoComIcone({
    super.key,
    required this.controller,
    this.rotulo,
    this.dica,
    this.icone,
    this.senha = false,
    this.teclado,
    this.formatadores,
    this.validador,
    this.aoMudar,
    this.habilitado = true,
    this.maxLinhas = 1,
  });

  final TextEditingController controller;
  final String? rotulo;
  final String? dica;
  final IconData? icone;
  final bool senha;
  final TextInputType? teclado;
  final List<TextInputFormatter>? formatadores;
  final String? Function(String?)? validador;
  final ValueChanged<String>? aoMudar;
  final bool habilitado;
  final int maxLinhas;

  @override
  State<CampoComIcone> createState() => _CampoComIconeState();
}

class _CampoComIconeState extends State<CampoComIcone> {
  bool _ocultar = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.rotulo != null) ...[
          Text(
            widget.rotulo!,
            style: const TextStyle(
              color: corPrimariaEscura,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: widget.controller,
          obscureText: widget.senha && _ocultar,
          keyboardType: widget.teclado,
          inputFormatters: widget.formatadores,
          validator: widget.validador,
          onChanged: widget.aoMudar,
          enabled: widget.habilitado,
          maxLines: widget.senha ? 1 : widget.maxLinhas,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            hintText: widget.dica,
            hintStyle: const TextStyle(color: corTextoCinzaClaro),
            filled: true,
            fillColor: Colors.white,
            prefixIcon:
                widget.icone != null
                    ? Icon(widget.icone, size: 20, color: corPrimariaEscura)
                    : null,
            suffixIcon:
                widget.senha
                    ? IconButton(
                      icon: Icon(
                        _ocultar
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: corTextoCinzaClaro,
                      ),
                      onPressed: () => setState(() => _ocultar = !_ocultar),
                    )
                    : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.transparent, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: corPrimaria, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: corEmergencia, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: corEmergencia, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.transparent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class BotaoPrimario extends StatelessWidget {
  const BotaoPrimario({
    super.key,
    required this.texto,
    this.onPressed,
    this.cor = corPrimaria,
    this.icone,
    this.carregando = false,
    this.contorno = false,
  });

  final String texto;
  final VoidCallback? onPressed;
  final Color cor;
  final IconData? icone;
  final bool carregando;
  final bool contorno;

  @override
  Widget build(BuildContext context) {
    final conteudo =
        carregando
            ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
            : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    texto,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: contorno ? cor : Colors.white,
                    ),
                  ),
                ),
                if (icone != null) ...[
                  const SizedBox(width: 8),
                  Icon(icone, size: 20, color: contorno ? cor : Colors.white),
                ],
              ],
            );

    return SizedBox(
      width: double.infinity,
      child:
          contorno
              ? OutlinedButton(
                onPressed: carregando ? null : onPressed,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cor, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: conteudo,
              )
              : ElevatedButton(
                onPressed: carregando ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cor,
                  disabledBackgroundColor: cor.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 4,
                  shadowColor: cor.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: conteudo,
              ),
    );
  }
}

class CabecalhoGradiente extends StatelessWidget {
  const CabecalhoGradiente({
    super.key,
    required this.child,
    this.curvo = false,
  });

  final Widget child;
  final bool curvo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradientePrimario,
        borderRadius:
            curvo
                ? const BorderRadius.vertical(
                  bottom: Radius.elliptical(220, 40),
                )
                : null,
      ),
      child: SafeArea(bottom: false, child: child),
    );
  }
}

class CartaoBranco extends StatelessWidget {
  const CartaoBranco({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.corBorda,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? corBorda;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border:
            corBorda != null ? Border.all(color: corBorda!, width: 2) : null,
        boxShadow: sombraCard,
      ),
      child: child,
    );

    if (onTap == null) {
      return card;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: card,
    );
  }
}

class AlternadorSwitch extends StatelessWidget {
  const AlternadorSwitch({
    super.key,
    required this.valor,
    required this.aoMudar,
  });

  final bool valor;
  final ValueChanged<bool> aoMudar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => aoMudar(!valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: valor ? corPrimaria : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: valor ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }
}

class RotuloSecao extends StatelessWidget {
  const RotuloSecao(this.texto, {super.key, this.cor = corTextoCinzaClaro});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: TextStyle(
        color: cor,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class BadgeStatus extends StatelessWidget {
  const BadgeStatus({super.key, required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(color: cor, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
