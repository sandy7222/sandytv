import test from 'node:test';
import assert from 'node:assert/strict';
import { grupoDe, prepararCandidatos } from '../lib/filtros.mjs';

const config = {
  paises: ['AR', 'UY', 'MX'],
  paisesExcluidos: ['ES'],
  idioma: 'spa',
  categoriasExcluidas: ['xxx', 'shop'],
  etiquetasExcluidas: ['Not 24/7']
};

const canal = (id, pais, categorias = ['general'], extra = {}) =>
  ({ id, name: id, country: pais, categories: categorias, is_nsfw: false, closed: null, network: null, owners: [], website: null, ...extra });
const stream = (channel, url, extra = {}) =>
  ({ channel, feed: null, title: channel, url, quality: '720p', labels: [], user_agent: null, referrer: null, ...extra });
const feed = (channel, languages = ['spa']) => ({ channel, id: 'SD', is_main: true, languages });

test('grupoDe: noticias y deportes ganan sobre el país', () => {
  assert.equal(grupoDe({ pais: 'AR', categorias: ['news'] }), 'noticias');
  assert.equal(grupoDe({ pais: 'AR', categorias: ['general', 'sports'] }), 'deportes');
});

test('grupoDe: cine, documentales, infantiles y música', () => {
  assert.equal(grupoDe({ pais: 'MX', categorias: ['movies'] }), 'cine');
  assert.equal(grupoDe({ pais: 'MX', categorias: ['series'] }), 'cine');
  assert.equal(grupoDe({ pais: 'MX', categorias: ['documentary'] }), 'documentales');
  assert.equal(grupoDe({ pais: 'MX', categorias: ['science'] }), 'documentales');
  assert.equal(grupoDe({ pais: 'MX', categorias: ['kids'] }), 'infantiles');
  assert.equal(grupoDe({ pais: 'MX', categorias: ['music'] }), 'musica');
});

test('grupoDe: general de Argentina va a argentina y el de otro país a latinoamerica', () => {
  assert.equal(grupoDe({ pais: 'AR', categorias: ['general'] }), 'argentina');
  assert.equal(grupoDe({ pais: 'UY', categorias: ['general'] }), 'latinoamerica');
});

test('grupoDe: respeta el grupo forzado a mano', () => {
  assert.equal(grupoDe({ pais: 'AR', categorias: ['news'] }, 'argentina'), 'argentina');
});

test('grupoDe: sin categoría ni país conocido va a otros', () => {
  assert.equal(grupoDe({ pais: 'XX', categorias: [] }), 'otros');
});

test('prepararCandidatos deja canales latinos con enlace y descarta España', () => {
  const r = prepararCandidatos({
    channels: [canal('Telefe.ar', 'AR'), canal('La1.es', 'ES')],
    streams: [stream('Telefe.ar', 'http://a/1.m3u8'), stream('La1.es', 'http://a/2.m3u8')],
    feeds: [feed('Telefe.ar'), feed('La1.es')],
    config, mis: {}
  });
  assert.deepEqual(r.map(c => c.id), ['Telefe.ar']);
});

test('prepararCandidatos descarta países fuera de la lista, cerrados, nsfw y categorías excluidas', () => {
  const r = prepararCandidatos({
    channels: [
      canal('Fuera.br', 'BR'),
      canal('Cerrado.ar', 'AR', ['general'], { closed: '2020-01-01' }),
      canal('Nsfw.ar', 'AR', ['general'], { is_nsfw: true }),
      canal('Xxx.ar', 'AR', ['xxx']),
      canal('Tienda.ar', 'AR', ['shop']),
      canal('Bien.ar', 'AR')
    ],
    streams: ['Fuera.br', 'Cerrado.ar', 'Nsfw.ar', 'Xxx.ar', 'Tienda.ar', 'Bien.ar'].map(c => stream(c, `http://a/${c}.m3u8`)),
    feeds: [], config, mis: {}
  });
  assert.deepEqual(r.map(c => c.id), ['Bien.ar']);
});

