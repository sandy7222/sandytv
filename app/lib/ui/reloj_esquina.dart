import 'dart:async';

import 'package:flutter/material.dart';

import '../servicios/estado_app.dart';
import 'tema.dart';

/// Reloj con la hora de Argentina, abajo a la izquierda. Se muestra u oculta desde Ajustes.
class RelojEsquina extends StatefulWidget {
  const RelojEsquina({super.key, required this.estado});
  final EstadoApp estado;

  /// Ancho que ocupa, para que otras barras de abajo no lo pisen.
  static const ancho = 130.0;

  @override
  State<RelojEsquina> createState() => _RelojEsquinaState();
}

class _RelojEsquinaState extends State<RelojEsquina> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Cada segundo se mira la hora; solo se redibuja cuando cambia el minuto.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.estado,
      builder: (context, _) {
        if (!widget.estado.mostrarReloj) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            key: const Key('reloj'),
            margin: const EdgeInsets.only(left: 28, bottom: 24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(12)),
            child: Text(widget.estado.reloj.hora(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colores.texto)),
          ),
        );
      },
    );
  }
}
