// Genera los íconos provisorios de SandyTV para la versión web (los que usa el navegador del
// televisor al guardar el acceso directo). Sin dependencias: arma los PNG a mano.
// Cuando el dueño tenga el logo definitivo, se reemplazan los archivos.
//   node tool/generar_iconos_web.mjs

import { deflateSync } from 'node:zlib';
import { writeFileSync } from 'node:fs';

const G = {
  S: ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
  A: ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  N: ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
  D: ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  Y: ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
  T: ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
  V: ['10001', '10001', '10001', '10001', '10001', '01010', '00100']
};

function icono(L) {
  const px = new Uint8Array(L * L * 3);
  const rect = (x0, y0, w, h, rgb) => {
    for (let y = Math.max(0, y0); y < Math.min(L, y0 + h); y++) for (let x = Math.max(0, x0); x < Math.min(L, x0 + w); x++) {
      const i = (y * L + x) * 3; px[i] = rgb[0]; px[i + 1] = rgb[1]; px[i + 2] = rgb[2];
    }
  };
  const palabra = (texto, x0, y0, e, rgb) => {
    let x = x0;
    for (const ch of texto) {
      G[ch].forEach((fila, r) => [...fila].forEach((c, k) => { if (c === '1') rect(x + k * e, y0 + r * e, e, e, rgb); }));
      x += 6 * e;
    }
  };
  for (let y = 0; y < L; y++) for (let x = 0; x < L; x++) {
    const t = (x + y) / (2 * L); const i = (y * L + x) * 3;
    px[i] = Math.round(10 + t * 8); px[i + 1] = Math.round(14 + t * 34); px[i + 2] = Math.round(26 + t * 48);
  }
  // "SANDY" arriba, "TV" en un recuadro celeste abajo
  const e1 = Math.floor(L / 36);
  const anchoSandy = 5 * 6 * e1 - e1;
  palabra('SANDY', Math.round((L - anchoSandy) / 2), Math.round(L * 0.24), e1, [241, 245, 249]);
  const e2 = Math.floor(L / 16);
  const anchoTV = 2 * 6 * e2 - e2;
  const xTV = Math.round((L - anchoTV) / 2);
  const yTV = Math.round(L * 0.48);
  rect(xTV - e2, yTV - e2, anchoTV + 2 * e2, 7 * e2 + 2 * e2, [34, 211, 238]);
  palabra('TV', xTV, yTV, e2, [10, 14, 26]);
  return png(L, L, px);
}

function png(W, H, px) {
  const tabla = new Uint32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
  const crc = b => { let c = 0xffffffff; for (const x of b) c = tabla[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const trozo = (tipo, datos) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(datos.length);
    const cuerpo = Buffer.concat([Buffer.from(tipo), datos]);
    const c = Buffer.alloc(4); c.writeUInt32BE(crc(cuerpo));
    return Buffer.concat([len, cuerpo, c]);
  };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 2;
  const crudo = Buffer.alloc((W * 3 + 1) * H);
  for (let y = 0; y < H; y++) Buffer.from(px.buffer, y * W * 3, W * 3).copy(crudo, y * (W * 3 + 1) + 1);
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), trozo('IHDR', ihdr), trozo('IDAT', deflateSync(crudo)), trozo('IEND', Buffer.alloc(0))]);
}

for (const L of [180, 192, 512]) {
  writeFileSync(`web/icono-${L}.png`, icono(L));
  console.log(`web/icono-${L}.png`);
}
