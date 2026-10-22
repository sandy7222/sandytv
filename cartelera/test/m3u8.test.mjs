import test from 'node:test';
import assert from 'node:assert/strict';
import { esMaestra, parsearMaestra, elegirVariante, primerSegmento } from '../lib/m3u8.mjs';

const MAESTRA = `#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
low/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720
https://cdn.example.com/mid/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080
hd/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=15000000,RESOLUTION=3840x2160
uhd/index.m3u8
`;

const MEDIA = `#EXTM3U
#EXT-X-TARGETDURATION:6
#EXTINF:6.000,
seg1.ts
#EXTINF:6.000,
seg2.ts
`;

test('esMaestra distingue lista maestra de lista de segmentos', () => {
  assert.equal(esMaestra(MAESTRA), true);
  assert.equal(esMaestra(MEDIA), false);
});

test('parsearMaestra resuelve las direcciones relativas y lee resolución y velocidad', () => {
  const v = parsearMaestra(MAESTRA, 'https://tv.example.com/canal/master.m3u8');
  assert.equal(v.length, 4);
  assert.deepEqual(v[0], { url: 'https://tv.example.com/canal/low/index.m3u8', ancho: 640, alto: 360, kbps: 800 });
  assert.equal(v[1].url, 'https://cdn.example.com/mid/index.m3u8');
});

test('elegirVariante toma la de mayor resolución que no pase el máximo', () => {
  const v = parsearMaestra(MAESTRA, 'https://tv.example.com/m.m3u8');
  assert.equal(elegirVariante(v, { maxAlto: 1080 }).alto, 1080);
  assert.equal(elegirVariante(v, { maxAlto: 720 }).alto, 720);
});

test('elegirVariante: si todas pasan el máximo, toma la más chica', () => {
  const v = parsearMaestra(MAESTRA, 'https://tv.example.com/m.m3u8');
  assert.equal(elegirVariante(v.slice(2), { maxAlto: 480 }).alto, 1080);
});

test('elegirVariante sin resoluciones declaradas elige la de más velocidad', () => {
  const t = '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1000000\na.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=3000000\nb.m3u8\n';
  const v = parsearMaestra(t, 'https://x.com/m.m3u8');
  assert.equal(elegirVariante(v).url, 'https://x.com/b.m3u8');
});

test('elegirVariante con lista vacía devuelve null', () => {
  assert.equal(elegirVariante([]), null);
});

test('primerSegmento devuelve la dirección absoluta y la duración', () => {
  const s = primerSegmento(MEDIA, 'https://tv.example.com/canal/index.m3u8');
  assert.deepEqual(s, { url: 'https://tv.example.com/canal/seg1.ts', duracion: 6 });
});

test('primerSegmento sin segmentos devuelve null', () => {
  assert.equal(primerSegmento('#EXTM3U\n#EXT-X-TARGETDURATION:6\n', 'https://x.com/a.m3u8'), null);
});
