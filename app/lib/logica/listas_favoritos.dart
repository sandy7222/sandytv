import 'dart:convert';

import '../modelos/cartelera.dart';

/// Una lista de favoritos con título. Los canales se guardan por su id (por ejemplo "Telefe.ar"),
/// nunca por número, porque el número puede cambiar entre versiones de la cartelera.
class ListaFav {
  ListaFav({required this.id, required this.titulo, this.agrupar = false, List<String>? canales}) : canales = canales ?? [];

  final String id;
  String titulo;

  /// Si es verdadero, la lista se muestra agrupada por categoría.
  bool agrupar;
  final List<String> canales;

  Map<String, dynamic> toJson() => {'id': id, 'titulo': titulo, 'agrupar': agrupar, 'canales': canales};
}

/// Un lugar de la lista: el canal, o null si ya no está en la cartelera (se muestra atenuado).
class EntradaLista {
  const EntradaLista(this.id, this.canal);
  final String id;
  final Canal? canal;
}

class GrupoDeLista {
  const GrupoDeLista(this.grupo, this.canales);
  final Grupo grupo;
  final List<Canal> canales;
}

/// Todas las listas de favoritos y cuál está fijada como lista de inicio.
class ListasFavoritos {
  ListasFavoritos({List<ListaFav>? listas, String? fijada})
      : listas = listas ?? [],
        _fijada = fijada;

  final List<ListaFav> listas;
  String? _fijada;

  /// La lista con la que se abre la app, o null para abrir en "Todos los canales".
  String? get fijada => _fijada;

  ListaFav? porId(String id) {
    for (final l in listas) {
      if (l.id == id) return l;
    }
    return null;
  }

  String _idNuevo(String titulo) {
    final base = titulo.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúñ]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    final raiz = base.isEmpty ? 'lista' : base;
    var id = raiz;
    var n = 2;
    while (porId(id) != null) {
      id = '$raiz-${n++}';
    }
    return id;
  }

  ListaFav crear(String titulo) {
    var t = titulo.trim();
    if (t.isEmpty) t = listas.isEmpty ? 'Mi lista' : 'Lista ${listas.length + 1}';
    final lista = ListaFav(id: _idNuevo(t), titulo: t);
    listas.add(lista);
    return lista;
  }

  bool renombrar(String id, String titulo) {
    final l = porId(id);
    final t = titulo.trim();
    if (l == null || t.isEmpty) return false;
    l.titulo = t;
    return true;
  }

  /// La última lista no se puede borrar. Si se borra la fijada, se quita la fijación.
  bool borrar(String id) {
    final l = porId(id);
    if (l == null || listas.length <= 1) return false;
    listas.remove(l);
    if (_fijada == id) _fijada = null;
    return true;
  }

  void fijar(String? id) {
    _fijada = (id != null && porId(id) != null) ? id : null;
  }

  bool contiene(String listaId, String canalId) => porId(listaId)?.canales.contains(canalId) ?? false;

  void agregar(String listaId, String canalId) {
    final l = porId(listaId);
    if (l != null && !l.canales.contains(canalId)) l.canales.add(canalId);
  }

  void quitar(String listaId, String canalId) => porId(listaId)?.canales.remove(canalId);

  void mover(String listaId, int desde, int hasta) {
    final l = porId(listaId);
    if (l == null) return;
    if (desde < 0 || desde >= l.canales.length || hasta < 0 || hasta >= l.canales.length) return;
    l.canales.insert(hasta, l.canales.removeAt(desde));
  }

  List<EntradaLista> resolver(String listaId, Cartelera c) {
    final l = porId(listaId);
    if (l == null) return const [];
    return [for (final id in l.canales) EntradaLista(id, c.canalPorId(id))];
  }

  /// Solo los canales que existen hoy en la cartelera, en el orden de la lista.
  List<Canal> canalesDe(String listaId, Cartelera c) => [
        for (final e in resolver(listaId, c))
          if (e.canal != null) e.canal!
      ];

  List<GrupoDeLista> agruparPorCategoria(String listaId, Cartelera c) {
    final canales = canalesDe(listaId, c);
    return [
      for (final g in c.grupos)
        if (canales.any((x) => x.categoria == g.id)) GrupoDeLista(g, canales.where((x) => x.categoria == g.id).toList())
    ];
  }

  String comoTexto() => jsonEncode({
        'version': 1,
        'fijada': _fijada,
        'listas': [for (final l in listas) l.toJson()],
      });

  /// Un texto roto o vacío da una colección vacía: nunca rompe la app.
  static ListasFavoritos desdeTexto(String? texto) {
    if (texto == null) return ListasFavoritos();
    try {
      final j = jsonDecode(texto);
      if (j is! Map || j['listas'] is! List) return ListasFavoritos();
      final r = ListasFavoritos();
      for (final x in j['listas'] as List) {
        if (x is! Map || x['id'] is! String || x['titulo'] is! String) continue;
        r.listas.add(ListaFav(
          id: x['id'] as String,
          titulo: x['titulo'] as String,
          agrupar: x['agrupar'] == true,
          canales: [for (final c in (x['canales'] as List? ?? const [])) if (c is String) c],
        ));
      }
      r.fijar(j['fijada'] is String ? j['fijada'] as String : null);
      return r;
    } catch (_) {
      return ListasFavoritos();
    }
  }

  /// "Mi lista" de arranque: los mejores canales de Argentina por puntaje (o, si no hay, de cualquier grupo).
  static ListasFavoritos inicial(Cartelera c, {int max = 15}) {
    var candidatos = c.canales.where((x) => x.categoria == 'argentina').toList();
    if (candidatos.isEmpty) candidatos = [...c.canales];
    candidatos.sort((a, b) => (b.enlaces.first.puntaje).compareTo(a.enlaces.first.puntaje));
    final r = ListasFavoritos();
    final lista = r.crear('Mi lista');
    for (final x in candidatos.take(max)) {
      lista.canales.add(x.id);
    }
    return r;
  }
}
