/**
 * Generates the APEX OS app icon from code.
 *
 * The mark is the "spark" glyph already used throughout the UI — the centre
 * ring plus eight rays that appears on the CEO node, the conductor bar and
 * every agent card. Same geometry, same accent green, so the taskbar icon and
 * the app agree with each other.
 *
 * Written as a generator rather than a checked-in binary for two reasons:
 * the geometry stays editable (change a constant, re-run), and a reviewer can
 * see exactly what the icon is instead of trusting an opaque blob. No image
 * library needed — PNG is just zlib-compressed scanlines, and a modern .ico is
 * a small header wrapped around embedded PNGs.
 *
 * Run: npm run icon
 * Out: build/icon.png (1024px, also the Linux icon and the source
 *      electron-builder converts to .icns for macOS)
 *      build/icon.ico  (16/32/48/64/128/256, for Windows)
 */

import { deflateSync } from 'node:zlib';
import { writeFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outDir = resolve(root, 'build');
mkdirSync(outDir, { recursive: true });

/* ---- palette: lifted from the dark theme in styles.css ------------------ */
const BG = [0x0a, 0x0f, 0x0c]; // --surface
const FG = [0x3d, 0xf0, 0x8c]; // --accent

/* ---- geometry ------------------------------------------------------------
   The glyph is defined in the original SVG's 24x24 space and mapped so its
   outermost point (radius 10) lands at 0.40 of the icon width. Keeping the
   source numbers means the icon and the inline SVGs can't drift apart. */
const U = 0.96 / 24; // svg unit -> normalised icon unit
const RING_R = 3 * U; // circle r=3
const STROKE = 1.5 * U; // stroke-width=1.5
const RAY_IN = 6 * U; // rays run from radius 6...
const RAY_OUT = 10 * U; // ...to radius 10
const CORNER = 0.18; // rounded-square radius
const INSET = 0.04;

const SS = 4; // supersampling factor -> antialiasing

function distToSegment(px, py, ax, ay, bx, by) {
  const dx = bx - ax;
  const dy = by - ay;
  const len2 = dx * dx + dy * dy;
  let t = len2 === 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / len2;
  t = Math.max(0, Math.min(1, t));
  const cx = ax + t * dx;
  const cy = ay + t * dy;
  return Math.hypot(px - cx, py - cy);
}

function insideRoundedRect(x, y) {
  const lo = INSET;
  const hi = 1 - INSET;
  if (x < lo || x > hi || y < lo || y > hi) return false;
  const r = CORNER;
  // Corner centres
  const cx = x < lo + r ? lo + r : x > hi - r ? hi - r : x;
  const cy = y < lo + r ? lo + r : y > hi - r ? hi - r : y;
  if (cx === x || cy === y) return true;
  return Math.hypot(x - cx, y - cy) <= r;
}

/** The eight ray endpoints, at 45° steps, matching the SVG's path data. */
const RAYS = Array.from({ length: 8 }, (_, i) => {
  const a = (i * Math.PI) / 4;
  return [
    0.5 + Math.cos(a) * RAY_IN,
    0.5 + Math.sin(a) * RAY_IN,
    0.5 + Math.cos(a) * RAY_OUT,
    0.5 + Math.sin(a) * RAY_OUT,
  ];
});

function insideGlyph(x, y) {
  const d = Math.hypot(x - 0.5, y - 0.5);
  // Centre ring (stroked circle, not a filled disc — as in the SVG)
  if (Math.abs(d - RING_R) <= STROKE / 2) return true;
  for (const [ax, ay, bx, by] of RAYS) {
    if (distToSegment(x, y, ax, ay, bx, by) <= STROKE / 2) return true;
  }
  return false;
}

/** Renders one RGBA buffer at `size`, supersampled and box-filtered down. */
function render(size) {
  const hi = size * SS;
  // Premultiplied accumulation buffers
  const out = Buffer.alloc(size * size * 4);

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      let r = 0;
      let g = 0;
      let b = 0;
      let a = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const fx = (x * SS + sx + 0.5) / hi;
          const fy = (y * SS + sy + 0.5) / hi;
          if (!insideRoundedRect(fx, fy)) continue;
          const c = insideGlyph(fx, fy) ? FG : BG;
          r += c[0];
          g += c[1];
          b += c[2];
          a += 255;
        }
      }
      const n = SS * SS;
      const i = (y * size + x) * 4;
      if (a === 0) continue;
      // Un-premultiply: colour is the average over covered samples only.
      const covered = a / 255;
      out[i] = Math.round(r / covered);
      out[i + 1] = Math.round(g / covered);
      out[i + 2] = Math.round(b / covered);
      out[i + 3] = Math.round(a / n);
    }
  }
  return out;
}

/* ---- minimal PNG writer -------------------------------------------------- */

const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

function toPng(rgba, size) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // colour type: RGBA
  // 10..12 = compression, filter, interlace = 0

  // Each scanline gets a leading filter byte (0 = None).
  const raw = Buffer.alloc(size * (size * 4 + 1));
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0;
    rgba.copy(raw, y * (size * 4 + 1) + 1, y * size * 4, (y + 1) * size * 4);
  }

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/* ---- ICO container -------------------------------------------------------
   Vista and later accept PNG-compressed entries, so each size is just the PNG
   bytes with a directory entry pointing at it. */
function toIco(entries) {
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0); // reserved
  header.writeUInt16LE(1, 2); // type 1 = icon
  header.writeUInt16LE(entries.length, 4);

  const dir = Buffer.alloc(16 * entries.length);
  let offset = header.length + dir.length;

  entries.forEach(({ size, png }, i) => {
    const o = i * 16;
    dir[o] = size >= 256 ? 0 : size; // 0 means 256
    dir[o + 1] = size >= 256 ? 0 : size;
    dir[o + 2] = 0; // palette count
    dir[o + 3] = 0; // reserved
    dir.writeUInt16LE(1, o + 4); // colour planes
    dir.writeUInt16LE(32, o + 6); // bits per pixel
    dir.writeUInt32LE(png.length, o + 8);
    dir.writeUInt32LE(offset, o + 12);
    offset += png.length;
  });

  return Buffer.concat([header, dir, ...entries.map((e) => e.png)]);
}

/* ---- build --------------------------------------------------------------- */

const icoSizes = [16, 32, 48, 64, 128, 256];
const entries = icoSizes.map((size) => ({ size, png: toPng(render(size), size) }));

writeFileSync(resolve(outDir, 'icon.ico'), toIco(entries));
writeFileSync(resolve(outDir, 'icon.png'), toPng(render(1024), 1024));

console.log(`icon.ico  (${icoSizes.join(', ')})`);
console.log('icon.png  (1024)');
