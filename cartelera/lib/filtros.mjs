// Elige qué canales de iptv-org entran a la prueba: región, idioma, categorías y ajustes propios.

import { altoDeCalidad } from './puntaje.mjs';

const CINE = ['movies', 'series', 'classic', 'comedy'];
const DOCUMENTALES = ['documentary', 'science', 'education', 'travel', 'outdoor', 'culture', 'cooking'];
const INFANTILES = ['kids', 'animation'];

export function grupoDe({ pais, categorias = [] }, forzado) {
  if (forzado) return forzado;
  const tiene = lista => lista.some(c => categorias.includes(c));
  if (categorias.includes('news')) return 'noticias';
  if (categorias.includes('sports')) return 'deportes';
  if (tiene(CINE)) return 'cine';
  if (tiene(DOCUMENTALES)) return 'documentales';
  if (tiene(INFANTILES)) return 'infantiles';
  if (categorias.includes('music')) return 'musica';
  if (pais === 'AR') return 'argentina';
  if (['UY', 'CL', 'PY', 'BO', 'PE', 'CO', 'VE', 'EC', 'MX', 'CR', 'PA', 'GT', 'SV', 'HN', 'NI', 'DO', 'CU', 'PR'].includes(pais)) return 'latinoamerica';
  return 'otros';
}

function idiomasPorCanal(feeds) {
  const mapa = new Map();
  for (const f of feeds) {
    if (!f.channel) continue;
    const set = mapa.get(f.channel) || new Set();
    (f.languages || []).forEach(l => set.add(l));
    mapa.set(f.channel, set);
  }
  return mapa;
}

function agregarEnlace(lista, enlace) {
  if (!lista.some(e => e.url === enlace.url)) lista.push(enlace);
}

export function prepararCandidatos({ channels, streams, feeds, config, mis = {} }) {
  const excluir = new Set(mis.excluir || []);
  const forzar = new Set(mis.forzar || []);
  const gruposMano = mis.grupo || {};
  const idiomas = idiomasPorCanal(feeds);

  const streamsPorCanal = new Map();
  for (const s of streams) {
    if (!s.channel) continue;
    if ((s.labels || []).some(l => (config.etiquetasExcluidas || []).includes(l))) continue;
    const lista = streamsPorCanal.get(s.channel) || [];
    agregarEnlace(lista, {
      url: s.url,
      calidadDeclarada: s.quality || null,
      userAgent: s.user_agent || null,
      referrer: s.referrer || null
    });
    streamsPorCanal.set(s.channel, lista);
  }

  const candidatos = [];
  for (const c of channels) {
    if (excluir.has(c.id) || c.closed || c.is_nsfw) continue;
    if (!config.paises.includes(c.country) || (config.paisesExcluidos || []).includes(c.country)) continue;
    if ((c.categories || []).some(cat => (config.categoriasExcluidas || []).includes(cat))) continue;
    const idi = idiomas.get(c.id);
    if (idi && idi.size && !idi.has(config.idioma)) continue;
    const enlaces = streamsPorCanal.get(c.id);
    if (!enlaces?.length) continue;

    enlaces.sort((a, b) => (altoDeCalidad(b.calidadDeclarada) || 0) - (altoDeCalidad(a.calidadDeclarada) || 0));
    candidatos.push({
      id: c.id,
      nombre: c.name,
      pais: c.country,
      categorias: c.categories || [],
      emisora: c.network || (c.owners && c.owners[0]) || null,
      web: c.website || null,
      grupo: grupoDe({ pais: c.country, categorias: c.categories || [] }, gruposMano[c.id]),
      forzar: forzar.has(c.id),
      streams: enlaces
    });
  }

  for (const p of mis.agregar || []) {
    if (excluir.has(p.id)) continue;
    candidatos.push({
      id: p.id,
      nombre: p.nombre,
      pais: p.pais || null,
      categorias: p.categorias || [],
      emisora: p.emisora || null,
      web: p.web || null,
      logo: p.logo || null,
      grupo: grupoDe({ pais: p.pais, categorias: p.categorias || [] }, p.grupo || gruposMano[p.id]),
      forzar: forzar.has(p.id),
      streams: (p.enlaces || []).map(url => ({ url, calidadDeclarada: null, userAgent: null, referrer: null }))
    });
  }

  return candidatos;
}
