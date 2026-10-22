// Lectura mínima de listas HLS (.m3u8): solo lo que hace falta para probar un canal.

export function esMaestra(texto) {
  return /#EXT-X-STREAM-INF/.test(texto);
}

function atributo(linea, nombre) {
  const m = linea.match(new RegExp(`${nombre}=([^,]+)`));
  return m ? m[1] : null;
}

export function parsearMaestra(texto, base) {
  const lineas = texto.split(/\r?\n/).map(l => l.trim());
  const variantes = [];
  for (let i = 0; i < lineas.length; i++) {
    if (!lineas[i].startsWith('#EXT-X-STREAM-INF')) continue;
    const bw = Number(atributo(lineas[i], 'BANDWIDTH'));
    const res = atributo(lineas[i], 'RESOLUTION');
    const [ancho, alto] = res ? res.split('x').map(Number) : [null, null];
    let j = i + 1;
    while (j < lineas.length && (lineas[j] === '' || lineas[j].startsWith('#'))) j++;
    if (j >= lineas.length) break;
    variantes.push({
      url: new URL(lineas[j], base).href,
      ancho,
      alto,
      kbps: bw ? Math.round(bw / 1000) : null
    });
  }
  return variantes;
}

export function elegirVariante(variantes, { maxAlto = 1080 } = {}) {
  if (!variantes.length) return null;
  const conAlto = variantes.filter(v => v.alto);
  if (!conAlto.length) {
    return [...variantes].sort((a, b) => (b.kbps || 0) - (a.kbps || 0))[0];
  }
  const dentro = conAlto.filter(v => v.alto <= maxAlto);
  if (dentro.length) {
    return dentro.sort((a, b) => b.alto - a.alto || (b.kbps || 0) - (a.kbps || 0))[0];
  }
  return conAlto.sort((a, b) => a.alto - b.alto)[0];
}

export function primerSegmento(texto, base) {
  const lineas = texto.split(/\r?\n/).map(l => l.trim());
  for (let i = 0; i < lineas.length; i++) {
    const m = lineas[i].match(/^#EXTINF:([\d.]+)/);
    if (!m) continue;
    let j = i + 1;
    while (j < lineas.length && (lineas[j] === '' || lineas[j].startsWith('#'))) j++;
    if (j >= lineas.length) return null;
    return { url: new URL(lineas[j], base).href, duracion: Number(m[1]) };
  }
  return null;
}
