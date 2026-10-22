import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { probarEnlace } from '../lib/probar_enlace.mjs';

function servidor(rutas) {
  const srv = http.createServer((req, res) => {
    const r = rutas[req.url];
    if (!r) { res.statusCode = 404; return res.end('no'); }
    if (r.demora) return setTimeout(() => { res.end(r.cuerpo); }, r.demora);
    res.end(r.cuerpo);
  });
  return new Promise(ok => srv.listen(0, '127.0.0.1', () => ok({ srv, base: `http://127.0.0.1:${srv.address().port}` })));
}

const SEG = Buffer.alloc(20000, 1);

test('un canal con lista simple y segmento que baja rápido sale ok', async () => {
  const { srv, base } = await servidor({
    '/a/index.m3u8': { cuerpo: '#EXTM3U\n#EXTINF:6.0,\nseg1.ts\n' },
    '/a/seg1.ts': { cuerpo: SEG }
  });
  try {
    const r = await probarEnlace(`${base}/a/index.m3u8`, { timeoutMs: 3000 });
    assert.equal(r.ok, true);
    assert.ok(r.ratio > 5, `ratio ${r.ratio}`);
    assert.ok(r.msRespuesta < 3000);
  } finally { srv.close(); }
});

test('con lista maestra elige la mejor variante y devuelve su resolución', async () => {
  const { srv, base } = await servidor({
    '/m.m3u8': { cuerpo: '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=500000,RESOLUTION=640x360\nlow.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720\nmid.m3u8\n' },
    '/mid.m3u8': { cuerpo: '#EXTM3U\n#EXTINF:4.0,\ns.ts\n' },
    '/s.ts': { cuerpo: SEG }
  });
  try {
    const r = await probarEnlace(`${base}/m.m3u8`, { timeoutMs: 3000, maxAlto: 1080 });
    assert.equal(r.ok, true);
    assert.equal(r.alto, 720);
  } finally { srv.close(); }
});

test('una dirección que da 404 sale caída con motivo', async () => {
  const { srv, base } = await servidor({});
  try {
    const r = await probarEnlace(`${base}/nada.m3u8`, { timeoutMs: 2000 });
    assert.equal(r.ok, false);
    assert.match(r.motivo, /404/);
  } finally { srv.close(); }
});

test('algo que no es una lista m3u8 sale caído', async () => {
  const { srv, base } = await servidor({ '/x.m3u8': { cuerpo: '<html>hola</html>' } });
  try {
    const r = await probarEnlace(`${base}/x.m3u8`, { timeoutMs: 2000 });
    assert.equal(r.ok, false);
    assert.match(r.motivo, /m3u8/);
  } finally { srv.close(); }
});

test('si el servidor tarda más que el tiempo máximo sale caído', async () => {
  const { srv, base } = await servidor({ '/lento.m3u8': { cuerpo: '#EXTM3U\n', demora: 1500 } });
  try {
    const r = await probarEnlace(`${base}/lento.m3u8`, { timeoutMs: 300 });
    assert.equal(r.ok, false);
    assert.match(r.motivo, /tiempo/);
  } finally { srv.close(); }
});

test('una lista sin segmentos sale caída', async () => {
  const { srv, base } = await servidor({ '/v.m3u8': { cuerpo: '#EXTM3U\n#EXT-X-TARGETDURATION:6\n' } });
  try {
    const r = await probarEnlace(`${base}/v.m3u8`, { timeoutMs: 2000 });
    assert.equal(r.ok, false);
    assert.match(r.motivo, /segmento/);
  } finally { srv.close(); }
});
