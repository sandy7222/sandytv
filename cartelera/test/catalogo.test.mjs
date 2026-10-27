import test from 'node:test';
import assert from 'node:assert/strict';
import { armarCatalogo } from '../lib/catalogo.mjs';

const paises = [{ code: 'AR', name: 'Argentina' }, { code: 'UY', name: 'Uruguay' }, { code: 'US', name: 'United States' }];
const canal = (id, extra = {}) => ({ id, name: id, country: 'AR', categories: ['news'], is_nsfw: false, closed: null, ...extra });
const flujo = (channel, url, extra = {}) => ({ channel, url, quality: '720p', referrer: null, user_agent: null, ...extra });

test('incluye solo canales con un enlace https directo', () => {
  const r = armarCatalogo({
    channels: [canal('A.ar'), canal('B.ar'), canal('C.ar')],
    streams: [flujo('A.ar', 'https://x/a.m3u8'), flujo('B.ar', 'http://x/b.m3u8'), flujo('Z.ar', 'https://x/z.m3u8')],
    countries: paises,
  });
  assert.deepEqual(r.canales.map(c => c[0]), ['A.ar']);
});

test('descarta enlaces que piden referrer o user-agent (el navegador no los puede mandar)', () => {
  const r = armarCatalogo({
    channels: [canal('A.ar'), canal('B.ar')],
    streams: [flujo('A.ar', 'https://x/a.m3u8', { referrer: 'https://sitio' }), flujo('B.ar', 'https://x/b.m3u8', { user_agent: 'raro' })],
    countries: paises,
  });
  assert.equal(r.canales.length, 0);
});

test('saca los cerrados, los de adultos y la categoría xxx', () => {
  const r = armarCatalogo({
    channels: [canal('A.ar', { closed: '2020-01-01' }), canal('B.ar', { is_nsfw: true }), canal('C.ar', { categories: ['xxx'] }), canal('D.ar')],
    streams: ['A.ar', 'B.ar', 'C.ar', 'D.ar'].map(id => flujo(id, `https://x/${id}.m3u8`)),
    countries: paises,
  });
  assert.deepEqual(r.canales.map(c => c[0]), ['D.ar']);
});

test('elige el enlace de mejor calidad sin pasarse de 1080p', () => {
  const r = armarCatalogo({
    channels: [canal('A.ar')],
    streams: [flujo('A.ar', 'https://x/480.m3u8', { quality: '480p' }), flujo('A.ar', 'https://x/2160.m3u8', { quality: '2160p' }), flujo('A.ar', 'https://x/1080.m3u8', { quality: '1080p' })],
    countries: paises,
  });
  assert.equal(r.canales[0][4], 'https://x/1080.m3u8');
});

test('formato compacto: id, nombre, país, categoría, enlace, calidad; y lista solo los países usados', () => {
  const r = armarCatalogo({
    channels: [canal('B.uy', { name: 'Beta', country: 'UY' }), canal('A.ar', { name: 'Alfa' })],
    streams: [flujo('B.uy', 'https://x/b.m3u8'), flujo('A.ar', 'https://x/a.m3u8')],
    countries: paises,
  });
  assert.deepEqual(r.canales[0], ['A.ar', 'Alfa', 'AR', 'news', 'https://x/a.m3u8', '720p']); // ordenado por nombre
  assert.deepEqual(r.paises, { AR: 'Argentina', UY: 'Uruguay' });
  assert.equal(r.formato, 'sandytv-catalogo-1');
});

test('un canal sin categoría ni calidad no rompe nada', () => {
  const r = armarCatalogo({
    channels: [canal('A.ar', { categories: [] })],
    streams: [flujo('A.ar', 'https://x/a.m3u8', { quality: null })],
    countries: paises,
  });
  assert.deepEqual(r.canales[0].slice(3), ['', 'https://x/a.m3u8', '']);
});
