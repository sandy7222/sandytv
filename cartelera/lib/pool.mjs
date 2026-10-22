// Corre una función sobre muchos elementos, de a N a la vez, conservando el orden de los resultados.

export async function conLimite(items, limite, fn, alAvanzar = () => {}) {
  const resultados = new Array(items.length);
  let siguiente = 0;
  let hechos = 0;
  async function trabajador() {
    while (true) {
      const i = siguiente++;
      if (i >= items.length) return;
      resultados[i] = await fn(items[i], i);
      alAvanzar(++hechos, items.length);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limite, items.length) }, trabajador));
  return resultados;
}
