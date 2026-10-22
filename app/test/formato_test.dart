import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sandytv/modelos/formato_imagen.dart';
import 'package:sandytv/servicios/estado_app.dart';
import 'package:sandytv/servicios/repositorio_cartelera.dart';

import 'cartelera_test.dart' show carteleraJson;

Future<EstadoApp> crear() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = RepositorioCartelera(
    almacen: AlmacenPrefs(prefs),
    url: Uri.parse('https://x/c.json'),
    descargar: (_) async => throw Exception('sin internet'),
    cargarInicial: () async => carteleraJson(),
  );
  final e = EstadoApp(repo: repo, prefs: prefs, actualizacionAutomatica: false);
  await e.iniciar();
  return e;
}

void main() {
  test('el formato rota entre original, estirado y zoom y vuelve al principio', () {
    expect(FormatoImagen.original.siguiente, FormatoImagen.estirar);
    expect(FormatoImagen.estirar.siguiente, FormatoImagen.zoom);
    expect(FormatoImagen.zoom.siguiente, FormatoImagen.original);
  });

  test('cada formato tiene un nombre corto para mostrar y se guarda con un código', () {
    for (final f in FormatoImagen.values) {
      expect(f.nombre, isNotEmpty);
      expect(FormatoImagen.desdeCodigo(f.codigo), f);
    }
    expect(FormatoImagen.desdeCodigo('cualquier cosa'), isNull);
    expect(FormatoImagen.desdeCodigo(null), isNull);
  });

  test('sin nada guardado se usa el formato por defecto, que empieza siendo el original', () async {
    final e = await crear();
    expect(e.formatoDe('A.ar'), FormatoImagen.original);
  });

  test('el formato se recuerda por canal y no afecta a los demás', () async {
    final e = await crear();
    await e.guardarFormato('A.ar', FormatoImagen.estirar);
    expect(e.formatoDe('A.ar'), FormatoImagen.estirar);
    expect(e.formatoDe('B.ar'), FormatoImagen.original);
  });

  test('el formato por defecto cambia para los canales que no tienen uno propio', () async {
    final e = await crear();
    await e.cambiarFormatoDefecto(FormatoImagen.zoom);
    expect(e.formatoDe('B.ar'), FormatoImagen.zoom);
    await e.guardarFormato('A.ar', FormatoImagen.original);
    expect(e.formatoDe('A.ar'), FormatoImagen.original, reason: 'el propio del canal gana');
  });
}
