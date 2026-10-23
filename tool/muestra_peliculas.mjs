// Arma el catálogo de MUESTRA de películas (app/assets/peliculas_inicial.json) a partir de la página pública
// de canales de YouTube que suben películas completas. Es solo para probar el menú de pelis; el catálogo
// real saldrá de la API oficial de YouTube (con una clave que se guarda como secreto en GitHub).
//
//   node tool/muestra_peliculas.mjs <salida.json> <archivo.html>=<Nombre del canal>=<modo> [...]
//
// modo "completa": solo videos cuyo título dice "película completa"; el género se deduce del título.
// modo "todos":    todos los videos de la página; van en una fila con el nombre del canal.

import { readFileSync, writeFileSync } from 'node:fs';

const [salida, ...fuentes] = process.argv.slice(2);

const GENEROS = [
  ['accion', 'Acción'], ['suspenso', 'Suspenso'], ['terror', 'Terror'], ['crimen', 'Crimen'],
  ['comedia', 'Comedia'], ['drama', 'Drama'], ['ciencia-ficcion', 'Ciencia ficción'], ['aventura', 'Aventura']
];

function generoDe(titulo) {
  const t = titulo.toLowerCase();
  for (const [id, nombre] of GENEROS) if (t.includes(nombre.toLowerCase())) return { id, nombre };
  return { id: 'otras', nombre: 'Otras' };
}

const slug = s => s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');

const vistos = new Set();
const peliculas = [];
const generosExtra = new Map();

for (const fuente of fuentes) {
  const [archivo, canal, modo] = fuente.split('=');
  const html = readFileSync(archivo, 'utf8');
  const m = html.match(/var ytInitialData = (\{.*?\});<\/script>/s);
  if (!m) throw new Error(`No encontré los datos de la página de ${canal}`);
  const datos = JSON.parse(m[1]);

  const agregar = (id, bruto) => {
    if (!id || !bruto || vistos.has(id)) return;
    if (modo === 'completa' && !/pel[ií]cula completa/i.test(bruto)) return;
    vistos.add(id);
    const titulo = bruto.split(/ - | \/\/ /)[0].replace(/\s+/g, ' ').replace(/\|.*$/, '').trim();
    let genero;
    if (modo === 'completa') {
      genero = generoDe(bruto).id;
    } else {
      genero = slug(canal);
      generosExtra.set(genero, canal);
    }
    peliculas.push({ id, titulo, canal, genero, portada: `https://i.ytimg.com/vi/${id}/mqdefault.jpg`, duracionMin: null });
  };

  (function rec(o) {
    if (!o || typeof o !== 'object') return;
    if (typeof o.videoId === 'string') agregar(o.videoId, o.title?.runs?.[0]?.text || o.title?.simpleText || o.headline?.simpleText);
    if (typeof o.contentId === 'string') agregar(o.contentId, o.metadata?.lockupMetadataViewModel?.title?.content);
    for (const k in o) rec(o[k]);
  })(datos);
}

const usados = new Set(peliculas.map(p => p.genero));
const generos = [
  ...GENEROS.map(([id, nombre]) => ({ id, nombre })),
  { id: 'otras', nombre: 'Otras' },
  ...[...generosExtra].map(([id, nombre]) => ({ id, nombre }))
].filter(g => usados.has(g.id));

writeFileSync(salida, JSON.stringify({ formato: 1, version: 'muestra', generos, peliculas }, null, 2));
console.log(`${peliculas.length} películas de muestra, filas: ${generos.map(g => g.nombre).join(', ')}`);
