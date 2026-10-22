import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sandytv/modelos/cartelera.dart';

Map<String, dynamic> canalJson(String id, int numero, {String categoria = 'argentina', List<Map<String, dynamic>>? enlaces}) => {
      'id': id,
      'numero': numero,
      'nombre': id,
      'emisora': null,
      'pais': 'AR',
      'paisNombre': 'Argentina',
      'categoria': categoria,
      'logo': null,
      'web': null,
      'forzado': false,
      'enlaces': enlaces ??
          [
            {'url': 'http://a/$id.m3u8', 'alto': 720, 'kbps': 2000, 'puntaje': 90, 'userAgent': null, 'referrer': null}
          ],
    };

String carteleraJson({List<Map<String, dynamic>>? canales, int formato = 1, String version = 'v1'}) => jsonEncode({
      'formato': formato,
      'version': version,
      'categorias': [
        {'id': 'argentina', 'nombre': 'Argentina (aire)', 'orden': 1},
        {'id': 'noticias', 'nombre': 'Noticias', 'orden': 2},
      ],
      'canales': canales ?? [canalJson('A.ar', 1), canalJson('B.ar', 2, categoria: 'noticias')],
      'numeros': {'A.ar': 1, 'B.ar': 2},
    });

void main() {
  test('lee una cartelera válida con sus canales, grupos y enlaces', () {
    final c = Cartelera.tryParse(carteleraJson())!;
    expect(c.version, 'v1');
    expect(c.canales.length, 2);
    expect(c.grupos.map((g) => g.id), ['argentina', 'noticias']);
    expect(c.canales.first.enlaces.first.url, 'http://a/A.ar.m3u8');
    expect(c.canales.first.enlaces.first.alto, 720);
  });

  test('un JSON roto devuelve null', () {
    expect(Cartelera.tryParse('esto no es json'), isNull);
    expect(Cartelera.tryParse('[]'), isNull);
  });

  test('una cartelera sin canales o de otro formato devuelve null', () {
    expect(Cartelera.tryParse(carteleraJson(canales: [])), isNull);
    expect(Cartelera.tryParse(carteleraJson(formato: 2)), isNull);
  });

  test('un canal sin enlaces se ignora y no tira abajo la cartelera', () {
    final c = Cartelera.tryParse(carteleraJson(canales: [canalJson('A.ar', 1), canalJson('Sin.ar', 2, enlaces: [])]))!;
    expect(c.canales.map((x) => x.id), ['A.ar']);
  });

  test('busca canales por id y por número, y agrupa por categoría', () {
    final c = Cartelera.tryParse(carteleraJson())!;
    expect(c.canalPorId('B.ar')!.numero, 2);
    expect(c.canalPorNumero(1)!.id, 'A.ar');
    expect(c.canalPorNumero(99), isNull);
    expect(c.canalesDe('noticias').map((x) => x.id), ['B.ar']);
  });

  test('los grupos sin canales no se muestran', () {
    final c = Cartelera.tryParse(carteleraJson(canales: [canalJson('A.ar', 1)]))!;
    expect(c.gruposConCanales.map((g) => g.id), ['argentina']);
  });
}
