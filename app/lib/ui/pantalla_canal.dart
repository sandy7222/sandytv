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
  const PantallaCanal({
    super.key,
    required this.estado,
    required this.canalInicial,
    this.timeoutApertura = const Duration(seconds: 10),
    this.crearMotor,
  });
  final EstadoApp estado;
  final Canal canalInicial;

  /// Cuánto se espera a que un enlace arranque antes de probar el de reserva.
  final Duration timeoutApertura;

  /// Solo para pruebas: permite usar un motor de video falso.
  final MotorPantalla Function()? crearMotor;

  @override
  State<PantallaCanal> createState() => _PantallaCanalState();
}

class _PantallaCanalState extends State<PantallaCanal> {
  late final MotorPantalla _motor = widget.crearMotor?.call() ?? MotorVideoReal();

  /// El canal que se eligió (de acá se sigue al apretar ↑ o ↓, ande o no ande).
  late Canal _objetivo;

  /// El canal que se está viendo ahora; null si todavía no arrancó ninguno.
  Canal? _enAire;
  _Estado _estadoCanal = _Estado.conectando;
  bool _cambiando = false;
  Enlace? _enlace;
  bool _barra = false;
  String _marcando = '';
  String? _aviso;
  Timer? _timerBarra;
  Timer? _timerAviso;
  late final MarcadoNumerico _marcado;
  int _intento = 0;
  List<String> _errores = const [];

  List<Canal> get _canales => widget.estado.cartelera?.canales ?? const [];

  @override
  void initState() {
    super.initState();
    _objetivo = widget.canalInicial;
    _marcado = MarcadoNumerico(
      alCambiar: (t) => setState(() => _marcando = t),
      alTerminar: _irAlNumero,
    );
    _motor.alError = _reintentarActual;
    _pantallaEncendida(true);
    _abrir(_objetivo);
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

  /// Cambia de canal sin cortes: el que se está viendo sigue hasta que el nuevo arranque.
  Future<void> _abrir(Canal canal) async {
    final mio = ++_intento;
    _timerBarra?.cancel();
    setState(() {
      _objetivo = canal;
      _cambiando = true;
      _errores = const [];
      _barra = true; // la barra avisa de inmediato a qué canal se está cambiando
      if (_enAire == null) _estadoCanal = _Estado.conectando;
    });
    final r = await abrirConReserva(canal, _motor, widget.estado.salud,
        timeout: widget.timeoutApertura, cancelado: () => mio != _intento || !mounted);
    if (!mounted || mio != _intento) return;
    widget.estado.guardarSalud();
    if (r.ok) {
      widget.estado.recordarCanal(canal);
      setState(() {
        _enAire = canal;
        _enlace = r.enlace;
        _errores = const [];
        _cambiando = false;
        _estadoCanal = _Estado.reproduciendo;
      });
      _mostrarBarra();
    } else if (_enAire != null) {
      // No se corta lo que se estaba mirando: se avisa abajo y se sigue.
      setState(() {
        _cambiando = false;
        _barra = false;
      });
      _avisar('Canal ${canal.numero} no disponible');
    } else {
      setState(() {
        _cambiando = false;
        _errores = r.errores;
        _estadoCanal = _Estado.sinSenal;
      });
    }
  }

  void _reintentarActual() {
    if (!mounted) return;
    if (_enlace != null) widget.estado.salud.registrarFallo(_enlace!.url);
    setState(() {
      _enAire = null;
      _estadoCanal = _Estado.conectando;
    });
    _abrir(_objetivo);
  }

  void _mostrarBarra() {
    _timerBarra?.cancel();
    setState(() => _barra = true);
    _timerBarra = Timer(const Duration(seconds: 5), () {
      if (mounted && !_cambiando) setState(() => _barra = false);
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
      _cambiar(c);
    }
  }

  void _cambiar(Canal? c) {
    if (c != null && c.id != _objetivo.id) _abrir(c);
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
        _cambiar(canalSiguiente(_canales, _objetivo.id));
      case Accion.canalAnterior:
        _cambiar(canalAnterior(_canales, _objetivo.id));
      case Accion.derecha:
        if (!_barra) return KeyEventResult.ignored;
        _cambiar(canalSiguiente(widget.estado.cartelera!.canalesDe(_objetivo.categoria), _objetivo.id));
      case Accion.izquierda:
        if (!_barra) return KeyEventResult.ignored;
        _cambiar(canalAnterior(widget.estado.cartelera!.canalesDe(_objetivo.categoria), _objetivo.id));
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
    final hayVideo = _enAire != null;
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
                if (c == null || !hayVideo) return const SizedBox.shrink();
                return Center(child: AspectRatio(aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio, child: VideoPlayer(c)));
              },
            ),
            if (!hayVideo) _PantallaEspera(canal: _objetivo, sinSenal: _estadoCanal == _Estado.sinSenal, detalle: _errores),
            if (_barra && hayVideo) _BarraCanal(canal: _objetivo, enlace: _cambiando ? null : _enlace, sintonizando: _cambiando),
            if (_marcando.isNotEmpty) _NumeroMarcado(texto: _marcando),
            if (_aviso != null) _Aviso(texto: _aviso!),
          ]),
        ),
      ),
    );
  }
}

class _PantallaEspera extends StatelessWidget {
  const _PantallaEspera({required this.canal, required this.sinSenal, this.detalle = const []});
  final Canal canal;
  final bool sinSenal;

  /// Por qué falló cada enlace (para saber si el problema es el canal o el reproductor).
  final List<String> detalle;

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
              for (final d in detalle.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(d, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colores.textoSuave)),
                ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Barra de abajo: a qué canal se cambió (se ve por unos segundos sobre el video en vivo).
class _BarraCanal extends StatelessWidget {
  const _BarraCanal({required this.canal, required this.enlace, this.sintonizando = false});
  final Canal canal;
  final Enlace? enlace;

  /// Mientras el canal nuevo todavía está arrancando.
  final bool sintonizando;

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
              if (sintonizando)
                const Text('Sintonizando…', style: TextStyle(fontSize: 16, color: Colores.acento))
              else if (detalle.isNotEmpty)
                Text(detalle, style: const TextStyle(fontSize: 16, color: Colores.textoSuave)),
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
