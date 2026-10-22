import test from 'node:test';
import assert from 'node:assert/strict';
import { altoDeCalidad, puntuar, cumpleMinimos } from '../lib/puntaje.mjs';

const calidad = { minAlto: 480, maxMsRespuesta: 8000, minRatio: 1.5 };

test('altoDeCalidad lee la etiqueta de iptv-org', () => {
  assert.equal(altoDeCalidad('1080p'), 1080);
  assert.equal(altoDeCalidad('720i'), 720);
  assert.equal(altoDeCalidad(''), null);
  assert.equal(altoDeCalidad(null), null);
  assert.equal(altoDeCalidad('hd'), null);
});

test('puntuar: más resolución, más velocidad y menos demora dan más puntos', () => {
  const mejor = puntuar({ alto: 1080, ratio: 4, msRespuesta: 500 });
  const medio = puntuar({ alto: 720, ratio: 2, msRespuesta: 2000 });
  const peor = puntuar({ alto: 480, ratio: 1.5, msRespuesta: 7000 });
  assert.ok(mejor > medio && medio > peor);
  assert.equal(mejor, 100);
});

test('puntuar: resolución desconocida vale menos que 720p pero más que nada', () => {
  const desconocida = puntuar({ alto: null, ratio: 3, msRespuesta: 1000 });
  assert.ok(desconocida < puntuar({ alto: 720, ratio: 3, msRespuesta: 1000 }));
  assert.ok(desconocida > 0);
});

test('cumpleMinimos acepta lo que llega a los mínimos', () => {
  assert.equal(cumpleMinimos({ alto: 480, ratio: 1.5, msRespuesta: 8000 }, calidad), true);
  assert.equal(cumpleMinimos({ alto: null, ratio: 2, msRespuesta: 1000 }, calidad), true);
});

test('cumpleMinimos rechaza baja resolución, lentitud o demora', () => {
  assert.equal(cumpleMinimos({ alto: 360, ratio: 3, msRespuesta: 500 }, calidad), false);
  assert.equal(cumpleMinimos({ alto: 720, ratio: 1.2, msRespuesta: 500 }, calidad), false);
  assert.equal(cumpleMinimos({ alto: 720, ratio: 3, msRespuesta: 9000 }, calidad), false);
});
