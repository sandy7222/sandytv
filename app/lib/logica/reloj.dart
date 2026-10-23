import 'dart:io' show HttpDate;

/// Reloj con la hora de Argentina (UTC-3, sin horario de verano), corregido con la hora de GitHub.
///
/// GitHub no ofrece un servicio de hora, pero toda respuesta HTTP trae el encabezado `Date` con la
/// hora exacta del servidor. Se lee al bajar la cartelera y se guarda la diferencia con el reloj del
/// televisor; así la hora es correcta aunque el televisor la tenga mal puesta.
class RelojArgentino {
  RelojArgentino({DateTime Function()? ahoraUtc}) : _ahoraUtc = ahoraUtc ?? (() => DateTime.now().toUtc());

  final DateTime Function() _ahoraUtc;
  Duration _desfase = Duration.zero;
  bool _sincronizado = false;

  bool get sincronizado => _sincronizado;

  /// Guarda cuánto se adelanta o atrasa el reloj del televisor respecto de la hora del servidor.
  void sincronizar(DateTime fechaServidorUtc) {
    _desfase = fechaServidorUtc.toUtc().difference(_ahoraUtc());
    _sincronizado = true;
  }

  /// La hora de Argentina, como una fecha "de pared" (los campos hora y minuto son los que se ven).
  DateTime ahoraArgentina() => _ahoraUtc().add(_desfase).subtract(const Duration(hours: 3));

  String hora() {
    final a = ahoraArgentina();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(a.hour)}:${dos(a.minute)}';
  }

  /// Lee el encabezado `Date` de una respuesta HTTP; null si falta o no se entiende.
  static DateTime? fechaDeEncabezado(String? valor) {
    if (valor == null) return null;
    try {
      return HttpDate.parse(valor).toUtc();
    } catch (_) {
      return null;
    }
  }
}
