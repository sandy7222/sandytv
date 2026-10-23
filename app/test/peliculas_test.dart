import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sandytv/modelos/peliculas.dart';
import 'package:sandytv/servicios/estado_app.dart';
import 'package:sandytv/servicios/repositorio_cartelera.dart';
import 'package:sandytv/ui/pantalla_inicio.dart';
import 'package:sandytv/ui/pantalla_pelis.dart';

import 'cartelera_test.dart' show canalJson;

String catalogo({List<Map<String, dynamic>>? peliculas, int formato = 1}) => jsonEncode({
      'formato': formato,
      'version': 'v1',
      'generos': [
        {'id': 'accion', 'nombre': 'Acción'},
        {'id': 'terror', 'nombre': 'Terror'},
        {'id': 'drama', 'nombre': 'Drama'},
      ],
      'peliculas': peliculas ??
          [
            {'id': 'AAA', 'titulo': 'Punto de control', 'canal': 'Canal X', 'genero': 'accion', 'portada': 'https://i.ytimg.com/vi/AAA/mqdefault.jpg', 'duracionMin': 97},
            {'id': 'BBB', 'titulo': 'El devorador de huesos', 'canal': 'Canal X', 'genero': 'terror', 'portada': 'https://i.ytimg.com/vi/BBB/mqdefault.jpg', 'duracionMin': null},
            {'id': 'CCC', 'titulo': 'Pterodáctilo', 'canal': 'Canal X', 'genero': 'accion', 'portada': null, 'duracionMin': 91},
          ],
    });

void main() {
  group('catálogo de películas', () {
    test('lee películas y géneros', () {
      final c = CatalogoPeliculas.tryParse(catalogo())!;
      expect(c.peliculas.length, 3);
      expect(c.peliculas.first.titulo, 'Punto de control');
      expect(c.peliculas.first.duracionMin, 97);
      expect(c.delGenero('accion').map((p) => p.id), ['AAA', 'CCC']);
    });

    test('los géneros sin películas no se muestran', () {
      final c = CatalogoPeliculas.tryParse(catalogo())!;
      expect(c.generosConPeliculas.map((g) => g.id), ['accion', 'terror']);
    });

    test('la dirección de cada película es la de YouTube', () {
      final c = CatalogoPeliculas.tryParse(catalogo())!;
      expect(c.peliculas.first.urlYoutube, 'https://www.youtube.com/watch?v=AAA');
    });

    test('JSON roto, vacío o de otro formato devuelve null', () {
      expect(CatalogoPeliculas.tryParse('basura'), isNull);
      expect(CatalogoPeliculas.tryParse(catalogo(peliculas: [])), isNull);
      expect(CatalogoPeliculas.tryParse(catalogo(formato: 9)), isNull);
    });

    test('una película mal formada se ignora y no tira abajo el catálogo', () {
      final c = CatalogoPeliculas.tryParse(catalogo(peliculas: [
        {'id': 'AAA', 'titulo': 'Buena', 'canal': 'X', 'genero': 'accion', 'portada': null, 'duracionMin': null},
        {'titulo': 'Sin id'},
        {'id': 'ZZZ'},
      ]))!;
      expect(c.peliculas.map((p) => p.id), ['AAA']);
    });

    test('una película con género desconocido va a "Otras"', () {
      final c = CatalogoPeliculas.tryParse(catalogo(peliculas: [
        {'id': 'AAA', 'titulo': 'Rara', 'canal': 'X', 'genero': 'inventado', 'portada': null, 'duracionMin': null},
      ]))!;
      expect(c.generosConPeliculas.single.nombre, 'Otras');
      expect(c.delGenero('otras').single.id, 'AAA');
    });
  });

  group('menú de pelis', () {
    Future<EstadoApp> crear({Future<bool> Function(String)? abrir}) async {
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
        cargarPeliculas: () async => catalogo(),
        abrirVideo: abrir ?? (_) async => true,
      );
      await e.iniciar();
      return e;
    }

    testWidgets('muestra una fila por género con los títulos de las películas', (t) async {
      final e = await crear();
      await t.pumpWidget(MaterialApp(home: PantallaPelis(estado: e)));
      await t.pump();
      expect(find.text('Acción'), findsOneWidget);
      expect(find.text('Terror'), findsOneWidget);
      expect(find.text('Drama'), findsNothing);
      expect(find.text('Punto de control'), findsOneWidget);
      expect(find.text('El devorador de huesos'), findsOneWidget);
    });

    testWidgets('elegir una película la abre con el reproductor de YouTube', (t) async {
      final abiertas = <String>[];
      final e = await crear(abrir: (u) async {
        abiertas.add(u);
        return true;
      });
      await t.pumpWidget(MaterialApp(home: PantallaPelis(estado: e)));
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.select); // OK del control: la primera película tiene el foco
      await t.pump();
      expect(abiertas, ['https://www.youtube.com/watch?v=AAA']);
    });

    testWidgets('si no se puede abrir YouTube, avisa', (t) async {
      final e = await crear(abrir: (_) async => false);
      await t.pumpWidget(MaterialApp(home: PantallaPelis(estado: e)));
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.select); // OK del control: la primera película tiene el foco
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('No se pudo abrir YouTube'), findsOneWidget);
    });

    testWidgets('el Inicio tiene el botón Pelis y lleva al menú', (t) async {
      final e = await crear();
      await t.pumpWidget(MaterialApp(home: PantallaInicio(estado: e)));
      await t.pump();
      expect(find.textContaining('Pelis'), findsOneWidget);
      await t.tap(find.textContaining('Pelis'));
      await t.pumpAndSettle();
      expect(find.text('Punto de control'), findsOneWidget);
    });
  });
}
