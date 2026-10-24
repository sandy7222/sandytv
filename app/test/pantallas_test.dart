import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sandytv/servicios/estado_app.dart';
import 'package:sandytv/servicios/repositorio_cartelera.dart';
import 'package:sandytv/ui/pantalla_ajustes.dart';
import 'package:sandytv/ui/pantalla_canal.dart';
import 'package:sandytv/ui/pantalla_inicio.dart';
import 'package:sandytv/ui/pantalla_presentacion.dart';
import 'package:video_player/video_player.dart';

import 'cartelera_test.dart' show canalJson;
import 'dart:convert';

String cartelera() => jsonEncode({
      'formato': 1,
      'version': 'test',
      'categorias': [
        {'id': 'argentina', 'nombre': 'Argentina (aire)', 'orden': 1},
        {'id': 'noticias', 'nombre': 'Noticias', 'orden': 2},
        {'id': 'deportes', 'nombre': 'Deportes', 'orden': 3},
      ],
      'canales': [canalJson('Telefe.ar', 1), canalJson('TN.ar', 2, categoria: 'noticias')],
    });

Future<EstadoApp> crearEstado() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = RepositorioCartelera(
    almacen: AlmacenPrefs(prefs),
    url: Uri.parse('https://x/c.json'),
    descargar: (_) async => throw Exception('sin internet'),
    cargarInicial: () async => cartelera(),
  );
  final estado = EstadoApp(repo: repo, prefs: prefs, actualizacionAutomatica: false);
  await estado.iniciar();
  return estado;
}

void main() {
  testWidgets('el Inicio muestra la cartelera de SandyTV y no tiene reproductor', (t) async {
    t.view.physicalSize = const Size(1280, 720); // pantalla de televisor
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final estado = await crearEstado();
    await t.pumpWidget(MaterialApp(home: PantallaInicio(estado: estado)));
    await t.pump();
    expect(find.text('Sandy'), findsOneWidget);
    expect(find.text('▶  Ver ahora'), findsOneWidget);
    expect(find.text('Argentina (aire)'), findsOneWidget);
    expect(find.text('Noticias'), findsOneWidget);
    expect(find.text('Deportes'), findsNothing, reason: 'los grupos sin canales no se muestran');
    expect(find.byType(VideoPlayer), findsNothing);
  });

  testWidgets('elegir un canal abre la pantalla del canal', (t) async {
    final estado = await crearEstado();
    await t.pumpWidget(MaterialApp(home: PantallaInicio(estado: estado)));
    await t.pump();
    await t.tap(find.text('▶  Ver ahora'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('1 · Telefe.ar'), findsOneWidget);
    expect(find.text('▶  Ver ahora'), findsNothing, reason: 'se abrió la pantalla del canal');
    expect(estado.ultimoCanalId, isNull, reason: 'solo se recuerda un canal que llegó a arrancar');
  });

  testWidgets('si el canal no anda avisa en vez de quedar en negro', (t) async {
    final estado = await crearEstado();
    await t.pumpWidget(MaterialApp(home: PantallaCanal(estado: estado, canalInicial: estado.cartelera!.canales.first, timeoutApertura: const Duration(milliseconds: 100))));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Este canal no está disponible ahora'), findsOneWidget);
    expect(find.byType(VideoPlayer), findsNothing);
  });

  testWidgets('en el canal, ↑ pasa al siguiente y las teclas de volumen no se interceptan', (t) async {
    final estado = await crearEstado();
    await t.pumpWidget(MaterialApp(home: PantallaCanal(estado: estado, canalInicial: estado.cartelera!.canales.first, timeoutApertura: const Duration(milliseconds: 100))));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('1 · Telefe.ar'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('2 · TN.ar'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('1 · Telefe.ar'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.audioVolumeUp);
    await t.pump();
    expect(find.text('1 · Telefe.ar'), findsOneWidget);
  });

  testWidgets('marcar 2 con el control lleva al canal 2', (t) async {
    final estado = await crearEstado();
    await t.pumpWidget(MaterialApp(home: PantallaCanal(estado: estado, canalInicial: estado.cartelera!.canales.first, timeoutApertura: const Duration(milliseconds: 100))));
    await t.pump(const Duration(seconds: 1));
    await t.sendKeyEvent(LogicalKeyboardKey.digit2);
    await t.pump();
    expect(find.text('2'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    expect(find.text('2 · TN.ar'), findsOneWidget);
  });

  testWidgets('la pantalla de prueba de teclas no deja atrapado: Atrás vuelve a Ajustes', (t) async {
    final estado = await crearEstado();
    await t.pumpWidget(MaterialApp(home: PantallaAjustes(estado: estado)));
    await t.pump();
    await t.scrollUntilVisible(find.text('Probar las teclas del control'), 200);
    await t.tap(find.text('Probar las teclas del control'));
    await t.pumpAndSettle();
    expect(find.textContaining('Apretá una tecla'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.digit5);
    await t.pump();
    expect(find.textContaining('Tecla: 5'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.textContaining('Apretá una tecla'), findsNothing);
  });

  testWidgets('cuando un canal no abre se muestra el motivo', (t) async {
    final estado = await crearEstado();
    await t.pumpWidget(MaterialApp(home: PantallaCanal(estado: estado, canalInicial: estado.cartelera!.canales.first, timeoutApertura: const Duration(milliseconds: 100))));
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('a: '), findsWidgets, reason: 'el detalle empieza con el servidor del enlace');
  });

  testWidgets('la presentación lleva al Inicio con la cartelera incluida', (t) async {
    final estado = await crearEstado();
    await t.pumpWidget(MaterialApp(home: PantallaPresentacion(estado: estado)));
    await t.pump(const Duration(milliseconds: 2500));
    await t.pump();
    expect(find.text('Argentina (aire)'), findsOneWidget);
  });
}
