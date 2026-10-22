import 'dart:async';

import '../modelos/cartelera.dart';
import 'salud_enlaces.dart';

/// El motor de video real implementa esto; en las pruebas se usa uno falso.
abstract class MotorVideo {
  /// Abre el enlace y espera a que arranque. Lanza una excepción si falla o se pasa del tiempo.
  Future<void> abrir(Enlace e, {required Duration timeout});
}

class ResultadoApertura {
  const ResultadoApertura(this.enlace, [this.errores = const []]);
  final Enlace? enlace;

  /// Por qué falló cada enlace probado (para mostrarlo en pantalla y poder diagnosticar).
  final List<String> errores;
  bool get ok => enlace != null;
}

String _host(String url) => Uri.tryParse(url)?.host.isNotEmpty == true ? Uri.parse(url).host : url;

String _motivo(Object error, Duration timeout) {
  if (error is TimeoutException) return 'no arrancó en ${timeout.inSeconds} s';
  var t = error.toString();
  for (final prefijo in ['Exception: ', 'Bad state: ', 'StateError: ', 'PlatformException(', 'VideoError, ']) {
    if (t.startsWith(prefijo)) t = t.substring(prefijo.length);
  }
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length > 110 ? '${t.substring(0, 110)}…' : t;
}

/// Prueba los enlaces del canal (primero los que andan) hasta que uno arranque.
Future<ResultadoApertura> abrirConReserva(
  Canal canal,
  MotorVideo motor,
  SaludEnlaces salud, {
  Duration timeout = const Duration(seconds: 10),
  bool Function()? cancelado,
}) async {
  final errores = <String>[];
  for (final e in salud.ordenar(canal)) {
    if (cancelado?.call() ?? false) return ResultadoApertura(null, errores);
    try {
      await motor.abrir(e, timeout: timeout);
      salud.registrarExito(e.url);
      return ResultadoApertura(e);
    } catch (error) {
      salud.registrarFallo(e.url);
      errores.add('${_host(e.url)}: ${_motivo(error, timeout)}');
    }
  }
  return ResultadoApertura(null, errores);
}
