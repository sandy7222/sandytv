// Genera el banner provisorio de 320x180 que usa Android TV en su menú de aplicaciones.
// Sin dependencias: arma el PNG a mano. Cuando el dueño tenga el logo definitivo, se reemplaza el archivo.
//   node tool/generar_banner.mjs

import { deflateSync } from 'node:zlib';
import { writeFileSync, mkdirSync } from 'node:fs';

const W = 320, H = 180;
const px = new Uint8Array(W * H * 3);

for (let y = 0; y < H; y++) {
  for (let x = 0; x < W; x++) {
    const t = (x / W + y / H) / 2;
    const i = (y * W + x) * 3;
    px[i] = Math.round(10 + t * 8);
    px[i + 1] = Math.round(14 + t * 34);
    px[i + 2] = Math.round(26 + t * 48);
  }
}

// Letras de 5x7 para "SANDY" y "TV".
const G = {
  S: ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
  A: ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  N: ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
  D: ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  Y: ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
  T: ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
  V: ['10001', '10001', '10001', '10001', '10001', '01010', '00100']
};

function rect(x0, y0, w, h, rgb) {
  for (let y = y0; y < y0 + h; y++) for (let x = x0; x < x0 + w; x++) {
    if (x < 0 || y < 0 || x >= W || y >= H) continue;
    const i = (y * W + x) * 3;
    px[i] = rgb[0]; px[i + 1] = rgb[1]; px[i + 2] = rgb[2];
  }
}

function palabra(texto, x0, y0, e, rgb) {
  let x = x0;
  for (const ch of texto) {
    G[ch].forEach((fila, r) => [...fila].forEach((c, k) => { if (c === '1') rect(x + k * e, y0 + r * e, e, e, rgb); }));
    x += 6 * e;
  }
  return x;
}

const e = 5;
const anchoSandy = 5 * 6 * e;
const anchoTV = 2 * 6 * e;
const total = anchoSandy + 10 + anchoTV;
const x0 = Math.round((W - total) / 2);
const y0 = Math.round((H - 7 * e) / 2);
palabra('SANDY', x0, y0, e, [241, 245, 249]);
rect(x0 + anchoSandy + 4, y0 - 8, anchoTV + 8, 7 * e + 16, [34, 211, 238]);
palabra('TV', x0 + anchoSandy + 8, y0, e, [10, 14, 26]);

// PNG
const crcTabla = new Uint32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
const crc = buf => { let c = 0xffffffff; for (const b of buf) c = crcTabla[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
const trozo = (tipo, datos) => {
  const len = Buffer.alloc(4); len.writeUInt32BE(datos.length);
  const cuerpo = Buffer.concat([Buffer.from(tipo), datos]);
  const c = Buffer.alloc(4); c.writeUInt32BE(crc(cuerpo));
  return Buffer.concat([len, cuerpo, c]);
};
const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(W, 0); ihdr.writeUInt32BE(H, 4); ihdr[8] = 8; ihdr[9] = 2;
const crudo = Buffer.alloc((W * 3 + 1) * H);
for (let y = 0; y < H; y++) { crudo[y * (W * 3 + 1)] = 0; Buffer.from(px.buffer, y * W * 3, W * 3).copy(crudo, y * (W * 3 + 1) + 1); }
const png = Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), trozo('IHDR', ihdr), trozo('IDAT', deflateSync(crudo)), trozo('IEND', Buffer.alloc(0))]);

mkdirSync('android/app/src/main/res/drawable-xhdpi', { recursive: true });
writeFileSync('android/app/src/main/res/drawable-xhdpi/banner.png', png);
console.log('banner.png escrito', png.length, 'bytes');
