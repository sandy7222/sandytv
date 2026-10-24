import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sandytv/logica/listas_favoritos.dart';
import 'package:sandytv/logica/teclas.dart';
import 'package:sandytv/servicios/estado_app.dart';
import 'package:sandytv/servicios/repositorio_cartelera.dart';
import 'package:sandytv/ui/pantalla_canal.dart';
import 'package:sandytv/ui/pantalla_inicio.dart';

import 'cambio_de_canal_test.dart' show MotorDePrueba, urlA, urlB, urlC;
import 'cartelera_test.dart' show canalJson;

final _cartelera = jsonEncode({
  'formato': 1,
  'version': 'test',
  'categorias': [
    {'id': 'argentina', 'nombre': 'Argentina (aire)', 'orden': 1},
    {'id': 'noticias', 'nombre': 'Noticias', 'orden': 2},
  ],
  'canales': [
    canalJson('A.ar', 1),
    canalJson('B.ar', 2),
    canalJson('C.ar', 3),
    canalJson('N.ar', 4, categoria: 'noticias'),
  ],
});

Future<EstadoApp> crear([Map<String, Object> previas = const {}]) async {
  SharedPreferences.setMockInitialValues(previas);
  final prefs = await SharedPreferences.getInstance();
  final repo = RepositorioCartelera(
    almacen: AlmacenPrefs(prefs),
    url: Uri.parse('https://x/c.json'),
    descargar: (_) async => throw Exception('sin internet'),
    cargarInicial: () async => _cartelera,
  );
  final e = EstadoApp(repo: repo, prefs: prefs, actualizacionAutomatica: false);
  await e.iniciar();
  return e;
}

String listasGuardadas({String? fijada}) {
  final l = ListasFavoritos();
  final f = l.crear('Familia');
  l.agregar(f.id, 'C.ar');
  l.agregar(f.id, 'A.ar');
  l.crear('Fútbol');
  l.fijar(fijada == null ? null : f.id);
  return l.comoTexto();
}

