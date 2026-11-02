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

const SPOT = { id: 'el-guia', nombre: 'El Guía YA', archivo: 'spots/el-guia.mp4', dur: 30, cada: 3 };

test('auspicio: se intercala un spot cada N videos y no cambia los horarios de lo demás', () => {
  const cs = ['a', 'b', 'c', 'd', 'e', 'f', 'g'].map((x, i) => cand(x, 'C' + i, 100 + i));
  const { programas } = construirGrilla({ anterior: [], candidatos: cs, ahora: 0, horas: 6, auspicios: [SPOT] });
  const tipos = programas.map(p => (p.a ? 'S' : 'V')).join('');
  assert.ok(tipos.startsWith('VVVSVVVS'), tipos);
  const s = programas.find(p => p.a);
  assert.equal(s.a, 'spots/el-guia.mp4'); assert.equal(s.d, 30); assert.equal(s.c, 'Publicidad');
  assert.match(s.t, /auspiciado/i);
  for (let k = 1; k < programas.length; k++) assert.equal(programas[k].i, programas[k - 1].i + programas[k - 1].d, 'sin huecos');
});

test('auspicio: al renovar la grilla sigue la cuenta y no pone dos spots seguidos', () => {
  const cs = ['a', 'b', 'c', 'd', 'e', 'f'].map((x, i) => cand(x, 'C' + i, 100 + i));
  const p1 = construirGrilla({ anterior: [], candidatos: cs, ahora: 0, horas: 3, auspicios: [SPOT] });
  const p2 = construirGrilla({ anterior: p1.programas, candidatos: cs, ahora: 2000, horas: 8, historial: p1.historial, auspicios: [SPOT] });
  const t = p2.programas.map(p => (p.a ? 'S' : 'V')).join('');
  assert.ok(!t.includes('SS'), t);
  const entre = t.split('S').slice(1, -1).map(x => x.length);
  assert.ok(entre.length >= 1 && entre.every(n => n === 3), t);
});

test('sin auspicios la grilla es la de siempre', () => {
  const cs = ['a', 'b'].map((x, i) => cand(x, 'C' + i, i));
  const { programas } = construirGrilla({ anterior: [], candidatos: cs, ahora: 0, horas: 3 });
  assert.ok(programas.every(p => !p.a));
});

import { duracionISO, datosDesdeApi } from '../lib/programacion.mjs';

test('duracionISO: PT#H#M#S a segundos', () => {
  assert.equal(duracionISO('PT35M12S'), 2112);
  assert.equal(duracionISO('PT1H2M3S'), 3723);
  assert.equal(duracionISO('PT45S'), 45);
  assert.equal(duracionISO('P0D'), 0);
  assert.equal(duracionISO(undefined), 0);
});

const itemApi = (o = {}) => ({ id: 'AAAAAAAAAAA', snippet: { title: 'Pique de dorados', liveBroadcastContent: 'none' }, contentDetails: { duration: 'PT33M' }, status: { embeddable: true, privacyStatus: 'public', uploadStatus: 'processed' }, ...o });

test('datosDesdeApi: reproducible incrustado, público y no vivo', () => {
  assert.deepEqual(datosDesdeApi(itemApi()), { ok: true, dur: 1980, titulo: 'Pique de dorados' });
  assert.equal(datosDesdeApi(itemApi({ status: { embeddable: false, privacyStatus: 'public' } })).ok, false);
  assert.equal(datosDesdeApi(itemApi({ status: { embeddable: true, privacyStatus: 'private' } })).ok, false);
  assert.equal(datosDesdeApi(itemApi({ snippet: { title: 'x', liveBroadcastContent: 'live' } })).ok, false);
  assert.equal(datosDesdeApi(itemApi({ snippet: { title: 'x', liveBroadcastContent: 'upcoming' } })).ok, false);
  assert.equal(datosDesdeApi(itemApi({ contentDetails: { duration: 'P0D' } })).ok, false);
  assert.equal(datosDesdeApi(null).ok, false);
});

test('construirGrilla: guarda la fecha real de publicación (f) y no inventa una cuando no se sabe', () => {
  const cs = [
    { id: 'a', titulo: 'A', creador: 'X', dur: 1800, publicado: 1700000000, fechaReal: true },
    { id: 'b', titulo: 'B', creador: 'Y', dur: 1800, publicado: 1700000500 }
  ];
  const { programas } = construirGrilla({ anterior: [], candidatos: cs, ahora: 0, horas: 1 });
  const a = programas.find(p => p.v === 'a'), b = programas.find(p => p.v === 'b');
  assert.equal(a.f, 1700000000);
  assert.equal(b.f, undefined);
});
