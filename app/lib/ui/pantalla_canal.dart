import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../logica/apertura.dart';
import '../logica/marcado_numerico.dart';
import '../logica/navegacion.dart';
import '../logica/teclas.dart';
import '../modelos/cartelera.dart';
import '../servicios/estado_app.dart';
import '../servicios/motor_video.dart';
import 'pantalla_ajustes.dart';
import 'tema.dart';

enum _Estado { conectando, reproduciendo, sinSenal }

/// Canal a pantalla completa. Todo lo que se ve (barra, errores, "conectando") es diseño de SandyTV.
class PantallaCanal extends StatefulWidget {
  const PantallaCanal({super.key, required this.estado, required this.canalInicial, this.timeoutApertura = const Duration(seconds: 10)});
  final EstadoApp estado;
  final Canal canalInicial;

  /// Cuánto se espera a que un enlace arranque antes de probar el de reserva.
  final Duration timeoutApertura;

  @override
  State<PantallaCanal> createState() => _PantallaCanalState();
}

class _PantallaCanalState extends State<PantallaCanal> {
  final _motor = MotorVideoReal();
  late Canal _canal;
  _Estado _estadoCanal = _Estado.conectando;
  Enlace? _enlace;
  bool _barra = false;
  String _marcando = '';
  String? _aviso;
  Timer? _timerBarra;
  Timer? _timerAviso;
  late final MarcadoNumerico _marcado;
  int _intento = 0;

  List<Canal> get _canales => widget.estado.cartelera?.canales ?? const [];

  @override
  void initState() {
    super.initState();
    _canal = widget.canalInicial;
    _marcado = MarcadoNumerico(
      alCambiar: (t) => setState(() => _marcando = t),
      alTerminar: _irAlNumero,
    );
    _motor.alError = _reintentarActual;
    _pantallaEncendida(true);
    _abrir(_canal);
  }

  /// Mantiene la pantalla encendida mientras se mira un canal. Si el aparato no lo permite, no pasa nada.
  Future<void> _pantallaEncendida(bool encendida) async {
    try {
      await (encendida ? WakelockPlus.enable() : WakelockPlus.disable());
    } catch (_) {}
  }

  @override
  void dispose() {
    _pantallaEncendida(false);
    _timerBarra?.cancel();
    _timerAviso?.cancel();
    _marcado.dispose();
    _motor.dispose();
    super.dispose();
  }

  Future<void> _abrir(Canal canal) async {
    final mio = ++_intento;
    setState(() {
      _canal = canal;
      _estadoCanal = _Estado.conectando;
      _enlace = null;
    });
    widget.estado.recordarCanal(canal);
    final r = await abrirConReserva(canal, _motor, widget.estado.salud, timeout: widget.timeoutApertura, cancelado: () => mio != _intento || !mounted);
    if (!mounted || mio != _intento) return;
    widget.estado.guardarSalud();
    setState(() {
      _enlace = r.enlace;
      _estadoCanal = r.ok ? _Estado.reproduciendo : _Estado.sinSenal;
    });
    if (r.ok) _mostrarBarra();
  }

  void _reintentarActual() {
    if (!mounted) return;
    if (_enlace != null) widget.estado.salud.registrarFallo(_enlace!.url);
    _abrir(_canal);
  }

