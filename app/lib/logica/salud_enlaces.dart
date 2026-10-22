import 'dart:convert';

import '../modelos/cartelera.dart';

/// Recuerda en el aparato qué enlaces fallaron seguido, para probar primero los que andan.
class SaludEnlaces {
  SaludEnlaces([Map<String, int>? fallos]) : _fallos = fallos ?? {};

  final Map<String, int> _fallos;

  int fallosDe(String url) => _fallos[url] ?? 0;

  void registrarFallo(String url) => _fallos[url] = fallosDe(url) + 1;

  void registrarExito(String url) => _fallos.remove(url);

  List<Enlace> ordenar(Canal c) {
    final lista = [...c.enlaces];
    lista.sort((a, b) {
      final porFallos = fallosDe(a.url).compareTo(fallosDe(b.url));
      return porFallos != 0 ? porFallos : b.puntaje.compareTo(a.puntaje);
    });
    return lista;
  }

  /// Un canal cuyos enlaces fallaron todos 3 veces seguidas pasa al final de su fila.
  bool canalConFallas(Canal c, {int umbral = 3}) =>
      c.enlaces.isNotEmpty && c.enlaces.every((e) => fallosDe(e.url) >= umbral);

  String comoTexto() => jsonEncode(_fallos);

  factory SaludEnlaces.desdeTexto(String? texto) {
    if (texto == null) return SaludEnlaces();
    try {
      final j = jsonDecode(texto);
      if (j is! Map) return SaludEnlaces();
      return SaludEnlaces({for (final e in j.entries) e.key as String: (e.value as num).toInt()});
    } catch (_) {
      return SaludEnlaces();
    }
  }
}
