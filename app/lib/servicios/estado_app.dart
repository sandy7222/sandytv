import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logica/salud_enlaces.dart';
import '../modelos/cartelera.dart';
import '../modelos/formato_imagen.dart';
import 'repositorio_cartelera.dart';

class AlmacenPrefs implements Almacen {
  AlmacenPrefs(this.prefs);
  final SharedPreferences prefs;
  @override
  Future<String?> leer(String clave) async => prefs.getString(clave);
  @override
  Future<void> escribir(String clave, String valor) async => prefs.setString(clave, valor);
}

/// Lo que la app sabe en todo momento: la cartelera, la salud de los enlaces y las preferencias.
class EstadoApp extends ChangeNotifier {
  EstadoApp({required this.repo, required this.prefs, this.actualizacionAutomatica = true});

  /// Si es verdadero, busca una cartelera nueva cada 3 horas mientras la app está abierta.
  final bool actualizacionAutomatica;

  static const claveSalud = 'sandytv_salud';
  static const claveUltimo = 'sandytv_ultimo_canal';
  static const claveRetomar = 'sandytv_retomar';
  static const cadaCuanto = Duration(hours: 3);

  final RepositorioCartelera repo;
  final SharedPreferences prefs;

  Cartelera? cartelera;
  late SaludEnlaces salud;
  Timer? _timer;
  bool actualizando = false;

  String? get ultimoCanalId => prefs.getString(claveUltimo);
  bool get retomarAlAbrir => prefs.getBool(claveRetomar) ?? false;

  Canal? get ultimoCanal {
    final id = ultimoCanalId;
    return id == null ? null : cartelera?.canalPorId(id);
  }

  Future<void> iniciar() async {
    salud = SaludEnlaces.desdeTexto(prefs.getString(claveSalud));
    cartelera = await repo.cargarGuardada();
    notifyListeners();
    unawaited(refrescar());
    _timer?.cancel();
    if (actualizacionAutomatica) _timer = Timer.periodic(cadaCuanto, (_) => refrescar());
  }

  /// Baja la cartelera; si hay una versión nueva y válida la reemplaza sin cortar lo que se está mirando.
  Future<bool> refrescar() async {
    if (actualizando) return false;
    actualizando = true;
    notifyListeners();
    try {
      final nueva = await repo.actualizar(cartelera);
      if (nueva != null) {
        cartelera = nueva;
        return true;
      }
      return false;
    } finally {
      actualizando = false;
      notifyListeners();
    }
  }

  void recordarCanal(Canal c) => prefs.setString(claveUltimo, c.id);

  static const claveFormatoDefecto = 'sandytv_formato_defecto';
  static String _claveFormato(String canalId) => 'sandytv_formato_$canalId';

  /// Formato que se usa en los canales que no tienen uno propio.
  FormatoImagen get formatoDefecto => FormatoImagen.desdeCodigo(prefs.getString(claveFormatoDefecto)) ?? FormatoImagen.original;

  /// El formato de un canal: el que se eligió para ese canal, o el de por defecto.
  FormatoImagen formatoDe(String canalId) => FormatoImagen.desdeCodigo(prefs.getString(_claveFormato(canalId))) ?? formatoDefecto;

  Future<void> guardarFormato(String canalId, FormatoImagen f) async {
    await prefs.setString(_claveFormato(canalId), f.codigo);
    notifyListeners();
  }

  Future<void> cambiarFormatoDefecto(FormatoImagen f) async {
    await prefs.setString(claveFormatoDefecto, f.codigo);
    notifyListeners();
  }

  Future<void> guardarSalud() => prefs.setString(claveSalud, salud.comoTexto());

  Future<void> cambiarRetomar(bool v) async {
    await prefs.setBool(claveRetomar, v);
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
