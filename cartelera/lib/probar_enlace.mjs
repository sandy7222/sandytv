// Prueba un enlace HLS: baja la lista, elige la mejor variante, baja UN segmento y mide.
// ratio = cuántas veces más rápido que el tiempo real baja el segmento (>= 1,5 es aceptable).

import { esMaestra, parsearMaestra, elegirVariante, primerSegmento } from './m3u8.mjs';

class Fallo extends Error {}

async function bajar(url, { timeoutMs, userAgent, referrer, binario = false }) {
  const headers = {};
  if (userAgent) headers['User-Agent'] = userAgent;
  if (referrer) headers['Referer'] = referrer;
  try {
    const res = await fetch(url, { headers, signal: AbortSignal.timeout(timeoutMs), redirect: 'follow' });
    if (!res.ok) throw new Fallo(`respuesta ${res.status}`);
    const cuerpo = binario ? (await res.arrayBuffer()).byteLength : await res.text();
    return { cuerpo, urlFinal: res.url || url };
  } catch (e) {
    if (e instanceof Fallo) throw e;
    if (e?.name === 'TimeoutError' || e?.name === 'AbortError') throw new Fallo('se pasó del tiempo máximo');
    throw new Fallo(`no conecta (${e?.cause?.code || e?.message || 'error'})`);
  }
}

export async function probarEnlace(url, { timeoutMs = 8000, maxAlto = 1080, userAgent = null, referrer = null } = {}) {
  const opc = { timeoutMs, userAgent, referrer };
  try {
    const t0 = Date.now();
    const lista = await bajar(url, opc);
    const msRespuesta = Date.now() - t0;
    if (!String(lista.cuerpo).trimStart().startsWith('#EXTM3U')) throw new Fallo('no es una lista m3u8');

    let alto = null;
    let kbps = null;
    let texto = lista.cuerpo;
    let base = lista.urlFinal;

    if (esMaestra(texto)) {
      const variante = elegirVariante(parsearMaestra(texto, base), { maxAlto });
      if (!variante) throw new Fallo('lista maestra sin variantes');
      alto = variante.alto;
      kbps = variante.kbps;
      const sub = await bajar(variante.url, opc);
      if (!String(sub.cuerpo).trimStart().startsWith('#EXTM3U')) throw new Fallo('la variante no es una lista m3u8');
      texto = sub.cuerpo;
      base = sub.urlFinal;
    }

    const segmento = primerSegmento(texto, base);
    if (!segmento) throw new Fallo('sin segmentos de video');

    const t1 = Date.now();
    const bytes = await bajar(segmento.url, { ...opc, binario: true });
    const ms = Math.max(1, Date.now() - t1);
    const ratio = (segmento.duracion * 1000) / ms;

    return { ok: true, alto, kbps: kbps ?? Math.round((bytes.cuerpo * 8) / segmento.duracion / 1000), ratio: Math.round(ratio * 100) / 100, msRespuesta };
  } catch (e) {
    return { ok: false, motivo: e instanceof Fallo ? e.message : `error inesperado (${e?.message})` };
  }
}
