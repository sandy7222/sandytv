import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sandytv/modelos/en_vivo.dart';
import 'package:sandytv/servicios/estado_app.dart';
import 'package:sandytv/servicios/repositorio_cartelera.dart';
import 'package:sandytv/ui/pantalla_en_vivo.dart';
import 'package:sandytv/ui/pantalla_inicio.dart';

import 'cartelera_test.dart' show canalJson;

String catalogo({List<Map<String, dynamic>>? canales, int formato = 1}) => jsonEncode({
      'formato': formato,
      'version': 'v1',
      'grupos': [
        {'id': 'noticias', 'nombre': 'Noticias'},
        {'id': 'deportes', 'nombre': 'Deportes'},
        {'id': 'musica', 'nombre': 'Música'},
      ],
      'canales': canales ??
          [
            {'id': 'a', 'titulo': 'Canal Uno Noticias', 'url': 'https://www.youtube.com/@CanalUno/live', 'grupo': 'noticias', 'portada': null},
            {'id': 'b', 'titulo': 'Canal Dos Noticias', 'url': 'https://www.youtube.com/@CanalDos/live', 'grupo': 'noticias', 'portada': 'https://i.ytimg.com/x.jpg'},
            {'id': 'c', 'titulo': 'Deportes en vivo', 'url': 'https://www.youtube.com/@Deportes/live', 'grupo': 'deportes', 'portada': null},
          ],
    });

