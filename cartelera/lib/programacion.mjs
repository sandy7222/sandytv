// Grilla de un canal propio hecho con videos de YouTube de los creadores que sigue el dueño.
// Todo en segundos (hora UNIX). Un programa: { v: idDelVideo, t: título, c: creador, i: inicio, d: duración }.

/** Ids de los videos de la lista "subidas" de un canal (YouTube.com/playlist?list=UULF…), del más nuevo al más viejo. */
export function parsearSubidas(html, max = 15) {
  const ids = [];
  for (const m of String(html).matchAll(/"contentId":"([\w-]{11})"/g)) {
    if (!ids.includes(m[1])) ids.push(m[1]);
    if (ids.length >= max) break;
  }
  return ids;
}

function decodificar(s) { try { return JSON.parse('"' + s + '"'); } catch { return s; } }

/** De la página de un video de YouTube: cuánto dura, su título y si se puede reproducir incrustado (no vivos, no próximos). */
export function leerDatosVideo(html) {
  const h = String(html);
  const seg = (h.match(/"lengthSeconds":"(\d+)"/) || [])[1];
  const estado = (h.match(/"playabilityStatus":\{"status":"([A-Z_]+)"/) || [])[1];
  const emb = (h.match(/"playableInEmbed":(true|false)/) || [])[1];
  const vivo = /"isLive":true/.test(h) || /"isUpcoming":true/.test(h);
  const dur = seg ? Number(seg) : 0;
  const ok = estado === 'OK' && emb === 'true' && !vivo && dur > 0;
  if (!ok) return { ok: false };
  const t = (h.match(/"videoDetails":\{[^}]*?"title":"((?:[^"\\]|\\.)*)"/) || [])[1];
  return t ? { ok: true, dur, titulo: decodificar(t) } : { ok: true, dur };
}

// Elige el próximo video: primero los que nunca salieron (el más nuevo antes) y después los que hace más que no salen;
// si se puede, de un creador distinto al del programa anterior.
function elegir(candidatos, historial, creadorAnterior) {
  const orden = [...candidatos].sort((a, b) => {
    const ha = historial[a.id] ?? -Infinity, hb = historial[b.id] ?? -Infinity;
    if (ha !== hb) return ha - hb;
    return (b.publicado || 0) - (a.publicado || 0);
  });
  return orden.find(c => c.creador !== creadorAnterior) || orden[0];
}

/**
 * Renueva la grilla: lo que ya está en marcha o por venir queda igual; se sacan los programas terminados
 * y se agregan programas al final hasta cubrir `horas` desde `ahora`.
 */
export function construirGrilla({ anterior = [], candidatos = [], ahora, horas = 48, historial = {}, auspicios = [] }) {
  const hist = { ...historial };
  const programas = anterior.filter(p => p.i + p.d > ahora).map(p => ({ ...p }));
  for (const p of programas) hist[p.v] = Math.max(hist[p.v] ?? -Infinity, p.i);
  const fin = ahora + horas * 3600;
  let t = programas.length ? programas[programas.length - 1].i + programas[programas.length - 1].d : ahora;
  let creadorAnterior = programas.length ? programas.filter(p => !p.a).slice(-1)[0]?.c ?? null : null;
  // Videos seguidos desde el último espacio auspiciado (para seguir la cuenta cuando se renueva la grilla)
  let desdeSpot = 0, nSpot = 0;
  for (let k = programas.length - 1; k >= 0 && !programas[k].a; k--) desdeSpot++;
  nSpot = programas.filter(p => p.a).length;
  while (t < fin && candidatos.length) {
    const sp = auspicios.length && programas.length && !programas[programas.length - 1].a ? auspicios[nSpot % auspicios.length] : null;
    if (sp && desdeSpot >= (sp.cada || 3)) {
      programas.push({ v: 'spot:' + sp.id, t: 'Espacio auspiciado: ' + sp.nombre, c: 'Publicidad', i: t, d: sp.dur, a: sp.archivo });
      t += sp.dur; desdeSpot = 0; nSpot++; continue;
    }
    desdeSpot++;
    const c = elegir(candidatos, hist, creadorAnterior);
    programas.push({ v: c.id, t: c.titulo, c: c.creador, i: t, d: c.dur });
    hist[c.id] = t; t += c.dur; creadorAnterior = c.creador;
  }
  return { programas, historial: hist };
}

/** Qué programa corresponde a un instante: { programa, desde } (desde = segundos que ya van del video) o null. */
export function programaEn(programas, instante) {
  for (const p of programas) if (instante >= p.i && instante < p.i + p.d) return { programa: p, desde: Math.floor(instante - p.i) };
  return null;
}
