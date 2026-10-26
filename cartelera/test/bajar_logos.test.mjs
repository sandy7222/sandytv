import test from 'node:test';
import assert from 'node:assert/strict';
import { nombreArchivo } from '../bajar_logos.mjs';

test('el nombre de archivo del logo es seguro y termina en .png', () => {
  assert.equal(nombreArchivo('5tv.ar'), '5tv.ar.png');
  assert.equal(nombreArchivo('A/B C?.ar'), 'A_B_C_.ar.png');
});
