// Puntaje de un enlace: resolución (50) + velocidad de descarga (30) + demora de respuesta (20).

export function altoDeCalidad(etiqueta) {
  if (!etiqueta) return null;
  const m = String(etiqueta).match(/^(\d{3,4})[pi]$/i);
  return m ? Number(m[1]) : null;
}

function puntosResolucion(alto) {
  if (alto == null) return 20;
  if (alto >= 1080) return 50;
  if (alto >= 720) return 42;
  if (alto >= 576) return 30;
  if (alto >= 480) return 22;
  return 8;
}

function puntosVelocidad(ratio) {
  if (ratio >= 3) return 30;
  if (ratio >= 1.5) return 20;
  if (ratio >= 1) return 8;
  return 0;
}

function puntosDemora(ms) {
  if (ms < 1500) return 20;
  if (ms < 3000) return 16;
  if (ms < 8000) return 8;
  return 0;
}

export function puntuar({ alto, ratio, msRespuesta }) {
  return puntosResolucion(alto) + puntosVelocidad(ratio) + puntosDemora(msRespuesta);
}

export function cumpleMinimos({ alto, ratio, msRespuesta }, calidad) {
  if (alto != null && alto < calidad.minAlto) return false;
  if (ratio < calidad.minRatio) return false;
  if (msRespuesta > calidad.maxMsRespuesta) return false;
  return true;
}
