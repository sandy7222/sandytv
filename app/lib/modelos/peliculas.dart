import 'dart:convert';

/// Una película del catálogo. Se reproduce con el reproductor oficial de YouTube.
class Pelicula {
  const Pelicula({
    required this.id,
    required this.titulo,
    required this.canal,
    required this.genero,
    required this.portada,
    required this.duracionMin,
  });

  /// El código del video de YouTube.
  final String id;
  final String titulo;
  final String canal;
  final String genero;
  final String? portada;
  final int? duracionMin;

  String get urlYoutube => 'https://www.youtube.com/watch?v=$id';
}

class GeneroPeli {
  const GeneroPeli({required this.id, required this.nombre});
  final String id;
  final String nombre;
}

class CatalogoPeliculas {
  CatalogoPeliculas({required this.version, required this.generos, required this.peliculas});

  final String version;
  final List<GeneroPeli> generos;
  final List<Pelicula> peliculas;

  static const _otras = GeneroPeli(id: 'otras', nombre: 'Otras');

  /// Devuelve null si el texto no es un catálogo válido (así nunca se pisa uno bueno con uno roto).
  static CatalogoPeliculas? tryParse(String texto) {
    try {
      final j = jsonDecode(texto);
      if (j is! Map<String, dynamic> || j['formato'] != 1) return null;
      final generos = <GeneroPeli>[
        for (final g in (j['generos'] as List? ?? const []))
          if (g is Map && g['id'] is String && g['nombre'] is String) GeneroPeli(id: g['id'] as String, nombre: g['nombre'] as String)
      ];
      final conocidos = generos.map((g) => g.id).toSet();
      final peliculas = <Pelicula>[];
      for (final p in (j['peliculas'] as List? ?? const [])) {
        if (p is! Map || p['id'] is! String || p['titulo'] is! String) continue;
        final genero = p['genero'] is String && conocidos.contains(p['genero']) ? p['genero'] as String : _otras.id;
        peliculas.add(Pelicula(
          id: p['id'] as String,
          titulo: p['titulo'] as String,
          canal: p['canal'] is String ? p['canal'] as String : '',
          genero: genero,
          portada: p['portada'] is String ? p['portada'] as String : null,
          duracionMin: (p['duracionMin'] as num?)?.toInt(),
        ));
      }
      if (peliculas.isEmpty) return null;
      return CatalogoPeliculas(version: (j['version'] as String?) ?? '', generos: generos, peliculas: peliculas);
    } catch (_) {
      return null;
    }
  }

  List<Pelicula> delGenero(String generoId) => peliculas.where((p) => p.genero == generoId).toList();

  List<GeneroPeli> get generosConPeliculas => [
        for (final g in [...generos, _otras])
          if (peliculas.any((p) => p.genero == g.id)) g
      ];
}
