import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../logica/apertura.dart';
import '../modelos/cartelera.dart';

/// Motor de video real. Solo reproduce: no muestra controles ni nombre de ningún reproductor.
class MotorVideoReal implements MotorVideo {
  final ValueNotifier<VideoPlayerController?> actual = ValueNotifier(null);

  /// Se llama si un canal que ya estaba andando deja de funcionar.
  VoidCallback? alError;

  int _generacion = 0;
  VideoPlayerController? _controlador;

  @override
  Future<void> abrir(Enlace e, {required Duration timeout}) async {
    final mia = ++_generacion;
    await soltar();
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
    } catch (_) {
      // No se espera la liberación: si tarda, no tiene que demorar el pase al enlace de reserva.
      c.dispose().catchError((Object _) {});
      rethrow;
    }
    _controlador = c;
    c.addListener(_vigilar);
    actual.value = c;
  }

  void _vigilar() {
    if (_controlador?.value.hasError ?? false) {
      _controlador!.removeListener(_vigilar);
      alError?.call();
    }
  }

  /// Cancela lo que se esté abriendo y libera el video actual.
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

  Future<void> dispose() async {
    await soltar();
    actual.dispose();
  }
}