void main() {
  test('la primera vez se crea "Mi lista" sola, sin fijar: la app abre como siempre', () async {
    final e = await crear();
    expect(e.listas.listas.single.titulo, 'Mi lista');
    expect(e.listaActivaId, isNull);
    expect(e.canalesActivos.length, 4, reason: 'sin lista activa se ven todos los canales');
  });

  test('con una lista fijada, la app abre ya en esa lista', () async {
    final e = await crear({EstadoApp.claveListas: listasGuardadas(fijada: 'si')});
    expect(e.listaActivaId, 'familia');
    expect(e.listaActiva!.titulo, 'Familia');
    expect(e.canalesActivos.map((c) => c.id), ['C.ar', 'A.ar']);
  });

  test('sin fijar, abre en todos los canales aunque haya listas', () async {
    final e = await crear({EstadoApp.claveListas: listasGuardadas()});
    expect(e.listaActivaId, isNull);
  });

  test('en una lista, los números son la posición dentro de la lista', () async {
    final e = await crear({EstadoApp.claveListas: listasGuardadas(fijada: 'si')});
    expect(e.numeroVisible(e.cartelera!.canalPorId('C.ar')!), 1);
    expect(e.numeroVisible(e.cartelera!.canalPorId('A.ar')!), 2);
    expect(e.canalPorNumeroActivo(2)!.id, 'A.ar');
    expect(e.canalPorNumeroActivo(3), isNull);
  });

  test('sin lista activa, los números son los de la cartelera', () async {
    final e = await crear();
    expect(e.numeroVisible(e.cartelera!.canalPorId('N.ar')!), 4);
    expect(e.canalPorNumeroActivo(4)!.id, 'N.ar');
  });

  test('cambiar de lista activa no cambia la fijada', () async {
    final e = await crear({EstadoApp.claveListas: listasGuardadas(fijada: 'si')});
    e.activarLista(null);
    expect(e.listaActivaId, isNull);
    expect(e.listas.fijada, 'familia');
  });

  test('si la lista activa se borra, se vuelve a todos los canales', () async {
    final e = await crear({EstadoApp.claveListas: listasGuardadas(fijada: 'si')});
    await e.borrarLista('familia');
    expect(e.listaActivaId, isNull);
    expect(e.listas.porId('familia'), isNull);
  });

  test('los cambios en las listas se guardan en el aparato', () async {
    final e = await crear();
    final nueva = e.crearLista('Noticias');
    await e.cambioEnListas();
    e.listas.agregar(nueva.id, 'N.ar');
    await e.fijarLista(nueva.id);
    final otra = ListasFavoritos.desdeTexto(e.prefs.getString(EstadoApp.claveListas));
    expect(otra.porId(nueva.id)!.canales, ['N.ar']);
    expect(otra.fijada, nueva.id);
  });

  test('la tecla verde agrega o quita el canal de una lista', () {
    expect(mapearTecla(LogicalKeyboardKey.colorF1Green).accion, Accion.favorito);
    expect(mapearTecla(LogicalKeyboardKey.guide).accion, Accion.guia);
  });

  testWidgets('el Inicio con una lista fijada muestra el título de la lista y sus canales, no las categorías', (t) async {
    final e = await crear({EstadoApp.claveListas: listasGuardadas(fijada: 'si')});
    await t.pumpWidget(MaterialApp(home: PantallaInicio(estado: e)));
    await t.pump();
    expect(find.text('Familia'), findsWidgets);
    expect(find.text('Noticias'), findsNothing, reason: 'las categorías no se muestran en una lista sin agrupar');
    expect(find.text('Argentina (aire)'), findsNothing);
    expect(find.text('C.ar'), findsWidgets);
    expect(find.text('B.ar'), findsNothing, reason: 'B.ar no está en la lista');
  });

  testWidgets('el Inicio sin lista activa muestra las categorías como siempre', (t) async {
    t.view.physicalSize = const Size(1280, 720); // pantalla de televisor
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final e = await crear();
    await t.pumpWidget(MaterialApp(home: PantallaInicio(estado: e)));
    await t.pump();
    expect(find.text('Argentina (aire)'), findsOneWidget);
    expect(find.text('Noticias'), findsOneWidget);
  });

  testWidgets('una lista agrupada muestra una fila por categoría, solo con sus canales', (t) async {
    final e = await crear({EstadoApp.claveListas: listasGuardadas(fijada: 'si')});
    e.listas.porId('familia')!.agrupar = true;
    e.listas.agregar('familia', 'N.ar');
    await t.pumpWidget(MaterialApp(home: PantallaInicio(estado: e)));
    await t.pump();
    expect(find.text('Argentina (aire)'), findsOneWidget);
    expect(find.text('Noticias'), findsOneWidget);
    expect(find.text('B.ar'), findsNothing);
  });

  testWidgets('en el canal, ↑ y ↓ cambian dentro de la lista activa y la barra muestra la posición', (t) async {
    final e = await crear({EstadoApp.claveListas: listasGuardadas(fijada: 'si')});
    final motor = MotorDePrueba({
      urlA: (Duration.zero, true),
      urlB: (Duration.zero, true),
      urlC: (Duration.zero, true),
    });
    await t.pumpWidget(MaterialApp(
      home: PantallaCanal(
        estado: e,
        canalInicial: e.canalesActivos.first, // C.ar, primero de la lista
        crearMotor: () => motor,
        timeoutApertura: const Duration(seconds: 5),
      ),
    ));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('1  C.ar'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('2  A.ar'), findsOneWidget, reason: 'pasa al siguiente DE LA LISTA (salta B.ar)');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('1  C.ar'), findsOneWidget, reason: 'del último vuelve al primero de la lista');
    await t.pump(const Duration(seconds: 6));
  });

  testWidgets('en el canal, la tecla verde permite agregar el canal a una lista', (t) async {
    final e = await crear({EstadoApp.claveListas: listasGuardadas()});
    final motor = MotorDePrueba({urlB: (Duration.zero, true)});
    await t.pumpWidget(MaterialApp(
      home: PantallaCanal(
        estado: e,
        canalInicial: e.cartelera!.canalPorId('B.ar')!,
        crearMotor: () => motor,
        timeoutApertura: const Duration(seconds: 5),
      ),
    ));
    await t.pump(const Duration(milliseconds: 100));
    await t.sendKeyEvent(LogicalKeyboardKey.f5); // F5 = botón verde en el teclado de la PC (el verde no se puede simular)
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Agregar B.ar a una lista'), findsOneWidget);
    expect(e.listas.contiene('familia', 'B.ar'), isFalse);
    await t.tap(find.text('Familia'));
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(e.listas.contiene('familia', 'B.ar'), isTrue);
    await t.tap(find.text('Familia'));
    await t.pumpAndSettle(const Duration(milliseconds: 100));
    expect(e.listas.contiene('familia', 'B.ar'), isFalse, reason: 'tocar de nuevo lo quita');
    await t.pump(const Duration(seconds: 6));
  });
}
