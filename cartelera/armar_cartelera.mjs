// Arma la cartelera de SandyTV: baja los datos de iptv-org, prueba los enlaces y escribe
// salida/cartelera.json y salida/informe.json.
//
// Uso:  node armar_cartelera.mjs [--max-canales N] [--sin-previa] [--forzar-publicacion]

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { prepararCandidatos } from './lib/filtros.mjs';
import { probarEnlace } from './lib/probar_enlace.mjs';
import { ensamblar } from './lib/ensamblar.mjs';
import { debePublicar } from './lib/proteccion.mjs';
import { conLimite } from './lib/pool.mjs';

const aca = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const opcion = n => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : null; };
const maxCanales = opcion('--max-canales') ? Number(opcion('--max-canales')) : Infinity;
const sinPrevia = args.includes('--sin-previa');
const forzarPublicacion = args.includes('--forzar-publicacion');

const leerJson = async f => JSON.parse(await readFile(path.join(aca, f), 'utf8'));

async function bajarJson(url, intentos = 3) {
  for (let i = 1; i <= intentos; i++) {
    try {
      const res = await fetch(url, { signal: AbortSignal.timeout(120000) });
      if (!res.ok) throw new Error(`respuesta ${res.status}`);
      return await res.json();
    } catch (e) {
      if (i === intentos) throw new Error(`No pude bajar ${url}: ${e.message}`);
      await new Promise(r => setTimeout(r, 2000 * i));
    }
  }
}

async function cartelAnterior(config) {
  if (sinPrevia) return null;
  try {
    const res = await fetch(config.urlPublicada, { signal: AbortSignal.timeout(30000) });
    return res.ok ? await res.json() : null;
  } catch { return null; }
}

const config = await leerJson('config.json');
const mis = await leerJson('mis_canales.json');

console.log('Bajando datos de iptv-org...');
const [channels, streams, feeds, logos, countries] = await Promise.all(
  ['channels', 'streams', 'feeds', 'logos', 'countries'].map(n => bajarJson(`${config.api}/${n}.json`))
);

let candidatos = prepararCandidatos({ channels, streams, feeds, config, mis });
const ordenGrupo = new Map(config.grupos.map((g, i) => [g.id, i]));
candidatos.sort((a, b) => (ordenGrupo.get(a.grupo) ?? 99) - (ordenGrupo.get(b.grupo) ?? 99));
if (Number.isFinite(maxCanales)) candidatos = candidatos.slice(0, maxCanales);

const tareas = [];
for (const c of candidatos) {
  c.streams = c.streams.slice(0, config.prueba.maxEnlacesPorCanalAProbar);
  c.streams.forEach((s, i) => tareas.push({ c, i, s }));
}
console.log(`${candidatos.length} canales candidatos, ${tareas.length} enlaces para probar...`);

for (const c of candidatos) c.pruebas = new Array(c.streams.length);
await conLimite(tareas, config.prueba.concurrencia, async ({ c, i, s }) => {
  c.pruebas[i] = await probarEnlace(s.url, {
    timeoutMs: config.prueba.timeoutMs, maxAlto: config.calidad.maxAlto,
    userAgent: s.userAgent, referrer: s.referrer
  });
}, (hechos, total) => { if (hechos % 100 === 0 || hechos === total) console.log(`  probados ${hechos}/${total}`); });

const anterior = await cartelAnterior(config);
const version = new Date().toISOString().replace(/\.\d+Z$/, 'Z');
const { cartelera, informe } = ensamblar({
  candidatos, logos, paises: countries, numerosPrevios: anterior?.numeros || {}, config, version
});

const decision = forzarPublicacion ? { publicar: cartelera.canales.length > 0 } : debePublicar(anterior, cartelera, config.proteccionMinimo);
informe.publicar = decision.publicar;
informe.motivoNoPublicar = decision.motivo || null;

const salida = path.join(aca, 'salida');
await mkdir(salida, { recursive: true });
await writeFile(path.join(salida, 'informe.json'), JSON.stringify(informe, null, 2));
if (decision.publicar) {
  await writeFile(path.join(salida, 'cartelera.json'), JSON.stringify(cartelera));
}

console.log(`\nCanales aceptados: ${informe.aceptados} de ${informe.candidatos}`);
console.log('Por grupo:', informe.porGrupo);
if (!decision.publicar) {
  console.log(`\n⚠️ NO se publica: ${decision.motivo}`);
  process.exitCode = 2;
} else {
  console.log(`\nEscribí salida/cartelera.json (versión ${version}).`);
}
