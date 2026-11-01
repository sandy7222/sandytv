// Arma salida/programacion.json: la grilla de un canal propio hecho con los videos más nuevos de los creadores de YouTube
// que el dueño sigue. Uso: node armar_programacion.mjs [--config canal_pesca.json] [--salida salida] [--sin-previa]
// Sin claves ni cuentas: usa el feed público de cada canal y la página de cada video (duración y si se puede incrustar).
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parsearSubidas, leerDatosVideo, construirGrilla } from './lib/programacion.mjs';
import { conLimite } from './lib/pool.mjs';

const aca = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const opcion = (n, defecto) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : defecto; };
const configRuta = path.resolve(aca, opcion('--config', 'canal_pesca.json'));
const salida = path.resolve(aca, opcion('--salida', 'salida'));
const sinPrevia = args.includes('--sin-previa');

const config = JSON.parse(await readFile(configRuta, 'utf8'));
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36';
const ahora = Math.floor(Date.now() / 1000);

if (!config.creadores?.length) { console.error('canal_pesca.json no tiene creadores todavía.'); process.exit(2); }

async function bajarTexto(url, ms = 25000) {
  const r = await fetch(url, { redirect: 'follow', signal: AbortSignal.timeout(ms), headers: { 'user-agent': UA, 'accept-language': 'es-AR,es;q=0.9', cookie: 'CONSENT=YES+1; SOCS=CAI' } });
  if (!r.ok) throw new Error('respuesta ' + r.status);
  return r.text();
}

// Lo publicado la vez anterior: la grilla ya armada (para no mover lo que está en marcha) y lo ya averiguado de cada video
let previo = null;
if (!sinPrevia && config.urlPublicada) {
  try { const r = await fetch(config.urlPublicada, { signal: AbortSignal.timeout(30000) }); if (r.ok) previo = await r.json(); } catch { /* primera vez */ }
}
const cache = { ...(previo?.videos || {}) };

console.log(`Siguiendo ${config.creadores.length} creadores…`);
const vistos = new Map();
// De cada creador, los videos más nuevos de su lista de "subidas" (UULF…: sin shorts ni vivos), del más nuevo al más viejo
const subidas = await conLimite(config.creadores, 4, async c => {
  try { return { c, ids: parsearSubidas(await bajarTexto(`https://www.youtube.com/playlist?list=UULF${c.canal.slice(2)}`), config.videosPorCreador ?? 15) }; }
  catch (e) { console.error(`  ✗ ${c.nombre}: ${e.message}`); return { c, ids: [] }; }
});
for (const { c, ids } of subidas) {
  console.log(`  ${c.nombre}: ${ids.length} videos`);
  ids.forEach((id, rank) => { if (!vistos.has(id)) vistos.set(id, { id, creador: c.nombre, publicado: ahora - rank * 86400 }); });
}

const nuevos = [...vistos.keys()].filter(id => !cache[id]);
console.log(`Videos a revisar: ${nuevos.length} (el resto ya estaba averiguado)`);
await conLimite(nuevos, 6, async id => {
  try { cache[id] = leerDatosVideo(await bajarTexto(`https://www.youtube.com/watch?v=${id}`)); }
  catch (e) { /* sin dato: se reintenta la próxima vez */ }
});

const minSeg = (config.minMinutos ?? 8) * 60, maxSeg = (config.maxMinutos ?? 180) * 60;
const candidatos = [...vistos.values()]
  .filter(v => cache[v.id]?.ok && cache[v.id].dur >= minSeg && cache[v.id].dur <= maxSeg)
  .map(v => ({ ...v, titulo: cache[v.id].titulo || v.id, dur: cache[v.id].dur }));
console.log(`Candidatos reproducibles: ${candidatos.length} de ${vistos.size}`);

// Protección: sin candidatos no se publica una grilla vacía (queda la anterior)
if (!candidatos.length) { console.error('No quedó ningún video reproducible; no se escribe nada.'); process.exit(2); }

const { programas, historial } = construirGrilla({ anterior: previo?.programas || [], candidatos, ahora, horas: config.horas ?? 48, historial: previo?.historial || {} });
// Para que la caché no crezca sin fin: solo se guardan los videos que siguen en los feeds
const videos = Object.fromEntries([...vistos.keys()].filter(id => cache[id]).map(id => [id, cache[id]]));
const resultado = {
  formato: 'sandytv-programacion-1',
  generado: new Date(ahora * 1000).toISOString(),
  canal: { id: config.id, nombre: config.nombre },
  programas, historial, videos
};
await mkdir(salida, { recursive: true });
await writeFile(path.join(salida, 'programacion.json'), JSON.stringify(resultado));
const horasCubiertas = programas.length ? ((programas[programas.length - 1].i + programas[programas.length - 1].d - ahora) / 3600).toFixed(1) : 0;
console.log(`Grilla: ${programas.length} programas, ${horasCubiertas} h por delante.`);
