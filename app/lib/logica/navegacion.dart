import '../modelos/cartelera.dart';

Canal? canalSiguiente(List<Canal> lista, String actualId) {
  if (lista.isEmpty) return null;
  final i = lista.indexWhereId(actualId);
  return lista[(i + 1) % lista.length];
}

Canal? canalAnterior(List<Canal> lista, String actualId) {
  if (lista.isEmpty) return null;
  final i = lista.indexWhereId(actualId);
  if (i < 0) return lista.first;
  return lista[(i - 1 + lista.length) % lista.length];
}

Canal? canalPorNumero(List<Canal> lista, int numero) {
  for (final c in lista) {
    if (c.numero == numero) return c;
  }
  return null;
}

extension on List<Canal> {
  int indexWhereId(String id) => indexWhere((c) => c.id == id);
}
