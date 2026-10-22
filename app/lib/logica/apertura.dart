import '../modelos/cartelera.dart';
import 'salud_enlaces.dart';

/// El motor de video real implementa esto; en las pruebas se usa uno falso.
abstract class MotorVideo {
  /// Abre el enlace y espera a que arranque. Lanza una excepción si falla o se pasa del tiempo.
  Future<void> abrir(Enlace e, {required Duration timeout});
}

class ResultadoApertura {
  const ResultadoApertura(this.enlace);
  final Enlace? enlace;
  bool get ok => enlace != null;
}

/// Prueba los enlaces del canal (primero los que andan) hasta que uno arranque.
Future<ResultadoApertura> abrirConReserva(
  Canal canal,
  MotorVideo motor,
  SaludEnlaces salud, {
  Duration timeout = const Duration(seconds: 10),
  bool Function()? cancelado,
}) async {
  for (final e in salud.ordenar(canal)) {
    if (cancelado?.call() ?? false) return const ResultadoApertura(null);
    try {
      await motor.abrir(e, timeout: timeout);
      salud.registrarExito(e.url);
      return ResultadoApertura(e);
    } catch (_) {
      salud.registrarFallo(e.url);
    }
  }
  return const ResultadoApertura(null);
}
