/**
 * Vendors third-party assets into renderer/vendor/ so the packaged desktop app
 * has zero external network dependencies beyond Supabase itself.
 *
 * Two things get vendored:
 *
 *  1. @supabase/supabase-js — bundled to a single IIFE that exposes
 *     window.supabase. The renderer runs with nodeIntegration disabled, so it
 *     cannot require() anything; a plain <script> bundle is the way in.
 *
 *  2. JetBrains Mono — the original index_2.html pulled this from Google Fonts
 *     over the network. In a desktop app that is both an offline failure mode
 *     (no font until the network answers) and a privacy leak (every launch
 *     announces itself to a third party). Since the founder asked for maximum
 *     privacy, the font ships inside the app and the Google Fonts <link> is
 *     gone. APEX OS now talks to exactly one host: the Supabase project.
 */

import { build } from 'esbuild';
import { mkdirSync, copyFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const vendorDir = resolve(root, 'renderer/vendor');
const fontDir = resolve(vendorDir, 'fonts');

mkdirSync(fontDir, { recursive: true });

// ---- 1. supabase-js -------------------------------------------------------
await build({
  entryPoints: [resolve(root, 'scripts/supabase-entry.js')],
  bundle: true,
  format: 'iife',
  globalName: 'supabase',
  platform: 'browser',
  target: ['chrome120'],
  minify: true,
  outfile: resolve(vendorDir, 'supabase.js'),
  logLevel: 'info',
});

// ---- 2. JetBrains Mono ----------------------------------------------------
const weights = [400, 500, 600, 700];
const fontSrc = resolve(root, 'node_modules/@fontsource/jetbrains-mono/files');

for (const w of weights) {
  const file = `jetbrains-mono-latin-${w}-normal.woff2`;
  copyFileSync(resolve(fontSrc, file), resolve(fontDir, file));
}

writeFileSync(
  resolve(fontDir, 'jetbrains-mono.css'),
  weights
    .map(
      (w) => `@font-face{
  font-family:'JetBrains Mono';
  font-style:normal;
  font-weight:${w};
  font-display:swap;
  src:url('./jetbrains-mono-latin-${w}-normal.woff2') format('woff2');
}`
    )
    .join('\n') + '\n'
);

console.log(`vendored supabase.js + JetBrains Mono (${weights.join(', ')})`);
