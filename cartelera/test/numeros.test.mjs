import test from 'node:test';
import assert from 'node:assert/strict';
import { asignarNumeros } from '../lib/numeros.mjs';

test('sin números previos, numera desde 1 en el orden dado', () => {
  assert.deepEqual(asignarNumeros(['A', 'B', 'C'], {}), { A: 1, B: 2, C: 3 });
});

test('los canales que ya tenían número lo conservan aunque cambie el orden', () => {
  const r = asignarNumeros(['C', 'A', 'B'], { A: 1, B: 2, C: 3 });
  assert.deepEqual(r, { A: 1, B: 2, C: 3 });
});

test('un canal nuevo recibe el número siguiente al más alto usado', () => {
  const r = asignarNumeros(['A', 'D', 'B'], { A: 1, B: 2, C: 3 });
  assert.equal(r.D, 4);
});

test('un canal que desaparece conserva su número reservado y no se reutiliza', () => {
  const r = asignarNumeros(['A', 'D'], { A: 1, B: 2 });
  assert.equal(r.B, 2);
  assert.equal(r.D, 3);
});
