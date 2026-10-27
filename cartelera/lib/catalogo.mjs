// Catálogo de búsqueda: todos los canales de iptv-org que la página del televisor puede reproducir
// (enlace https directo, sin pedir referrer ni user-agent). Formato compacto para que pese poco:
//   canales: [id, nombre, país (código), categoría, enlace, calidad]
const MAX_ALTO = 1080;

function alto(q) {
  const n = parseInt(String(q || ''), 10);
  return Number.isFinite(n) ? n : 0;
}

// Mejor calidad sin pasarse de 1080p (un televisor de 50" con conexión de casa no necesita más); si todos se pasan, el más chico.
function mejorFlujo(flujos) {
  const ordenados = [...flujos].sort((a, b) => {
    const ha = alto(a.quality), hb = alto(b.quality);
    const pa = ha > MAX_ALTO ? -ha : ha, pb = hb > MAX_ALTO ? -hb : hb;
    return pb - pa;
  });
  return ordenados[0];
}

export function armarCatalogo({ channels, streams, countries }) {
  const porCanal = new Map();
  for (const s of streams) {
    if (!s.channel || typeof s.url !== 'string' || !s.url.startsWith('https://')) continue;
    if (s.referrer || s.user_agent) continue;
    if (!porCanal.has(s.channel)) porCanal.set(s.channel, []);
    porCanal.get(s.channel).push(s);
  }
  const vistos = new Set();
  const canales = [];
  for (const c of channels) {
    if (vistos.has(c.id) || !porCanal.has(c.id)) continue;
    const cats = c.categories || [];
    if (c.closed || c.is_nsfw || cats.includes('xxx')) continue;
    vistos.add(c.id);
    const f = mejorFlujo(porCanal.get(c.id));
    canales.push([c.id, c.name, c.country, cats[0] || '', f.url, f.quality || '']);
  }
  canales.sort((a, b) => a[1].localeCompare(b[1], 'es', { sensitivity: 'base' }));
  const usados = new Set(canales.map(c => c[2]));
  const paises = {};
  for (const p of countries) if (usados.has(p.code)) paises[p.code] = p.name;
  return { formato: 'sandytv-catalogo-1', paises, canales };
}
