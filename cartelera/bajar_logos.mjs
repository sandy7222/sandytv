// Baja los logos de la cartelera y guarda una copia CHICA de cada uno en nuestra propia página.
// Por qué: el televisor Philips no logra bajar las imágenes alojadas en imgur (la mayoría de los logos de canales
// argentinos). Con la copia en GitHub Pages, la imagen viene del mismo sitio que la página y pesa pocos KB.
// Uso (lo corre el workflow después de armar la cartelera): node bajar_logos.mjs [carpetaSalida]
// Requiere el paquete "sharp" (el workflow lo instala; las pruebas no lo necesitan).
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { join } from 'node:path';

const SALIDA = process.argv[2] || 'salida';
const ANCHO = 160, ALTO = 100, MAX_BYTES = 6 * 1024 * 1024, PARALELO = 8;

export function nombreArchivo(id) {
  return String(id).replace(/[^A-Za-z0-9._-]/g, '_') + '.png';
}

async function bajar(url) {
  const r = await fetch(url, { redirect: 'follow', signal: AbortSignal.timeout(20000), headers: { 'user-agent': 'Mozilla/5.0 SandyTV' } });
  if (!r.ok) throw new Error('HTTP ' + r.status);
  const b = Buffer.from(await r.arrayBuffer());
  if (!b.length || b.length > MAX_BYTES) throw new Error('tamaño ' + b.length);
  return b;
}

async function main() {
  let sharp;
  try { sharp = (await import('sharp')).default; } catch { console.log('Sin sharp: no se generan miniaturas (la página usa los logos originales).'); return; }
  const ruta = join(SALIDA, 'cartelera.json');
  const cartelera = JSON.parse(await readFile(ruta, 'utf8'));
  const dir = join(SALIDA, 'logos');
  await mkdir(dir, { recursive: true });
  const conLogo = cartelera.canales.filter((c) => c.logo);
  let ok = 0, fallos = 0, i = 0;
  async function obrero() {
    while (i < conLogo.length) {
      const c = conLogo[i++];
      try {
        const buf = await bajar(c.logo);
        const png = await sharp(buf, { animated: false })
          .resize(ANCHO, ALTO, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
          .png({ compressionLevel: 9, palette: true })
          .toBuffer();
        await writeFile(join(dir, nombreArchivo(c.id)), png);
        c.logoLocal = 'logos/' + nombreArchivo(c.id);
        ok++;
      } catch (e) { fallos++; }
    }
  }
  await Promise.all(Array.from({ length: PARALELO }, obrero));
  await writeFile(ruta, JSON.stringify(cartelera));
  console.log(`Logos: ${ok} miniaturas, ${fallos} sin poder bajar (de ${conLogo.length}).`);
}

if (import.meta.url === new URL(process.argv[1], 'file:///').href || process.argv[1]?.endsWith('bajar_logos.mjs')) await main();
