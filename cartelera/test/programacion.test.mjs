import test from 'node:test';
import assert from 'node:assert/strict';
import { parsearSubidas, leerDatosVideo, construirGrilla } from '../lib/programacion.mjs';

const HTML_SUBIDAS = `...{"lockupViewModel":{"contentId":"AAAAAAAAAAA","contentType":"LOCKUP_CONTENT_TYPE_VIDEO"}}...
 {"lockupViewModel":{"contentId":"BBBBBBBBBBB"}} {"contentId":"AAAAAAAAAAA"} {"contentId":"CCCCCCCCCCC"} "contentId":"corto"`;

test('parsearSubidas: ids en orden, sin repetir, hasta el máximo', () => {
  assert.deepEqual(parsearSubidas(HTML_SUBIDAS), ['AAAAAAAAAAA', 'BBBBBBBBBBB', 'CCCCCCCCCCC']);
  assert.deepEqual(parsearSubidas(HTML_SUBIDAS, 2), ['AAAAAAAAAAA', 'BBBBBBBBBBB']);
  assert.deepEqual(parsearSubidas('sin nada'), []);
});

const pagina = ({ seg = '2100', emb = 'true', estado = 'OK', extra = '' } = {}) =>
  `..."playabilityStatus":{"status":"${estado}"}...,"playableInEmbed":${emb},..."videoDetails":{"videoId":"X","title":"Dorados \u0026 m\u00e1s","lengthSeconds":"${seg}"${extra}}...`;

test('leerDatosVideo: duración y si se puede reproducir incrustado', () => {
  assert.deepEqual(leerDatosVideo(pagina()), { ok: true, dur: 2100, titulo: 'Dorados & más' });
  assert.equal(leerDatosVideo(pagina({ emb: 'false' })).ok, false);
  assert.equal(leerDatosVideo(pagina({ estado: 'UNPLAYABLE' })).ok, false);
  assert.equal(leerDatosVideo(pagina({ extra: ',"isLive":true' })).ok, false, 'un vivo no entra a la grilla');
  assert.equal(leerDatosVideo(pagina({ extra: ',"isUpcoming":true' })).ok, false);
  assert.equal(leerDatosVideo('no es una página de video').ok, false);
});

const cand = (id, creador, publicado, dur = 1800) => ({ id, titulo: id, creador, publicado, dur });
const HORA = 3600;

test('la grilla cubre todo el horizonte sin huecos ni solapamientos', () => {
  const cs = ['a', 'b', 'c', 'd', 'e', 'f'].map((x, i) => cand(x, 'C' + (i % 3), 1000 + i, 1800));
  const { programas } = construirGrilla({ anterior: [], candidatos: cs, ahora: 10000, horas: 24 });
  assert.equal(programas[0].i, 10000);
  for (let k = 1; k < programas.length; k++) assert.equal(programas[k].i, programas[k - 1].i + programas[k - 1].d);
  const ultimo = programas[programas.length - 1];
  assert.ok(ultimo.i < 10000 + 24 * HORA && ultimo.i + ultimo.d >= 10000 + 24 * HORA - 1800);
});

test('rota: no repite un video hasta haber pasado todos', () => {
  const cs = ['a', 'b', 'c', 'd'].map((x, i) => cand(x, 'C' + i, 100 + i));
  const { programas } = construirGrilla({ anterior: [], candidatos: cs, ahora: 0, horas: 3 }); // 6 programas de media hora
  const ids = programas.map(p => p.v);
  assert.equal(new Set(ids.slice(0, 4)).size, 4);
});

test('los videos nuevos pasan primero entre los que todavía no salieron', () => {
  const cs = [cand('viejo', 'X', 100), cand('nuevo', 'Y', 900), cand('medio', 'Z', 500)];
  const { programas } = construirGrilla({ anterior: [], candidatos: cs, ahora: 0, horas: 1.5 });
  assert.deepEqual(programas.map(p => p.v), ['nuevo', 'medio', 'viejo']);
});

test('evita dos videos seguidos del mismo creador si hay de otro', () => {
  const cs = [cand('a1', 'A', 900), cand('a2', 'A', 800), cand('b1', 'B', 100)];
  const { programas } = construirGrilla({ anterior: [], candidatos: cs, ahora: 0, horas: 1.5 });
  assert.deepEqual(programas.map(p => p.v), ['a1', 'b1', 'a2']);
});

test('lo que ya está en marcha o por venir no se mueve cuando se renueva la grilla', () => {
  const cs = ['a', 'b', 'c', 'd'].map((x, i) => cand(x, 'C' + i, 100 + i));
  const primera = construirGrilla({ anterior: [], candidatos: cs, ahora: 0, horas: 4 });
  // pasan 40 minutos: el primer programa terminó, el segundo está en marcha; aparece un video nuevo
  const ahora2 = 2400;
  const nuevos = [...cs, cand('zzz', 'N', 5000)];
  const segunda = construirGrilla({ anterior: primera.programas, candidatos: nuevos, ahora: ahora2, horas: 4, historial: primera.historial });
  const previos = primera.programas.filter(p => p.i + p.d > ahora2);
  assert.deepEqual(segunda.programas.slice(0, previos.length), previos, 'el programa en marcha y los que siguen quedan igual');
  assert.ok(segunda.programas.slice(previos.length).some(p => p.v === 'zzz'), 'el video nuevo entra al final de la cola');
  assert.ok(segunda.programas.every(p => p.i + p.d > ahora2), 'los programas ya terminados se sacan');
});

test('sin videos candidatos no inventa programas', () => {
  const { programas } = construirGrilla({ anterior: [], candidatos: [], ahora: 0, horas: 24 });
  assert.deepEqual(programas, []);
});

test('si la grilla vieja quedó toda en el pasado, arranca desde ahora', () => {
  const cs = [cand('a', 'A', 1), cand('b', 'B', 2)];
  const vieja = [{ v: 'a', t: 'a', c: 'A', i: 0, d: 1800 }];
  const { programas } = construirGrilla({ anterior: vieja, candidatos: cs, ahora: 100000, horas: 1 });
  assert.equal(programas[0].i, 100000);
});
