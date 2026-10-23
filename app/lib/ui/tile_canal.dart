import 'package:flutter/material.dart';

import '../modelos/cartelera.dart';
import 'tema.dart';

/// Tarjeta de un canal en las filas del inicio. Se maneja con las flechas y OK.
class TileCanal extends StatefulWidget {
  const TileCanal({super.key, required this.canal, required this.alElegir, this.autofocus = false, this.atenuado = false, this.numero});
  final Canal canal;

  /// Número a mostrar; si es null, el de la cartelera.
  final int? numero;
  final VoidCallback alElegir;
  final bool autofocus;
  final bool atenuado;

  @override
  State<TileCanal> createState() => _TileCanalState();
}

class _TileCanalState extends State<TileCanal> {
  bool _enfocado = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.canal;
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (v) => setState(() => _enfocado = v),
      onFocusChange: (v) {
        if (v) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 150));
      },
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) { widget.alElegir(); return null; })},
      child: GestureDetector(
        onTap: widget.alElegir,
        child: AnimatedScale(
          scale: _enfocado ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Opacity(
            opacity: widget.atenuado ? 0.45 : 1,
            child: Container(
              width: 190,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colores.superficie,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _enfocado ? Colores.acento : Colors.transparent, width: 3),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(height: 70, child: LogoCanal(url: c.logo, nombre: c.nombre, alto: 64)),
                const SizedBox(height: 8),
                Text(c.nombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colores.texto)),
                Text('Canal ${widget.numero ?? c.numero}', style: const TextStyle(fontSize: 12, color: Colores.textoSuave)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
