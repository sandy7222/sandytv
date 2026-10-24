import 'dart:convert';

/// Un canal que transmite en vivo por YouTube. Se abre con la app oficial de YouTube del televisor.
class CanalEnVivo {
  CanalEnVivo({required this.id, required this.titulo, required this.url, required this.grupo, required this.portada, this.propio = false});
  final String id;

  /// Se puede cambiar (los que agrega el dueño con el editor).
  String titulo;

  /// Si lo cargó el dueño con el editor (se puede cambiar o borrar); los que vienen con la app no.
  final bool propio;

  /// Dirección de la transmisión en vivo del canal (por ejemplo https://www.youtube.com/@canal/live).
  final String url;
  String grupo;
  final String? portada;

  Map<String, dynamic> toJson() => {'id': id, 'titulo': titulo, 'url': url, 'grupo': grupo};
}

/// Deja una dirección de YouTube lista para abrirse. Si es la de un canal (por ejemplo youtube.com/@canal),
/// le agrega /live para que abra lo que está en vivo. Devuelve null si no es de YouTube.
String? normalizarUrlYoutube(String texto) {
  var t = texto.trim();
  if (t.isEmpty) return null;
  if (!t.contains('://')) t = 'https://$t';
  final u = Uri.tryParse(t);
  if (u == null || (u.scheme != 'https' && u.scheme != 'http')) return null;
  final h = u.host.toLowerCase();
  if (!(h == 'www.youtube.com' || h == 'youtube.com' || h == 'm.youtube.com' || h == 'youtu.be')) return null;
  final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
  // youtube.com y m.youtube.com pasan a www.youtube.com; youtu.be queda como está
  var destino = u.replace(scheme: 'https', host: h == 'youtu.be' ? h : 'www.youtube.com');
  if (h != 'youtu.be') {
    final esCanal = (segs.length == 1 && segs[0].startsWith('@')) || (segs.length == 2 && ['channel', 'c', 'user'].contains(segs[0]));
    if (esCanal) destino = destino.replace(pathSegments: [...segs, 'live']);
  }
  return destino.toString();
}

class GrupoEnVivo {
  const GrupoEnVivo({required this.id, required this.nombre});
  final String id;
  final String nombre;
}

/// Los canales de YouTube en vivo que elige el dueño (no todo lo que hay en YouTube).
class CatalogoEnVivo {
  CatalogoEnVivo({required this.version, required this.grupos, required this.canales});
  final String version;
  final List<GrupoEnVivo> grupos;
  final List<CanalEnVivo> canales;

  static const _otros = GrupoEnVivo(id: 'otros', nombre: 'Otros');

  /// Grupos que se ofrecen si el archivo que viene con la app no trae los suyos.
  static const gruposPorDefecto = [
    GrupoEnVivo(id: 'noticias', nombre: 'Noticias'),
    GrupoEnVivo(id: 'deportes', nombre: 'Deportes'),
    GrupoEnVivo(id: 'musica', nombre: 'Música'),
    GrupoEnVivo(id: 'otros', nombre: 'Otros'),
  ];

  static bool _esYoutube(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.scheme != 'https') return false;
    final h = u.host.toLowerCase();
    return h == 'www.youtube.com' || h == 'youtube.com' || h == 'm.youtube.com' || h == 'youtu.be';
  }

  /// Devuelve null si el texto no es un catálogo válido o no tiene canales.
  static CatalogoEnVivo? tryParse(String texto) {
    try {
      final j = jsonDecode(texto);
      if (j is! Map<String, dynamic> || j['formato'] != 1) return null;
      final grupos = <GrupoEnVivo>[
        for (final g in (j['grupos'] as List? ?? const []))
          if (g is Map && g['id'] is String && g['nombre'] is String) GrupoEnVivo(id: g['id'] as String, nombre: g['nombre'] as String)
      ];
      final conocidos = grupos.map((g) => g.id).toSet();
      final canales = <CanalEnVivo>[];
      for (final c in (j['canales'] as List? ?? const [])) {
        if (c is! Map || c['id'] is! String || c['titulo'] is! String || c['url'] is! String) continue;
        if (!_esYoutube(c['url'] as String)) continue; // solo enlaces de YouTube
        canales.add(CanalEnVivo(
          id: c['id'] as String,
          titulo: c['titulo'] as String,
          url: c['url'] as String,
          grupo: c['grupo'] is String && conocidos.contains(c['grupo']) ? c['grupo'] as String : _otros.id,
          portada: c['portada'] is String ? c['portada'] as String : null,
        ));
      }
      if (canales.isEmpty) return null;
      return CatalogoEnVivo(version: (j['version'] as String?) ?? '', grupos: grupos, canales: canales);
    } catch (_) {
      return null;
    }
  }

  List<CanalEnVivo> delGrupo(String grupoId) => canales.where((c) => c.grupo == grupoId).toList();

  List<GrupoEnVivo> get gruposConCanales => [
        for (final g in [...grupos, _otros])
          if (canales.any((c) => c.grupo == g.id)) g
      ];
}
