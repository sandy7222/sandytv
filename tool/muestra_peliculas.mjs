// Arma el catálogo de MUESTRA de películas (app/assets/peliculas_inicial.json) a partir de la página pública
// de un canal de YouTube que sube películas completas. Es solo para probar el menú de pelis; el catálogo
// real saldrá de la API oficial de YouTube (con una clave que se guarda como secreto en GitHub).
//
//   node tool/muestra_peliculas.mjs <archivo.html del canal> <salida.json>

import { readFileSync, writeFileSync } from 'node:fs';

const [entrada, salida] = process.argv.slice(2);
const html = readFileSync(entrada, 'utf8');
const m = html.match(/var ytInitialData = (\{.*?\});<\/script>/s);
if (!m) throw new Error('No encontré los datos de la página');
const datos = JSON.parse(m[1]);

const GENEROS = [
  ['accion', 'Acción'], ['suspenso', 'Suspenso'], ['terror', 'Terror'], ['crimen', 'Crimen'],
  ['comedia', 'Comedia'], ['drama', 'Drama'], ['ciencia-ficcion', 'Ciencia ficción'], ['aventura', 'Aventura']
];

function generoDe(titulo) {
  const t = titulo.toLowerCase();
  for (const [id, nombre] of GENEROS) if (t.includes(nombre.toLowerCase())) return { id, nombre };
  return { id: 'otras', nombre: 'Otras' };
}

const vistos = new Set();
const peliculas = [];

function agregar(id, bruto) {
  if (!id || !bruto || vistos.has(id) || !/pel[ií]cula completa/i.test(bruto)) return;
  vistos.add(id);
  const titulo = bruto.split(' - ')[0].replace(/\s+/g, ' ').trim();
  peliculas.push({ id, titulo, canal: 'Adrenalina Pura TV', genero: generoDe(bruto).id,
    portada: `https://i.ytimg.com/vi/${id}/mqdefault.jpg`, duracionMin: null });
}

(function rec(o) {
  if (!o || typeof o !== 'object') return;
  // formato clásico de la página
  if (typeof o.videoId === 'string') agregar(o.videoId, o.title?.runs?.[0]?.text || o.title?.simpleText || o.headline?.simpleText);
  // formato nuevo de la página
  if (typeof o.contentId === 'string') agregar(o.contentId, o.metadata?.lockupMetadataViewModel?.title?.content);
  for (const k in o) rec(o[k]);
})(datos);

const usados = new Set(peliculas.map(p => p.genero));
const generos = [...GENEROS.map(([id, nombre]) => ({ id, nombre })), { id: 'otras', nombre: 'Otras' }]
  .filter(g => usados.has(g.id));

writeFileSync(salida, JSON.stringify({ formato: 1, version: 'muestra', generos, peliculas }, null, 2));
console.log(`${peliculas.length} películas de muestra, géneros: ${generos.map(g => g.nombre).join(', ')}`);
