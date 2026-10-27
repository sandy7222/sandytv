// Arma salida/catalogo.json: todos los canales de iptv-org que se pueden reproducir en la página del televisor,
// para el buscador. Uso (lo corre el workflow): node armar_catalogo.mjs [carpetaSalida]
import { writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { armarCatalogo } from './lib/catalogo.mjs';

const salida = process.argv[2] || 'salida';
const API = 'https://iptv-org.github.io/api';

async function bajar(nombre) {
  for (let i = 1; i <= 3; i++) {
    try {
      const r = await fetch(`${API}/${nombre}.json`, { signal: AbortSignal.timeout(120000) });
      if (!r.ok) throw new Error('respuesta ' + r.status);
      return await r.json();
    } catch (e) {
      if (i === 3) throw new Error(`No pude bajar ${nombre}: ${e.message}`);
      await new Promise(res => setTimeout(res, 2000 * i));
    }
  }
}

const [channels, streams, countries] = await Promise.all(['channels', 'streams', 'countries'].map(bajar));
const cat = armarCatalogo({ channels, streams, countries });
// Protección: si salen muy pocos canales, algo falló en la fuente; no se publica un catálogo roto.
if (cat.canales.length < 2000) { console.error(`Catálogo sospechosamente chico (${cat.canales.length}); no se escribe.`); process.exit(2); }
cat.generado = new Date().toISOString();
await mkdir(salida, { recursive: true });
await writeFile(path.join(salida, 'catalogo.json'), JSON.stringify(cat));
console.log(`Catálogo: ${cat.canales.length} canales de ${Object.keys(cat.paises).length} países.`);
