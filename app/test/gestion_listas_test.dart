import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sandytv/servicios/estado_app.dart';
import 'package:sandytv/servicios/repositorio_cartelera.dart';
import 'package:sandytv/ui/pantalla_editar_lista.dart';
import 'package:sandytv/ui/pantalla_listas.dart';

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
    canalJson('N.ar', 3, categoria: 'noticias'),
  ],
});

Future<EstadoApp> crear() async {
  SharedPreferences.setMockInitialValues({});
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

void main() {
  testWidgets('Mis listas muestra las listas con su título y cantidad de canales', (t) async {
    final e = await crear();
    e.listas.renombrar('mi-lista', 'Familia');
    await t.pumpWidget(MaterialApp(home: PantallaListas(estado: e)));
    await t.pump();
    expect(find.text('Familia'), findsOneWidget);
    expect(find.text('Nueva lista'), findsOneWidget);
    expect(find.textContaining('2 canales'), findsOneWidget, reason: 'la lista inicial propone los de Argentina (A y B), no el de noticias');
  });

  testWidgets('desde las opciones de una lista se puede fijar como lista de inicio', (t) async {
    final e = await crear();
    await t.pumpWidget(MaterialApp(home: PantallaListas(estado: e)));
    await t.pump();
    await t.tap(find.text('Mi lista'));
    await t.pumpAndSettle();
    expect(e.listas.fijada, isNull);
    await t.tap(find.text('Abrir la app siempre con esta lista'));
    await t.pumpAndSettle();
    expect(e.listas.fijada, 'mi-lista');
    expect(find.textContaining('se abre al iniciar'), findsOneWidget);
  });

  testWidgets('"Ver esta lista" activa la lista y vuelve atrás', (t) async {
    final e = await crear();
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PantallaListas(estado: e))),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.tap(find.text('Mi lista'));
    await t.pumpAndSettle();
    await t.tap(find.text('Ver esta lista'));
    await t.pumpAndSettle();
    expect(e.listaActivaId, 'mi-lista');
    expect(find.text('abrir'), findsOneWidget, reason: 'volvió a la pantalla anterior');
  });

  testWidgets('Editar lista: se tildan y destildan canales recorriendo las categorías', (t) async {
    final e = await crear();
    e.listas.quitar('mi-lista', 'A.ar');
    e.listas.quitar('mi-lista', 'B.ar');
    e.listas.quitar('mi-lista', 'N.ar');
    await t.pumpWidget(MaterialApp(home: PantallaEditarLista(estado: e, listaId: 'mi-lista')));
    await t.pump();
    expect(find.text('Argentina (aire)'), findsOneWidget);
    expect(find.text('Noticias'), findsOneWidget);
    await t.tap(find.text('N.ar'));
    await t.pump();
    expect(e.listas.contiene('mi-lista', 'N.ar'), isTrue);
    await t.tap(find.text('N.ar'));
    await t.pump();
    expect(e.listas.contiene('mi-lista', 'N.ar'), isFalse);
  });

  testWidgets('Editar lista: el buscador filtra por nombre', (t) async {
    final e = await crear();
    await t.pumpWidget(MaterialApp(home: PantallaEditarLista(estado: e, listaId: 'mi-lista')));
    await t.pump();
    await t.enterText(find.byType(TextField), 'n.ar');
    await t.pump();
    expect(find.text('N.ar'), findsOneWidget);
    expect(find.text('A.ar'), findsNothing);
    expect(find.text('Argentina (aire)'), findsNothing, reason: 'una categoría sin resultados no se muestra');
  });

  testWidgets('Editar lista: en Ordenar se mueven y se quitan canales', (t) async {
    final e = await crear();
    final antes = List<String>.from(e.listas.porId('mi-lista')!.canales);
    await t.pumpWidget(MaterialApp(home: PantallaEditarLista(estado: e, listaId: 'mi-lista')));
    await t.pump();
    await t.tap(find.text('Ordenar'));
    await t.pump();
    // bajar el primero
    await t.tap(find.byTooltip('Bajar').first);
    await t.pump();
    final despues = e.listas.porId('mi-lista')!.canales;
    expect(despues[0], antes[1]);
    expect(despues[1], antes[0]);
    // quitar el primero
    await t.tap(find.byTooltip('Quitar').first);
    await t.pump();
    expect(e.listas.porId('mi-lista')!.canales.length, antes.length - 1);
  });
}
