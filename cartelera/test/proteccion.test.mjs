import test from 'node:test';
import assert from 'node:assert/strict';
import { debePublicar } from '../lib/proteccion.mjs';

test('la primera vez publica si hay canales', () => {
  assert.equal(debePublicar(null, { canales: [{}] }).publicar, true);
});

test('no publica una cartelera vacía', () => {
  assert.equal(debePublicar(null, { canales: [] }).publicar, false);
});

test('publica si la nueva tiene al menos la mitad de canales que la anterior', () => {
  const ant = { canales: new Array(100).fill({}) };
  assert.equal(debePublicar(ant, { canales: new Array(50).fill({}) }, 0.5).publicar, true);
});

test('no publica si la nueva perdió más de la mitad y explica por qué', () => {
  const ant = { canales: new Array(100).fill({}) };
  const r = debePublicar(ant, { canales: new Array(49).fill({}) }, 0.5);
  assert.equal(r.publicar, false);
  assert.match(r.motivo, /49/);
});