  void _mostrarBarra() {
    _timerBarra?.cancel();
    setState(() => _barra = true);
    _timerBarra = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _barra = false);
    });
  }

  void _ocultarBarra() {
    _timerBarra?.cancel();
    setState(() => _barra = false);
  }

  void _avisar(String texto) {
    _timerAviso?.cancel();
    setState(() => _aviso = texto);
    _timerAviso = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _aviso = null);
    });
  }

  void _irAlNumero(int n) {
    final c = canalPorNumero(_canales, n);
    if (c == null) {
      _avisar('No hay un canal $n');
    } else {
      _abrir(c);
    }
  }

  void _cambiar(Canal? c) {
    if (c != null && c.id != _canal.id) _abrir(c);
  }

  void _atras() {
    if (_barra) {
      _ocultarBarra();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  KeyEventResult _alTecla(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (kDebugMode) debugPrint('TECLA ${e.logicalKey.keyLabel} id=${e.logicalKey.keyId} fisica=${e.physicalKey.usbHidUsage}');
    final t = mapearTecla(e.logicalKey);
    switch (t.accion) {
      case Accion.canalSiguiente:
        _cambiar(canalSiguiente(_canales, _canal.id));
      case Accion.canalAnterior:
        _cambiar(canalAnterior(_canales, _canal.id));
      case Accion.derecha:
        if (!_barra) return KeyEventResult.ignored;
        _mostrarBarra();
        _cambiar(canalSiguiente(widget.estado.cartelera!.canalesDe(_canal.categoria), _canal.id));
      case Accion.izquierda:
        if (!_barra) return KeyEventResult.ignored;
        _mostrarBarra();
        _cambiar(canalAnterior(widget.estado.cartelera!.canalesDe(_canal.categoria), _canal.id));
      case Accion.digito:
        _marcado.digito(t.digito!);
      case Accion.aceptar:
        _barra ? _ocultarBarra() : _mostrarBarra();
      case Accion.info:
      case Accion.guia:
        _avisar('Esto llega en la próxima versión de SandyTV');
      case Accion.menu:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaAjustes(estado: widget.estado)));
      case Accion.atras:
        // En Android el botón Atrás llega por PopScope; acá solo se atiende Escape (PC).
        if (e.logicalKey == LogicalKeyboardKey.goBack) return KeyEventResult.ignored;
        _atras();
      case Accion.ninguna:
        return KeyEventResult.ignored; // el volumen lo maneja el televisor
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_barra,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _ocultarBarra();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: _alTecla,
          child: Stack(fit: StackFit.expand, children: [
            ValueListenableBuilder<VideoPlayerController?>(
              valueListenable: _motor.actual,
              builder: (_, c, _) {
                if (c == null || _estadoCanal != _Estado.reproduciendo) return const SizedBox.shrink();
                return Center(child: AspectRatio(aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio, child: VideoPlayer(c)));
              },
            ),
            if (_estadoCanal != _Estado.reproduciendo) _PantallaEspera(canal: _canal, sinSenal: _estadoCanal == _Estado.sinSenal),
            if (_barra && _estadoCanal == _Estado.reproduciendo) _BarraCanal(canal: _canal, enlace: _enlace),
            if (_marcando.isNotEmpty) _NumeroMarcado(texto: _marcando),
            if (_aviso != null) _Aviso(texto: _aviso!),
          ]),
        ),
      ),
    );
  }
}

class _PantallaEspera extends StatelessWidget {
  const _PantallaEspera({required this.canal, required this.sinSenal});
  final Canal canal;
  final bool sinSenal;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0A0E1A), Color(0xFF12304A)])),
      child: Stack(children: [
        const Positioned(top: 28, left: 40, child: LogoSandyTv(tam: 26)),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(height: 120, child: LogoCanal(url: canal.logo, nombre: canal.nombre, alto: 110)),
            const SizedBox(height: 16),
            Text('${canal.numero} · ${canal.nombre}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colores.texto)),
            const SizedBox(height: 22),
            if (!sinSenal) ...[
              const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 3, color: Colores.acento)),
              const SizedBox(height: 12),
              const Text('Conectando…', style: TextStyle(fontSize: 18, color: Colores.textoSuave)),
            ] else ...[
              const Text('Este canal no está disponible ahora', style: TextStyle(fontSize: 22, color: Colores.texto)),
              const SizedBox(height: 8),
              const Text('Con ↑ o ↓ pasás a otro canal · Atrás vuelve al inicio', style: TextStyle(fontSize: 16, color: Colores.textoSuave)),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _BarraCanal extends StatelessWidget {
  const _BarraCanal({required this.canal, required this.enlace});
  final Canal canal;
  final Enlace? enlace;

  @override
  Widget build(BuildContext context) {
    final detalle = [canal.emisora ?? canal.paisNombre, if (enlace?.alto != null) '${enlace!.alto}p'].whereType<String>().join(' · ');
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(40, 40, 40, 28),
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xE6000000)])),
        child: Row(children: [
          Container(
            width: 120, height: 70,
            decoration: BoxDecoration(color: Colores.superficie, borderRadius: BorderRadius.circular(10)),
            child: LogoCanal(url: canal.logo, nombre: canal.nombre, alto: 56),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${canal.numero}  ${canal.nombre}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colores.texto)),
              if (detalle.isNotEmpty) Text(detalle, style: const TextStyle(fontSize: 16, color: Colores.textoSuave)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _NumeroMarcado extends StatelessWidget {
  const _NumeroMarcado({required this.texto});
  final String texto;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topRight,
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(12)),
          child: Text(texto, style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w800, color: Colores.acento)),
        ),
      );
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.texto});
  final String texto;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: Container(
          margin: const EdgeInsets.only(top: 32),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xDD141B2D), borderRadius: BorderRadius.circular(24)),
          child: Text(texto, style: const TextStyle(fontSize: 18, color: Colores.texto)),
        ),
      );
}
