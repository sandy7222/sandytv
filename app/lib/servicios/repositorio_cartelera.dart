import '../modelos/cartelera.dart';

abstract class Almacen {
  Future<String?> leer(String clave);
  Future<void> escribir(String clave, String valor);
}

/// Carga y actualiza la cartelera. Nunca reemplaza una cartelera buena por una rota o vacía.
class RepositorioCartelera {
  RepositorioCartelera({
    required this.almacen,
    required this.descargar,
    required this.url,
    this.cargarInicial,
  });

  static const claveGuardada = 'sandytv_cartelera';

  final Almacen almacen;
  final Future<String> Function(Uri url) descargar;
  final Uri url;

  /// Cartelera que viene dentro de la app, para el primer arranque sin internet.
  final Future<String> Function()? cargarInicial;

  Future<Cartelera?> cargarGuardada() async {
    final guardada = await almacen.leer(claveGuardada);
    final c = guardada == null ? null : Cartelera.tryParse(guardada);
    if (c != null) return c;
    if (cargarInicial == null) return null;
    try {
      return Cartelera.tryParse(await cargarInicial!());
    } catch (_) {
      return null;
    }
  }

  /// Devuelve la cartelera nueva si hay una versión distinta y válida; si no, null.
  Future<Cartelera?> actualizar(Cartelera? actual) async {
    try {
      final texto = await descargar(url);
      final nueva = Cartelera.tryParse(texto);
      if (nueva == null) return null;
      if (actual != null && nueva.version == actual.version) return null;
      await almacen.escribir(claveGuardada, texto);
      return nueva;
    } catch (_) {
      return null;
    }
  }
}
