import 'package:flutter_test/flutter_test.dart';
import 'package:sandytv/modelos/cartelera.dart';
import 'package:sandytv/servicios/repositorio_cartelera.dart';

import 'cartelera_test.dart' show carteleraJson;

class AlmacenFalso implements Almacen {
  final datos = <String, String>{};
  @override
  Future<String?> leer(String clave) async => datos[clave];
  @override
  Future<void> escribir(String clave, String valor) async => datos[clave] = valor;
}

void main() {
  late AlmacenFalso almacen;
  setUp(() => almacen = AlmacenFalso());

  RepositorioCartelera repo(Future<String> Function(Uri) descargar, {String? inicial}) => RepositorioCartelera(
        almacen: almacen,
        descargar: descargar,
        url: Uri.parse('https://x/cartelera.json'),
        cargarInicial: inicial == null ? null : () async => inicial,
      );

  test('sin nada guardado ni inicial no hay cartelera', () async {
    expect(await repo((_) async => '').cargarGuardada(), isNull);
  });

  test('usa la última guardada', () async {
    almacen.datos[RepositorioCartelera.claveGuardada] = carteleraJson(version: 'guardada');
    expect((await repo((_) async => '').cargarGuardada())!.version, 'guardada');
  });

  test('si no hay guardada usa la cartelera incluida en la app', () async {
    final c = await repo((_) async => '', inicial: carteleraJson(version: 'incluida')).cargarGuardada();
    expect(c!.version, 'incluida');
  });

  test('si la guardada está rota usa la incluida', () async {
    almacen.datos[RepositorioCartelera.claveGuardada] = 'roto';
    final c = await repo((_) async => '', inicial: carteleraJson(version: 'incluida')).cargarGuardada();
    expect(c!.version, 'incluida');
  });

  test('actualizar: una versión nueva se guarda y se devuelve', () async {
    final actual = Cartelera.tryParse(carteleraJson(version: 'v1'));
    final nueva = await repo((_) async => carteleraJson(version: 'v2')).actualizar(actual);
    expect(nueva!.version, 'v2');
    expect(almacen.datos[RepositorioCartelera.claveGuardada], contains('v2'));
  });

  test('actualizar: la misma versión no cambia nada', () async {
    final actual = Cartelera.tryParse(carteleraJson(version: 'v1'));
    expect(await repo((_) async => carteleraJson(version: 'v1')).actualizar(actual), isNull);
    expect(almacen.datos, isEmpty);
  });

  test('actualizar: una cartelera rota o vacía no pisa la guardada', () async {
    final actual = Cartelera.tryParse(carteleraJson(version: 'v1'));
    almacen.datos[RepositorioCartelera.claveGuardada] = carteleraJson(version: 'v1');
    expect(await repo((_) async => 'basura').actualizar(actual), isNull);
    expect(await repo((_) async => carteleraJson(version: 'v9', canales: [])).actualizar(actual), isNull);
    expect(almacen.datos[RepositorioCartelera.claveGuardada], contains('v1'));
  });

  test('actualizar: si falla la descarga no rompe', () async {
    final actual = Cartelera.tryParse(carteleraJson(version: 'v1'));
    expect(await repo((_) async => throw Exception('sin internet')).actualizar(actual), isNull);
  });
}
