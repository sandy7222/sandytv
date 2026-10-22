// Protección: si la cartelera nueva perdió demasiados canales (por ejemplo, porque iptv-org
// estuvo caído), no se publica y queda la anterior.

export function debePublicar(anterior, nueva, minimo = 0.5) {
  const n = nueva.canales.length;
  if (n === 0) return { publicar: false, motivo: 'La cartelera nueva está vacía.' };
  if (!anterior || !anterior.canales?.length) return { publicar: true };
  const a = anterior.canales.length;
  if (n < a * minimo) {
    return { publicar: false, motivo: `La cartelera nueva tiene ${n} canales y la anterior ${a}: perdió más del ${Math.round((1 - minimo) * 100)} %.` };
  }
  return { publicar: true };
}
