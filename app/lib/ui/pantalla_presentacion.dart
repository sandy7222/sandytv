import 'package:flutter/material.dart';

import '../servicios/estado_app.dart';
import 'pantalla_canal.dart';
import 'pantalla_inicio.dart';
import 'tema.dart';

/// Primera pantalla: logo de SandyTV mientras se carga la cartelera guardada. Sin video.
class PantallaPresentacion extends StatefulWidget {
  const PantallaPresentacion({super.key, required this.estado});
  final EstadoApp estado;
  @override
  State<PantallaPresentacion> createState() => _PantallaPresentacionState();
}

class _PantallaPresentacionState extends State<PantallaPresentacion> {
  bool _sinCartelera = false;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  Future<void> _arrancar() async {
    setState(() => _sinCartelera = false);
    await Future.wait([widget.estado.iniciar(), Future<void>.delayed(const Duration(milliseconds: 1800))]);
    if (!mounted) return;
    if (widget.estado.cartelera == null) {
      setState(() => _sinCartelera = true);
      return;
    }
    final nav = Navigator.of(context);
    nav.pushReplacement(MaterialPageRoute(builder: (_) => PantallaInicio(estado: widget.estado)));
    final ultimo = widget.estado.ultimoCanal;
    if (widget.estado.retomarAlAbrir && ultimo != null) {
      nav.push(MaterialPageRoute(builder: (_) => PantallaCanal(estado: widget.estado, canalInicial: ultimo)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0A0E1A), Color(0xFF12304A)])),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const LogoSandyTv(tam: 72),
            const SizedBox(height: 28),
            if (!_sinCartelera)
              const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: Colores.acento))
            else ...[
              const Text('No pude cargar la cartelera. Revisá la conexión a internet.', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 16),
              FilledButton(autofocus: true, onPressed: _arrancar, child: const Text('Reintentar')),
            ],
          ]),
        ),
      ),
    );
  }
}
