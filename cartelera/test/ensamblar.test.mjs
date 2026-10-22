import test from 'node:test';
import assert from 'node:assert/strict';
import { ensamblar, elegirLogo } from '../lib/ensamblar.mjs';

const config = {
  calidad: { minAlto: 480, maxMsRespuesta: 8000, minRatio: 1.5 },
  prueba: { maxEnlacesPorCanal: 2 },
  grupos: [{ id: 'argentina', nombre: 'Argentina (aire)' }, { id: 'noticias', nombre: 'Noticias' }, { id: 'otros', nombre: 'Otros' }]
};

const cand = (id, grupo, pruebas, extra = {}) => ({
  id, nombre: id, pais: 'AR', categorias: [], emisora: null, web: null, grupo, forzar: false,
  streams: pruebas.map(p => ({ url: p.url, calidadDeclarada: p.declarada || null, userAgent: null, referrer: null })),
  pruebas: pruebas.map(p => p.resultado),
  ...extra
});
const ok = (alto, ratio = 3, msRespuesta = 500) => ({ ok: true, alto, kbps: 2000, ratio, msRespuesta });
const caido = { ok: false, motivo: 'respuesta 404' };

const paises = [{ code: 'AR', name: 'Argentina' }];

test('ensamblar ordena los enlaces por puntaje y se queda con los mejores', () => {
  const { cartelera } = ensamblar({
    candidatos: [cand('A.ar', 'argentina', [
      { url: 'u480', resultado: ok(480) }, { url: 'u1080', resultado: ok(1080) }, { url: 'u720', resultado: ok(720) }
    ])],
    logos: [], paises, numerosPrevios: {}, config, version: 'v1'
  });
  const enlaces = cartelera.canales[0].enlaces;
  assert.deepEqual(enlaces.map(e => e.url), ['u1080', 'u720']);
  assert.ok(enlaces[0].puntaje > enlaces[1].puntaje);
});

test('ensamblar descarta enlaces caídos o de mala calidad y los canales que quedan sin enlace', () => {
  const { cartelera, informe } = ensamblar({
    candidatos: [
      cand('Bueno.ar', 'argentina', [{ url: 'a', resultado: ok(720) }]),
      cand('Caido.ar', 'argentina', [{ url: 'b', resultado: caido }]),
      cand('Feo.ar', 'argentina', [{ url: 'c', resultado: ok(360) }])
    ],
    logos: [], paises, numerosPrevios: {}, config, version: 'v1'
  });
  assert.deepEqual(cartelera.canales.map(c => c.id), ['Bueno.ar']);
  assert.equal(informe.descartados.length, 2);
  assert.match(informe.descartados.find(d => d.id === 'Caido.ar').motivo, /404/);
});

test('ensamblar mantiene un canal forzado aunque falle la prueba', () => {
  const { cartelera } = ensamblar({
    candidatos: [cand('Forzado.ar', 'argentina', [{ url: 'x', declarada: '720p', resultado: caido }], { forzar: true })],
    logos: [], paises, numerosPrevios: {}, config, version: 'v1'
  });
  assert.equal(cartelera.canales.length, 1);
  assert.equal(cartelera.canales[0].enlaces[0].puntaje, 0);
  assert.equal(cartelera.canales[0].enlaces[0].alto, 720);
});

test('ensamblar numera por grupo y nombre, y conserva los números previos', () => {
  const candidatos = [
    cand('Z.ar', 'argentina', [{ url: 'z', resultado: ok(720) }]),
    cand('N.ar', 'noticias', [{ url: 'n', resultado: ok(720) }]),
    cand('A.ar', 'argentina', [{ url: 'a', resultado: ok(720) }])
  ];
  const primera = ensamblar({ candidatos, logos: [], paises, numerosPrevios: {}, config, version: 'v1' });
  assert.deepEqual(primera.cartelera.canales.map(c => [c.id, c.numero]), [['A.ar', 1], ['Z.ar', 2], ['N.ar', 3]]);
  const segunda = ensamblar({
    candidatos: [...candidatos, cand('B.ar', 'argentina', [{ url: 'b', resultado: ok(720) }])],
    logos: [], paises, numerosPrevios: primera.cartelera.numeros, config, version: 'v2'
  });
  assert.equal(segunda.cartelera.canales.find(c => c.id === 'B.ar').numero, 4);
  assert.equal(segunda.cartelera.canales.find(c => c.id === 'Z.ar').numero, 2);
});

test('ensamblar completa grupo, país y logo, y deja null lo que no se sabe', () => {
  const { cartelera } = ensamblar({
    candidatos: [cand('A.ar', 'argentina', [{ url: 'a', resultado: ok(720) }])],
    logos: [{ channel: 'A.ar', in_use: true, width: 100, height: 100, url: 'https://logo/a.png' }],
    paises, numerosPrevios: {}, config, version: 'v1'
  });
  const c = cartelera.canales[0];
  assert.equal(c.categoria, 'argentina');
  assert.equal(c.paisNombre, 'Argentina');
  assert.equal(c.logo, 'https://logo/a.png');
  assert.equal(c.emisora, null);
  assert.equal(cartelera.formato, 1);
  assert.equal(cartelera.version, 'v1');
  assert.deepEqual(cartelera.categorias.map(g => g.id), ['argentina', 'noticias', 'otros']);
});

test('elegirLogo prefiere los que están en uso y los más grandes', () => {
  const logos = [
    { channel: 'X', in_use: false, width: 1000, height: 1000, url: 'grande-sin-uso' },
    { channel: 'X', in_use: true, width: 50, height: 50, url: 'chico' },
    { channel: 'X', in_use: true, width: 300, height: 300, url: 'mediano' },
    { channel: 'Y', in_use: true, width: 900, height: 900, url: 'otro-canal' }
  ];
  assert.equal(elegirLogo(logos, 'X'), 'mediano');
  assert.equal(elegirLogo(logos, 'Z'), null);
});
