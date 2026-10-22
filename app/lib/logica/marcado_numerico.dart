import 'dart:async';

/// Junta los números que se van marcando con el control y avisa cuando se terminó de marcar.
class MarcadoNumerico {
  MarcadoNumerico({
    required this.alTerminar,
    this.alCambiar,
    this.espera = const Duration(milliseconds: 1500),
    this.maxDigitos = 4,
  });

  final void Function(int numero) alTerminar;
  final void Function(String actual)? alCambiar;
  final Duration espera;
  final int maxDigitos;

  String _actual = '';
  Timer? _timer;

  String get actual => _actual;

  void digito(int d) {
    _timer?.cancel();
    _actual += '$d';
    alCambiar?.call(_actual);
    if (_actual.length >= maxDigitos) {
      _terminar();
      return;
    }
    _timer = Timer(espera, _terminar);
  }

  void _terminar() {
    _timer?.cancel();
    final numero = int.tryParse(_actual);
    _actual = '';
    alCambiar?.call(_actual);
    if (numero != null) alTerminar(numero);
  }

  void cancelar() {
    _timer?.cancel();
    _actual = '';
    alCambiar?.call(_actual);
  }

  void dispose() => _timer?.cancel();
}
