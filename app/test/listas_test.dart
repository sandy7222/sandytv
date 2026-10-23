import 'package:flutter_test/flutter_test.dart';
import 'package:sandytv/logica/listas_favoritos.dart';
import 'package:sandytv/modelos/cartelera.dart';

import 'cartelera_test.dart' show canalJson, carteleraJson;

Cartelera cartelera() => Cartelera.tryParse(carteleraJson(canales: [
      canalJson('A.ar', 1, enlaces: [
        {'url': 'http://a/A', 'alto': 720, 'kbps': null, 'puntaje': 50, 'userAgent': null, 'referrer': null}
      ]),
      canalJson('B.ar', 2, enlaces: [
        {'url': 'http://a/B', 'alto': 1080, 'kbps': null, 'puntaje': 100, 'userAgent': null, 'referrer': null}
      ]),
      canalJson('C.ar', 3, enlaces: [
        {'url': 'http://a/C', 'alto': 720, 'kbps': null, 'puntaje': 80, 'userAgent': null, 'referrer': null}
      ]),
      canalJson('N.ar', 4, categoria: 'noticias'),
    ]))!;

void main() {
  group('crear, renombrar y borrar', () {
    test('crear una lista le pone el título y un id propio', () {
      final l = ListasFavoritos();
      final a = l.crear('Familia');
      expect(a.titulo, 'Familia');
      expect(l.listas.length, 1);
      expect(l.porId(a.id), same(a));
    });

    test('dos listas con el mismo título tienen ids distintos', () {
      final l = ListasFavoritos();
      final a = l.crear('Fútbol');
      final b = l.crear('Fútbol');
      expect(a.id, isNot(b.id));
    });

    test('un título vacío se reemplaza por uno por defecto', () {
      final l = ListasFavoritos();
      expect(l.crear('   ').titulo, 'Mi lista');
      expect(l.crear('').titulo, 'Lista 2');
    });

    test('renombrar cambia el título y rechaza uno vacío', () {
      final l = ListasFavoritos();
      final a = l.crear('Familia');
      expect(l.renombrar(a.id, '  Noticias  '), isTrue);
      expect(a.titulo, 'Noticias');
      expect(l.renombrar(a.id, '  '), isFalse);
      expect(a.titulo, 'Noticias');
    });

    test('no se puede borrar la última lista', () {
      final l = ListasFavoritos();
      final a = l.crear('Única');
      expect(l.borrar(a.id), isFalse);
      expect(l.listas.length, 1);
    });

    test('borrar una lista fijada quita la fijación', () {
      final l = ListasFavoritos();
      final a = l.crear('A');
      final b = l.crear('B');
      l.fijar(b.id);
      expect(l.borrar(b.id), isTrue);
      expect(l.fijada, isNull);
      expect(l.listas.single, same(a));
    });
  });

  group('canales de una lista', () {
    test('agregar no repite y quitar saca', () {
      final l = ListasFavoritos();
      final a = l.crear('A');
      l.agregar(a.id, 'A.ar');
      l.agregar(a.id, 'A.ar');
      l.agregar(a.id, 'B.ar');
      expect(a.canales, ['A.ar', 'B.ar']);
      l.quitar(a.id, 'A.ar');
      expect(a.canales, ['B.ar']);
      expect(l.contiene(a.id, 'B.ar'), isTrue);
      expect(l.contiene(a.id, 'A.ar'), isFalse);
    });

    test('un mismo canal puede estar en varias listas', () {
      final l = ListasFavoritos();
      final a = l.crear('A');
      final b = l.crear('B');
      l.agregar(a.id, 'A.ar');
      l.agregar(b.id, 'A.ar');
      expect(l.contiene(a.id, 'A.ar') && l.contiene(b.id, 'A.ar'), isTrue);
    });

    test('mover cambia el orden', () {
      final l = ListasFavoritos();
      final a = l.crear('A');
      for (final id in ['A.ar', 'B.ar', 'C.ar']) {
        l.agregar(a.id, id);
      }
      l.mover(a.id, 2, 0);
      expect(a.canales, ['C.ar', 'A.ar', 'B.ar']);
      l.mover(a.id, 0, 99); // fuera de rango: no hace nada raro
      expect(a.canales.length, 3);
    });

    test('resolver devuelve los canales en orden y marca los que ya no están en la cartelera', () {
      final l = ListasFavoritos();
      final a = l.crear('A');
      for (final id in ['B.ar', 'Viejo.ar', 'A.ar']) {
        l.agregar(a.id, id);
      }
      final r = l.resolver(a.id, cartelera());
      expect(r.map((e) => e.id), ['B.ar', 'Viejo.ar', 'A.ar']);
      expect(r[0].canal!.nombre, 'B.ar');
      expect(r[1].canal, isNull, reason: 'canal que ya no está: se muestra atenuado');
    });

    test('canalesDe devuelve solo los canales que existen, en orden', () {
      final l = ListasFavoritos();
      final a = l.crear('A');
      for (final id in ['B.ar', 'Viejo.ar', 'A.ar']) {
        l.agregar(a.id, id);
      }
      expect(l.canalesDe(a.id, cartelera()).map((c) => c.id), ['B.ar', 'A.ar']);
    });
  });

  group('lista fijada y guardado', () {
    test('fijar y desfijar', () {
      final l = ListasFavoritos();
      final a = l.crear('A');
      l.fijar(a.id);
      expect(l.fijada, a.id);
      l.fijar(null);
      expect(l.fijada, isNull);
      l.fijar('no-existe');
      expect(l.fijada, isNull, reason: 'no se puede fijar una lista que no existe');
    });

    test('se guarda y se recupera como texto, con títulos, orden y fijada', () {
      final l = ListasFavoritos();
      final a = l.crear('Familia');
      final b = l.crear('Fútbol');
      l.agregar(a.id, 'B.ar');
      l.agregar(a.id, 'A.ar');
      b.agrupar = true;
      l.fijar(a.id);
      final otra = ListasFavoritos.desdeTexto(l.comoTexto());
      expect(otra.listas.map((x) => x.titulo), ['Familia', 'Fútbol']);
      expect(otra.porId(a.id)!.canales, ['B.ar', 'A.ar']);
      expect(otra.porId(b.id)!.agrupar, isTrue);
      expect(otra.fijada, a.id);
    });

    test('un texto roto o vacío da una colección vacía, sin romper', () {
      expect(ListasFavoritos.desdeTexto('basura').listas, isEmpty);
      expect(ListasFavoritos.desdeTexto(null).listas, isEmpty);
      expect(ListasFavoritos.desdeTexto('{"listas": 5}').listas, isEmpty);
    });

    test('una fijada que no existe en el texto se ignora', () {
      final l = ListasFavoritos.desdeTexto('{"version":1,"fijada":"fantasma","listas":[{"id":"a","titulo":"A","agrupar":false,"canales":[]}]}');
      expect(l.fijada, isNull);
    });
  });

  group('lista inicial', () {
    test('propone "Mi lista" con los mejores canales de Argentina por puntaje, sin fijar', () {
      final l = ListasFavoritos.inicial(cartelera(), max: 2);
      expect(l.listas.single.titulo, 'Mi lista');
      expect(l.listas.single.canales, ['B.ar', 'C.ar']);
      expect(l.fijada, isNull);
    });

    test('si no hay canales de Argentina, usa los mejores de cualquier grupo', () {
      final c = Cartelera.tryParse(carteleraJson(canales: [canalJson('N.ar', 1, categoria: 'noticias')]))!;
      final l = ListasFavoritos.inicial(c);
      expect(l.listas.single.canales, ['N.ar']);
    });
  });

  group('agrupar por categoría', () {
    test('agrupa los canales de la lista según su categoría, respetando el orden dentro de cada una', () {
      final l = ListasFavoritos();
      final a = l.crear('A');
      for (final id in ['N.ar', 'C.ar', 'A.ar']) {
        l.agregar(a.id, id);
      }
      final grupos = l.agruparPorCategoria(a.id, cartelera());
      expect(grupos.map((g) => g.grupo.id), ['argentina', 'noticias']);
      expect(grupos[0].canales.map((c) => c.id), ['C.ar', 'A.ar']);
      expect(grupos[1].canales.map((c) => c.id), ['N.ar']);
    });
  });
}
