// Arma el cartelera.json a partir de los candidatos ya probados.

import { altoDeCalidad, puntuar, cumpleMinimos } from './puntaje.mjs';
import { asignarNumeros } from './numeros.mjs';

export function elegirLogo(logos, canalId) {
  const propios = logos.filter(l => l.channel === canalId);
  if (!propios.length) return null;
  propios.sort((a, b) =>
    Number(b.in_use) - Number(a.in_use) ||
    (b.width || 0) * (b.height || 0) - (a.width || 0) * (a.height || 0));
  return propios[0].url;
}

function enlacesValidos(c, config) {
  const validos = [];
  c.streams.forEach((s, i) => {
    const r = c.pruebas[i];
    if (!r?.ok) return;
    const alto = r.alto ?? altoDeCalidad(s.calidadDeclarada);
    if (!cumpleMinimos({ alto, ratio: r.ratio, msRespuesta: r.msRespuesta }, config.calidad)) return;
    validos.push({
      url: s.url, alto, kbps: r.kbps ?? null,
      puntaje: puntuar({ alto, ratio: r.ratio, msRespuesta: r.msRespuesta }),
      userAgent: s.userAgent, referrer: s.referrer
    });
  });
  return validos.sort((a, b) => b.puntaje - a.puntaje).slice(0, config.prueba.maxEnlacesPorCanal);
}

function enlacesDeclarados(c, config) {
  return c.streams.slice(0, config.prueba.maxEnlacesPorCanal).map(s => ({
    url: s.url, alto: altoDeCalidad(s.calidadDeclarada), kbps: null, puntaje: 0,
    userAgent: s.userAgent, referrer: s.referrer
  }));
}

function motivoDeDescarte(c) {
  const motivos = c.pruebas.map(r => (r?.ok ? 'no llega a la calidad mínima' : r?.motivo || 'sin prueba'));
  return [...new Set(motivos)].join('; ');
}

export function ensamblar({ candidatos, logos, paises, numerosPrevios, config, version }) {
  const descartados = [];
  const aceptados = [];

  for (const c of candidatos) {
    let enlaces = enlacesValidos(c, config);
    let forzado = false;
    if (!enlaces.length && c.forzar) {
      enlaces = enlacesDeclarados(c, config);
      forzado = true;
    }
    if (!enlaces.length) {
      descartados.push({ id: c.id, motivo: motivoDeDescarte(c) });
      continue;
    }
    aceptados.push({ c, enlaces, forzado });
  }

  const orden = new Map(config.grupos.map((g, i) => [g.id, i]));
  aceptados.sort((a, b) =>
    (orden.get(a.c.grupo) ?? 99) - (orden.get(b.c.grupo) ?? 99) ||
    a.c.nombre.localeCompare(b.c.nombre, 'es'));

  const numeros = asignarNumeros(aceptados.map(a => a.c.id), numerosPrevios);
  const nombrePais = new Map(paises.map(p => [p.code, p.name]));

  const canales = aceptados.map(({ c, enlaces, forzado }) => ({
    id: c.id,
    numero: numeros[c.id],
    nombre: c.nombre,
    emisora: c.emisora,
    pais: c.pais,
    paisNombre: nombrePais.get(c.pais) ?? null,
    categoria: c.grupo,
    categoriasOriginales: c.categorias,
    logo: c.logo ?? elegirLogo(logos, c.id),
    web: c.web,
    forzado,
    enlaces
  }));

  const porGrupo = {};
  for (const c of canales) porGrupo[c.categoria] = (porGrupo[c.categoria] || 0) + 1;

  return {
    cartelera: {
      formato: 1,
      version,
      categorias: config.grupos.map((g, i) => ({ id: g.id, nombre: g.nombre, orden: i + 1 })),
      canales,
      numeros
    },
    informe: {
      version,
      candidatos: candidatos.length,
      aceptados: canales.length,
      forzados: canales.filter(c => c.forzado).map(c => c.id),
      descartados,
      porGrupo
    }
  };
}
