import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../logica/apertura.dart';
import '../modelos/cartelera.dart';

/// Lo que la pantalla del canal necesita de un motor de video (en las pruebas se usa uno falso).
abstract class MotorPantalla implements MotorVideo {
  /// El video que se está mostrando ahora, o null si no hay ninguno.
  ValueListenable<VideoPlayerController?> get actual;

  /// Se llama si un canal que ya estaba andando deja de funcionar.
  VoidCallback? alError;

  /// Cancela lo que se esté abriendo y libera el video actual.
  Future<void> soltar();

  Future<void> dispose();
}

/// Motor de video real. Solo reproduce: no muestra controles ni nombre de ningún reproductor.
///
/// Al abrir un canal nuevo NO corta el que está andando: lo deja hasta que el nuevo arranca
/// y recién ahí hace el cambio, para que cambiar de canal no tenga cortes.
class MotorVideoReal extends MotorPantalla {
  @override
  final ValueNotifier<VideoPlayerController?> actual = ValueNotifier(null);

  int _generacion = 0;
  VideoPlayerController? _controlador;

  @override
  Future<void> abrir(Enlace e, {required Duration timeout}) async {
    final mia = ++_generacion;
    final c = VideoPlayerController.networkUrl(
      Uri.parse(e.url),
      httpHeaders: e.cabeceras,
      formatHint: VideoFormat.hls,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    try {
      await c.initialize().timeout(timeout);
      if (c.value.hasError) throw StateError(c.value.errorDescription ?? 'error de video');
      if (mia != _generacion) throw StateError('cancelado');
      await c.play();
      if (mia != _generacion) throw StateError('cancelado');
    } catch (_) {
      // No se espera la liberación: si tarda, no tiene que demorar el pase al enlace de reserva.
      c.dispose().catchError((Object _) {});
      rethrow;
    }
    final anterior = _controlador;
    anterior?.removeListener(_vigilar);
    _controlador = c;
    c.addListener(_vigilar);
    actual.value = c;
    if (anterior != null) anterior.dispose().catchError((Object _) {});
  }

  void _vigilar() {
    if (_controlador?.value.hasError ?? false) {
      _controlador!.removeListener(_vigilar);
      alError?.call();
    }
  }

  @override
  Future<void> soltar() async {
    _generacion++;
    final c = _controlador;
    _controlador = null;
    actual.value = null;
    if (c != null) {
      c.removeListener(_vigilar);
      await c.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    await soltar();
    actual.dispose();
  }
}
