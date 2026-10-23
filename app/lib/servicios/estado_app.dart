import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logica/listas_favoritos.dart';
import '../logica/reloj.dart';
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
  EstadoApp({required this.repo, required this.prefs, this.actualizacionAutomatica = true, RelojArgentino? reloj})
      : reloj = reloj ?? RelojArgentino();

  /// Hora de Argentina, corregida con la hora de GitHub.
  final RelojArgentino reloj;

  static const claveReloj = 'sandytv_reloj';

  bool get mostrarReloj => prefs.getBool(claveReloj) ?? true;

  Future<void> cambiarMostrarReloj(bool v) async {
    await prefs.setBool(claveReloj, v);
    notifyListeners();
  }

  /// Si es verdadero, busca una cartelera nueva cada 3 horas mientras la app está abierta.
  final bool actualizacionAutomatica;

  static const claveSalud = 'sandytv_salud';
  static const claveListas = 'sandytv_listas';
  static const claveUltimo = 'sandytv_ultimo_canal';
  static const claveRetomar = 'sandytv_retomar';
  static const cadaCuanto = Duration(hours: 3);

  final RepositorioCartelera repo;
  final SharedPreferences prefs;

  Cartelera? cartelera;
  late SaludEnlaces salud;

  /// Listas de favoritos del dueño y la que se está viendo ahora (null = todos los canales).
  ListasFavoritos listas = ListasFavoritos();
  String? listaActivaId;

  ListaFav? get listaActiva => listaActivaId == null ? null : listas.porId(listaActivaId!);

  /// Solo si la lista activa tiene al menos un canal que existe hoy en la cartelera.
  bool get _usaLista {
    final c = cartelera;
    final l = listaActivaId;
    return c != null && l != null && listas.canalesDe(l, c).isNotEmpty;
  }

  /// Los canales entre los que se cambia con ↑ y ↓: los de la lista activa, o todos.
  List<Canal> get canalesActivos {
    final c = cartelera;
    if (c == null) return const [];
    return _usaLista ? listas.canalesDe(listaActivaId!, c) : c.canales;
  }

  /// El número que se ve en pantalla: la posición en la lista activa, o el número de la cartelera.
  int numeroVisible(Canal canal) {
    if (!_usaLista) return canal.numero;
    final i = canalesActivos.indexWhere((x) => x.id == canal.id);
    return i >= 0 ? i + 1 : canal.numero;
  }

  Canal? canalPorNumeroActivo(int n) {
    if (!_usaLista) return cartelera?.canalPorNumero(n);
    final lista = canalesActivos;
    return (n >= 1 && n <= lista.length) ? lista[n - 1] : null;
  }

  void activarLista(String? id) {
    listaActivaId = (id != null && listas.porId(id) != null) ? id : null;
    notifyListeners();
  }

  /// Guarda las listas en el aparato y avisa a las pantallas. Se llama después de cualquier cambio.
  Future<void> cambioEnListas() async {
    await prefs.setString(claveListas, listas.comoTexto());
    notifyListeners();
  }

  ListaFav crearLista(String titulo) {
    final l = listas.crear(titulo);
    cambioEnListas();
    return l;
  }

  Future<bool> borrarLista(String id) async {
    final ok = listas.borrar(id);
    if (listaActivaId == id) listaActivaId = null;
    await cambioEnListas();
    return ok;
  }

  /// Fija la lista con la que se abre la app (null = abrir en todos los canales).
  Future<void> fijarLista(String? id) async {
    listas.fijar(id);
    await cambioEnListas();
  }
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
    listas = ListasFavoritos.desdeTexto(prefs.getString(claveListas));
    if (listas.listas.isEmpty && cartelera != null) {
      // Primera vez: "Mi lista" con una propuesta corta, para que no arranque vacía (no se fija).
      listas = ListasFavoritos.inicial(cartelera!);
      await prefs.setString(claveListas, listas.comoTexto());
    }
    listaActivaId = listas.fijada; // con una lista fijada, la app abre directo en esa lista
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