void main() {
  group('catálogo en vivo', () {
    test('lee canales y grupos', () {
      final c = CatalogoEnVivo.tryParse(catalogo())!;
      expect(c.canales.length, 3);
      expect(c.canales.first.titulo, 'Canal Uno Noticias');
      expect(c.canales.first.url, 'https://www.youtube.com/@CanalUno/live');
      expect(c.delGrupo('noticias').map((x) => x.id), ['a', 'b']);
    });

    test('los grupos sin canales no se muestran', () {
      final c = CatalogoEnVivo.tryParse(catalogo())!;
      expect(c.gruposConCanales.map((g) => g.id), ['noticias', 'deportes']);
    });

    test('sin canales, JSON roto o de otro formato devuelve null', () {
      expect(CatalogoEnVivo.tryParse(catalogo(canales: [])), isNull);
      expect(CatalogoEnVivo.tryParse('basura'), isNull);
      expect(CatalogoEnVivo.tryParse(catalogo(formato: 9)), isNull);
    });

    test('un canal sin título o sin dirección de YouTube se ignora', () {
      final c = CatalogoEnVivo.tryParse(catalogo(canales: [
        {'id': 'ok', 'titulo': 'Bueno', 'url': 'https://www.youtube.com/@Bueno/live', 'grupo': 'noticias'},
        {'id': 'sin-url', 'titulo': 'Sin dirección', 'grupo': 'noticias'},
        {'id': 'otra-web', 'titulo': 'Otra web', 'url': 'https://ejemplo.com/video', 'grupo': 'noticias'},
        {'id': 'sin-titulo', 'url': 'https://www.youtube.com/@X/live', 'grupo': 'noticias'},
      ]))!;
      expect(c.canales.map((x) => x.id), ['ok']);
    });

    test('un grupo desconocido va a "Otros"', () {
      final c = CatalogoEnVivo.tryParse(catalogo(canales: [
        {'id': 'x', 'titulo': 'Raro', 'url': 'https://www.youtube.com/@Raro/live', 'grupo': 'inventado'},
      ]))!;
      expect(c.gruposConCanales.single.nombre, 'Otros');
    });
  });

  group('sección En vivo', () {
    Future<EstadoApp> crear({String? enVivo, Future<bool> Function(String)? abrir}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = RepositorioCartelera(
        almacen: AlmacenPrefs(prefs),
        url: Uri.parse('https://x/c.json'),
        descargar: (_) async => throw Exception('sin internet'),
        cargarInicial: () async => jsonEncode({
          'formato': 1,
          'version': 't',
          'categorias': [
            {'id': 'argentina', 'nombre': 'Argentina (aire)', 'orden': 1}
          ],
          'canales': [canalJson('A.ar', 1)],
        }),
      );
      final e = EstadoApp(
        repo: repo,
        prefs: prefs,
        actualizacionAutomatica: false,
        cargarEnVivo: enVivo == null ? null : () async => enVivo,
        abrirVideo: abrir ?? (_) async => true,
      );
      await e.iniciar();
      return e;
    }

    testWidgets('muestra una fila por grupo con el título de cada canal', (t) async {
      final e = await crear(enVivo: catalogo());
      await t.pumpWidget(MaterialApp(home: PantallaEnVivo(estado: e)));
      await t.pump();
      expect(find.text('Noticias'), findsOneWidget);
      expect(find.text('Deportes'), findsOneWidget);
      expect(find.text('Música'), findsNothing);
      expect(find.text('Canal Uno Noticias'), findsOneWidget);
    });

    testWidgets('elegir un canal abre su transmisión en vivo en YouTube', (t) async {
      final abiertas = <String>[];
      final e = await crear(enVivo: catalogo(), abrir: (u) async {
        abiertas.add(u);
        return true;
      });
      await t.pumpWidget(MaterialApp(home: PantallaEnVivo(estado: e)));
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.select); // OK del control: el primer canal tiene el foco
      await t.pump();
      expect(abiertas, ['https://www.youtube.com/@CanalUno/live']);
    });

    testWidgets('si no se puede abrir YouTube, avisa', (t) async {
      final e = await crear(enVivo: catalogo(), abrir: (_) async => false);
      await t.pumpWidget(MaterialApp(home: PantallaEnVivo(estado: e)));
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.select);
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('No se pudo abrir YouTube'), findsOneWidget);
    });

    testWidgets('el Inicio siempre tiene el botón En vivo (para poder agregar el primer canal)', (t) async {
      final sin = await crear();
      await t.pumpWidget(MaterialApp(home: PantallaInicio(estado: sin)));
      await t.pump();
      expect(find.textContaining('En vivo'), findsOneWidget);
    });

    testWidgets('sin canales, la pantalla invita a agregar uno', (t) async {
    t.view.physicalSize = const Size(1280, 720); // pantalla de televisor
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
      final e = await crear();
      await t.pumpWidget(MaterialApp(home: PantallaEnVivo(estado: e)));
      await t.pump();
      expect(find.textContaining('Todavía no cargaste ningún canal'), findsOneWidget);
      expect(find.text('＋ Agregar canal'), findsOneWidget);
    });

    testWidgets('el editor agrega un canal con su título y la dirección del vivo, y queda guardado', (t) async {
    t.view.physicalSize = const Size(1280, 720); // pantalla de televisor
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
      final e = await crear();
      await t.pumpWidget(MaterialApp(home: PantallaEnVivo(estado: e)));
      await t.pump();
      await t.tap(find.text('＋ Agregar canal'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Título del canal'), 'Mi canal de noticias');
      await t.enterText(find.widgetWithText(TextField, 'Dirección del vivo de YouTube'), 'youtube.com/@MiCanal');
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      expect(find.text('Mi canal de noticias'), findsOneWidget);
      expect(e.enVivo.canales.single.url, 'https://www.youtube.com/@MiCanal/live', reason: 'se completa /live solo');
      // queda guardado en el aparato
      final guardado = e.prefs.getString(EstadoApp.claveEnVivoPropios)!;
      expect(guardado, contains('MiCanal'));
    });

    testWidgets('una dirección que no es de YouTube no se guarda y avisa', (t) async {
    t.view.physicalSize = const Size(1280, 720); // pantalla de televisor
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
      final e = await crear();
      await t.pumpWidget(MaterialApp(home: PantallaEnVivo(estado: e)));
      await t.pump();
      await t.tap(find.text('＋ Agregar canal'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Título del canal'), 'Algo');
      await t.enterText(find.widgetWithText(TextField, 'Dirección del vivo de YouTube'), 'https://ejemplo.com/video');
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      expect(find.textContaining('no es una dirección de YouTube'), findsOneWidget);
      expect(e.enVivo.canales, isEmpty);
    });

    testWidgets('los canales agregados sobreviven al reiniciar la app', (t) async {
      final e = await crear();
      e.agregarEnVivo(titulo: 'Guardado', url: 'https://www.youtube.com/@G/live', grupo: 'noticias');
      await e.cambioEnVivo();
      final texto = e.prefs.getString(EstadoApp.claveEnVivoPropios);
      SharedPreferences.setMockInitialValues({EstadoApp.claveEnVivoPropios: texto!});
      final prefs = await SharedPreferences.getInstance();
      final repo = RepositorioCartelera(
        almacen: AlmacenPrefs(prefs),
        url: Uri.parse('https://x/c.json'),
        descargar: (_) async => throw Exception('x'),
        cargarInicial: () async => jsonEncode({
          'formato': 1,
          'version': 't',
          'categorias': [
            {'id': 'argentina', 'nombre': 'Argentina (aire)', 'orden': 1}
          ],
          'canales': [canalJson('A.ar', 1)],
        }),
      );
      final otro = EstadoApp(repo: repo, prefs: prefs, actualizacionAutomatica: false);
      await otro.iniciar();
      expect(otro.enVivo.canales.map((c) => c.titulo), ['Guardado']);
    });

    testWidgets('en modo Editar se puede cambiar el título y borrar un canal propio', (t) async {
    t.view.physicalSize = const Size(1280, 720); // pantalla de televisor
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
      final e = await crear();
      e.agregarEnVivo(titulo: 'Para cambiar', url: 'https://www.youtube.com/@P/live', grupo: 'noticias');
      await e.cambioEnVivo();
      await t.pumpWidget(MaterialApp(home: PantallaEnVivo(estado: e)));
      await t.pump();
      await t.tap(find.text('✎ Editar'));
      await t.pump();
      await t.tap(find.text('Para cambiar'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cambiar el título'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Ya cambiado');
      await t.tap(find.text('Aceptar'));
      await t.pumpAndSettle();
      expect(find.text('Ya cambiado'), findsOneWidget);
      await t.tap(find.text('Ya cambiado'));
      await t.pumpAndSettle();
      await t.tap(find.text('Borrar el canal'));
      await t.pumpAndSettle();
      await t.tap(find.text('Borrar'));
      await t.pumpAndSettle();
      expect(e.enVivo.canales, isEmpty);
    });
  });

  group('direcciones de YouTube', () {
    test('un canal con @ o /channel/ pasa a su transmisión en vivo', () {
      expect(normalizarUrlYoutube('youtube.com/@MiCanal'), 'https://www.youtube.com/@MiCanal/live');
      expect(normalizarUrlYoutube('https://www.youtube.com/@MiCanal/'), 'https://www.youtube.com/@MiCanal/live');
      expect(normalizarUrlYoutube('https://www.youtube.com/channel/UC123abc'), 'https://www.youtube.com/channel/UC123abc/live');
    });

    test('una dirección que ya es de un video o del vivo se respeta', () {
      expect(normalizarUrlYoutube('https://www.youtube.com/@MiCanal/live'), 'https://www.youtube.com/@MiCanal/live');
      expect(normalizarUrlYoutube('https://www.youtube.com/watch?v=abc123'), 'https://www.youtube.com/watch?v=abc123');
      expect(normalizarUrlYoutube('https://youtu.be/abc123'), 'https://youtu.be/abc123');
    });

    test('sin https se lo agrega y http pasa a https', () {
      expect(normalizarUrlYoutube('http://youtube.com/watch?v=abc'), 'https://www.youtube.com/watch?v=abc');
    });

    test('lo que no es de YouTube o está vacío devuelve null', () {
      expect(normalizarUrlYoutube('https://ejemplo.com/@MiCanal'), isNull);
      expect(normalizarUrlYoutube('   '), isNull);
      expect(normalizarUrlYoutube('hola'), isNull);
    });
  });
}