test('prepararCandidatos exige español cuando el canal declara idiomas', () => {
  const r = prepararCandidatos({
    channels: [canal('Ingles.mx', 'MX'), canal('Espanol.mx', 'MX'), canal('SinDato.mx', 'MX')],
    streams: ['Ingles.mx', 'Espanol.mx', 'SinDato.mx'].map(c => stream(c, `http://a/${c}.m3u8`)),
    feeds: [feed('Ingles.mx', ['eng']), feed('Espanol.mx', ['spa', 'eng'])],
    config, mis: {}
  });
  assert.deepEqual(r.map(c => c.id).sort(), ['Espanol.mx', 'SinDato.mx']);
});

test('prepararCandidatos ignora canales sin enlace y enlaces marcados como no 24/7', () => {
  const r = prepararCandidatos({
    channels: [canal('SinEnlace.ar', 'AR'), canal('Intermitente.ar', 'AR'), canal('Ok.ar', 'AR')],
    streams: [
      stream('Intermitente.ar', 'http://a/x.m3u8', { labels: ['Not 24/7'] }),
      stream('Ok.ar', 'http://a/ok.m3u8'),
      stream(null, 'http://a/huerfano.m3u8')
    ],
    feeds: [], config, mis: {}
  });
  assert.deepEqual(r.map(c => c.id), ['Ok.ar']);
});

test('prepararCandidatos junta varios enlaces de un canal, sin repetir direcciones', () => {
  const r = prepararCandidatos({
    channels: [canal('Doble.ar', 'AR')],
    streams: [stream('Doble.ar', 'http://a/1.m3u8'), stream('Doble.ar', 'http://a/1.m3u8'), stream('Doble.ar', 'http://a/2.m3u8', { quality: '1080p' })],
    feeds: [], config, mis: {}
  });
  assert.equal(r[0].streams.length, 2);
  assert.equal(r[0].streams[0].calidadDeclarada, '1080p');
});

test('prepararCandidatos guarda emisora, web y cabeceras del enlace', () => {
  const r = prepararCandidatos({
    channels: [canal('AmericaTV.ar', 'AR', ['general'], { network: 'Grupo America', website: 'https://x.com' })],
    streams: [stream('AmericaTV.ar', 'http://a/1.m3u8', { user_agent: 'UA', referrer: 'https://ref' })],
    feeds: [], config, mis: {}
  });
  assert.equal(r[0].emisora, 'Grupo America');
  assert.equal(r[0].web, 'https://x.com');
  assert.equal(r[0].streams[0].userAgent, 'UA');
  assert.equal(r[0].streams[0].referrer, 'https://ref');
});

test('mis canales: excluir, forzar, grupo y agregar', () => {
  const r = prepararCandidatos({
    channels: [canal('Uno.ar', 'AR'), canal('Dos.ar', 'AR', ['news']), canal('Tres.ar', 'AR')],
    streams: ['Uno.ar', 'Dos.ar', 'Tres.ar'].map(c => stream(c, `http://a/${c}.m3u8`)),
    feeds: [], config,
    mis: {
      excluir: ['Uno.ar'],
      forzar: ['Dos.ar'],
      grupo: { 'Dos.ar': 'argentina' },
      agregar: [{ id: 'Propio.ar', nombre: 'Propio', pais: 'AR', grupo: 'argentina', enlaces: ['http://a/propio.m3u8'] }]
    }
  });
  const ids = r.map(c => c.id).sort();
  assert.deepEqual(ids, ['Dos.ar', 'Propio.ar', 'Tres.ar']);
  const dos = r.find(c => c.id === 'Dos.ar');
  assert.equal(dos.forzar, true);
  assert.equal(dos.grupo, 'argentina');
  assert.equal(r.find(c => c.id === 'Propio.ar').streams[0].url, 'http://a/propio.m3u8');
});
