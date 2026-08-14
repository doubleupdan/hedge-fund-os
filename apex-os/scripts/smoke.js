'use strict';

/**
 * Headless smoke test. Boots the real Electron main process configuration,
 * loads the renderer, and asserts that the UI actually rendered rather than
 * dying on a script error.
 *
 * It deliberately does NOT sign in — there are no test credentials, and a
 * smoke test should not need any. What it proves is that the app opens, the
 * vendored bundles load under the production CSP, every page renders its
 * static content, and the sign-in gate is the thing standing between the user
 * and the data. The live query itself is exercised on first real sign-in.
 *
 * Run: xvfb-run -a npx electron scripts/smoke.js --no-sandbox
 */

const { app, BrowserWindow, session } = require('electron');
const path = require('node:path');
const { SUPABASE_URL, SUPABASE_ANON_KEY } = require('../electron/config');

const SUPABASE_ORIGIN = new URL(SUPABASE_URL).origin;
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

const CONFIG_ARG = `--apex-config=${Buffer.from(
  JSON.stringify({ supabaseUrl: SUPABASE_URL, supabaseAnonKey: SUPABASE_ANON_KEY })
).toString('base64')}`;

const problems = [];

app.whenReady().then(async () => {
  session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
    callback({
      responseHeaders: { ...details.responseHeaders, 'Content-Security-Policy': [CSP] },
    });
  });

  const win = new BrowserWindow({
    width: 1440,
    height: 940,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, '../electron/preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      additionalArguments: [CONFIG_ARG],
    },
  });

  win.webContents.on('console-message', (_e, level, message) => {
    // level 3 = error. CSP violations and uncaught exceptions both land here.
    if (level >= 2) problems.push(`console(${level}): ${message}`);
  });
  win.webContents.on('render-process-gone', (_e, d) =>
    problems.push(`renderer gone: ${d.reason}`)
  );

  await win.loadFile(path.join(__dirname, '../renderer/index.html'));
  // Let the boot IIFE settle (it awaits getSession()).
  await new Promise((r) => setTimeout(r, 2500));

  const result = await win.webContents.executeJavaScript(`(() => {
    const q = (s) => document.querySelector(s);
    const n = (s) => document.querySelectorAll(s).length;
    return {
      supabaseLoaded: typeof window.supabase?.createClient === 'function',
      configBridged: !!(window.APEX_CONFIG && window.APEX_CONFIG.supabaseUrl),
      apexConfigured: !!(window.APEX && window.APEX.configured),
      fontFamily: getComputedStyle(document.body).fontFamily,
      gateVisible: !q('#gate').hidden,
      navItems: n('.nav-item'),
      agentCards: n('.agent-card'),
      placeholderCards: n('.agent-card.placeholder'),
      deptCols: n('.dept-col'),
      kgNodes: n('#kgSvg circle'),
      radarNodes: n('#radarSvg polygon'),
      mockBadges: n('.prov.mock'),
      riskBodyHidden: q('#riskBody').hidden,
      themeAttr: document.documentElement.getAttribute('data-theme'),
    };
  })()`);

  console.log('\n=== APEX OS smoke ===');
  console.log(JSON.stringify(result, null, 2));

  const checks = [
    ['supabase-js bundle loaded', result.supabaseLoaded],
    ['config crossed the context bridge', result.configBridged],
    ['APEX data layer configured', result.apexConfigured],
    ['JetBrains Mono applied (local font)', /JetBrains Mono/.test(result.fontFamily)],
    ['sign-in gate is blocking the UI', result.gateVisible],
    ['risk body hidden until authenticated', result.riskBodyHidden],
    ['nav rendered (4 items)', result.navItems === 4],
    ['15 live agent cards rendered', result.agentCards - result.placeholderCards === 15],
    ['185 placeholder cards rendered', result.placeholderCards === 185],
    ['10 department columns rendered', result.deptCols === 10],
    ['knowledge graph drew nodes', result.kgNodes > 10],
    ['radar drew polygons', result.radarNodes > 0],
    ['illustrative badges present', result.mockBadges > 10],
    ['theme applied', result.themeAttr === 'dark'],
  ];

  let failed = 0;
  for (const [label, ok] of checks) {
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${label}`);
    if (!ok) failed++;
  }

  if (problems.length) {
    console.log('\n--- console errors / warnings ---');
    problems.forEach((p) => console.log('  ' + p));
  } else {
    console.log('\nNo console errors.');
  }

  console.log(`\n${failed === 0 && problems.length === 0 ? 'SMOKE OK' : 'SMOKE FAILED'}`);
  app.exit(failed === 0 && problems.length === 0 ? 0 : 1);
});
