'use strict';

const { app, BrowserWindow, shell, session } = require('electron');
const path = require('node:path');
const { SUPABASE_URL, SUPABASE_ANON_KEY } = require('./config');

const SUPABASE_ORIGIN = new URL(SUPABASE_URL).origin;

/**
 * Content-Security-Policy for the renderer.
 *
 * Everything the UI needs is local: scripts, styles, and the vendored font all
 * ship in the bundle. The single permitted outbound destination is the
 * Supabase project. There is no CDN, no analytics, and no font host — so a
 * compromised or mistaken script has nowhere to send data.
 *
 * 'unsafe-inline' is granted to style-src only. The UI builds its SVG charts by
 * setting inline style attributes on generated elements (bar widths, node
 * fills), which CSP counts as inline styles. script-src gets no such latitude:
 * it is 'self' only, so no inline <script> and no eval can run.
 *
 * Realtime (wss:) is deliberately omitted — APEX OS fetches on demand and holds
 * no websocket. Add `wss://<host>` to connect-src if that ever changes.
 */
const CSP = [
  "default-src 'none'",
  "script-src 'self'",
  "style-src 'self' 'unsafe-inline'",
  "font-src 'self'",
  "img-src 'self' data:",
  `connect-src ${SUPABASE_ORIGIN}`,
  "form-action 'none'",
  "frame-ancestors 'none'",
  "base-uri 'none'",
].join('; ');

/**
 * The preload runs sandboxed, so it cannot require() a local config module.
 * additionalArguments is the supported channel for handing it startup data —
 * it arrives as an argv entry the preload parses.
 */
const CONFIG_ARG = `--apex-config=${Buffer.from(
  JSON.stringify({ supabaseUrl: SUPABASE_URL, supabaseAnonKey: SUPABASE_ANON_KEY })
).toString('base64')}`;

function createWindow() {
  const win = new BrowserWindow({
    width: 1440,
    height: 940,
    minWidth: 1024,
    minHeight: 700,
    backgroundColor: '#050807', // matches the dark theme's --bg; avoids a white flash on open
    title: 'APEX OS',
    // Window/taskbar icon. A packaged Windows build takes its icon from the
    // exe resources instead, but this covers `npm start` and Linux.
    icon: path.join(__dirname, '../build/icon.png'),
    show: false,
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webviewTag: false,
      additionalArguments: [CONFIG_ARG],
    },
  });

  win.once('ready-to-show', () => win.show());
  win.loadFile(path.join(__dirname, '../renderer/index.html'));

  // External links open in the real browser rather than navigating the app
  // window away from the local UI.
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('https://')) shell.openExternal(url);
    return { action: 'deny' };
  });

  // Hard stop on in-window navigation to anywhere but the bundled UI.
  win.webContents.on('will-navigate', (event, url) => {
    if (!url.startsWith('file://')) event.preventDefault();
  });

  return win;
}

app.whenReady().then(() => {
  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    callback({
      responseHeaders: {
        ...details.responseHeaders,
        'Content-Security-Policy': [CSP],
      },
    });
  });

  // The UI needs no device access at all. Refuse every permission request
  // rather than relying on none ever being made.
  session.defaultSession.setPermissionRequestHandler((_wc, _perm, cb) => cb(false));

  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
