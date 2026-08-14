'use strict';

/**
 * Sandboxed preload. Its only job is to hand the renderer its Supabase
 * connection config across the context bridge.
 *
 * Nothing else is exposed: no IPC surface, no filesystem, no shell. The
 * renderer talks to Supabase directly over HTTPS using supabase-js, so there
 * is no reason to give it a privileged channel back into the main process —
 * and every such channel is another thing to get wrong.
 */

const { contextBridge } = require('electron');

function readConfig() {
  const arg = process.argv.find((a) => a.startsWith('--apex-config='));
  if (!arg) return null;
  try {
    return JSON.parse(
      Buffer.from(arg.slice('--apex-config='.length), 'base64').toString('utf8')
    );
  } catch {
    return null;
  }
}

contextBridge.exposeInMainWorld('APEX_CONFIG', readConfig());
