// Número de canal estable: un canal conserva su número entre versiones de la cartelera.
// Los números de canales que desaparecen quedan reservados (no se reutilizan).

export function asignarNumeros(ids, previos = {}) {
  const resultado = { ...previos };
  let siguiente = Math.max(0, ...Object.values(previos)) + 1;
  for (const id of ids) {
    if (resultado[id] == null) resultado[id] = siguiente++;
  }
  return resultado;
}
