import 'dart:convert';

class Enlace {
  const Enlace({
    required this.url,
    required this.alto,
    required this.kbps,
    required this.puntaje,
    required this.userAgent,
    required this.referrer,
  });

  final String url;
  final int? alto;
  final int? kbps;
  final int puntaje;
  final String? userAgent;
  final String? referrer;

  factory Enlace.desdeJson(Map<String, dynamic> j) => Enlace(
        url: j['url'] as String,
        alto: (j['alto'] as num?)?.toInt(),
        kbps: (j['kbps'] as num?)?.toInt(),
        puntaje: (j['puntaje'] as num?)?.toInt() ?? 0,
        userAgent: j['userAgent'] as String?,
        referrer: j['referrer'] as String?,
      );

  Map<String, String> get cabeceras => {
        'User-Agent': ?userAgent,
        'Referer': ?referrer,
      };
}

class Canal {
  const Canal({
    required this.id,
    required this.numero,
    required this.nombre,
    required this.emisora,
    required this.pais,
    required this.paisNombre,
    required this.categoria,
    required this.logo,
    required this.web,
    required this.forzado,
    required this.enlaces,
  });

  final String id;
  final int numero;
  final String nombre;
  final String? emisora;
  final String? pais;
  final String? paisNombre;
  final String categoria;
  final String? logo;
  final String? web;
  final bool forzado;
  final List<Enlace> enlaces;

  factory Canal.desdeJson(Map<String, dynamic> j) => Canal(
        id: j['id'] as String,
        numero: (j['numero'] as num).toInt(),
        nombre: j['nombre'] as String,
        emisora: j['emisora'] as String?,
        pais: j['pais'] as String?,
        paisNombre: j['paisNombre'] as String?,
        categoria: (j['categoria'] as String?) ?? 'otros',
        logo: j['logo'] as String?,
        web: j['web'] as String?,
        forzado: (j['forzado'] as bool?) ?? false,
        enlaces: ((j['enlaces'] as List?) ?? const [])
            .map((e) => Enlace.desdeJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Grupo {
  const Grupo({required this.id, required this.nombre, required this.orden});
  final String id;
  final String nombre;
  final int orden;
}

class Cartelera {
  Cartelera({required this.version, required this.grupos, required this.canales});

  final String version;
  final List<Grupo> grupos;
  final List<Canal> canales;

  /// Devuelve null si el texto no es una cartelera válida (así nunca se pisa una buena con una rota).
  static Cartelera? tryParse(String texto) {
    try {
      final j = jsonDecode(texto);
      if (j is! Map<String, dynamic>) return null;
      if (j['formato'] != 1) return null;
      final canales = <Canal>[];
      for (final c in (j['canales'] as List)) {
        try {
          final canal = Canal.desdeJson(c as Map<String, dynamic>);
          if (canal.enlaces.isNotEmpty) canales.add(canal);
        } catch (_) {
          // un canal mal formado se ignora
        }
      }
      if (canales.isEmpty) return null;
      final grupos = ((j['categorias'] as List?) ?? const [])
          .map((g) => g as Map<String, dynamic>)
          .map((g) => Grupo(id: g['id'] as String, nombre: g['nombre'] as String, orden: (g['orden'] as num?)?.toInt() ?? 99))
          .toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
      return Cartelera(version: j['version'] as String, grupos: grupos, canales: canales);
    } catch (_) {
      return null;
    }
  }

  Canal? canalPorId(String id) {
    for (final c in canales) {
      if (c.id == id) return c;
    }
    return null;
  }

  Canal? canalPorNumero(int numero) {
    for (final c in canales) {
      if (c.numero == numero) return c;
    }
    return null;
  }

  List<Canal> canalesDe(String grupoId) => canales.where((c) => c.categoria == grupoId).toList();

  List<Grupo> get gruposConCanales => grupos.where((g) => canales.any((c) => c.categoria == g.id)).toList();
}
