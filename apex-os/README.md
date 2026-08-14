# APEX OS — desktop app

Internal command centre for Precision Summit Tech / AJTG. Four pages: Agent
Roster, Org Chart, Risk Desk, Super Brain.

This is the `dashboard/index_2.html` design, unchanged, running as a real
installable desktop application with the Risk Desk reading live data from
Supabase.

---

## ⚠️ One-time setup — you must create a Supabase Auth user first

**The app cannot sign in until you do this. The project currently has zero
auth users.**

Read access is granted to the `authenticated` role only. There is no anonymous
access at all (see "Security posture" below), so APEX OS needs a real account
to sign in with.

1. Open the Supabase dashboard → your project → **Authentication** → **Users**
2. **Add user** → **Create new user**
3. Email: `hmanue00@outlook.com` (or whichever you prefer)
4. Set a password. **Tick "Auto Confirm User"** — without it the account stays
   unconfirmed and sign-in fails with `Email not confirmed`.
5. Launch APEX OS and sign in with those credentials.

You pick the password and it is never stored in this repo. The session
persists in the app's own profile directory, so this is a once-per-machine
step, not once per launch.

---

## Run it

```bash
cd apex-os
npm install
npm start
```

## Build an installer

```bash
npm run dist          # current platform
npm run dist:mac      # .dmg  + .zip
npm run dist:win      # .exe  (NSIS installer)
npm run dist:linux    # .AppImage + .deb
```

Output lands in `apex-os/dist/`. Build on the platform you're targeting —
cross-compiling Electron apps needs extra toolchains and is not set up here.

### Windows: "Cannot create symbolic link : A required privilege is not held"

`npm run dist:win` can fail while unpacking `winCodeSign-2.6.0.7z`. That archive
carries macOS symlinks (`libcrypto.dylib`, `libssl.dylib`), and creating a
symlink on Windows needs a privilege standard accounts don't hold, so 7-Zip
exits 2 and electron-builder retries four times and gives up.

Note what this does *not* affect: the app is packaged before that step, so
`dist\win-unpacked\APEX OS.exe` already exists and runs. Only the installer is
missing.

electron-builder pulls that bundle down for code signing and for editing the
exe's icon/version resources. This build is unsigned and has no custom icon, so
none of it is needed:

```powershell
npm run dist:win:noadmin
```

That passes `-c.win.signAndEditExecutable=false`, which skips the winCodeSign
download entirely and builds the NSIS installer directly. No admin rights, no
Developer Mode.

The alternatives, if you'd rather keep the default path: turn on **Settings →
Privacy & security → For developers → Developer Mode** (grants symlink creation
to your normal account), or run the build from an Administrator PowerShell.
Either makes plain `npm run dist:win` work. Switch back to it if you ever add a
real icon or a signing certificate, since `dist:win:noadmin` skips embedding
both.

Note: `npm run dist` is unsigned. macOS Gatekeeper will need a right-click →
Open on first launch, and Windows SmartScreen will warn. Code signing needs
certificates you'd have to buy; for a single-operator internal tool that's
usually not worth it.

## Smoke test

```bash
npx electron scripts/smoke.js          # or: xvfb-run -a npx electron scripts/smoke.js --no-sandbox
```

Boots the app headless and asserts the UI rendered, the vendored bundles
loaded under the production CSP, and the sign-in gate is blocking the data.
It does not sign in — there are no test credentials.

---

## Security posture

The important thing to understand: **the anon key shipped in this app grants
nothing.**

RLS was already enabled on all 12 tables in this project, but zero policies
had ever been created — which in Postgres means deny-all. That was invisible
because server-side tooling uses the `service_role` key, which bypasses RLS.
The first client to actually try reading would have got back empty arrays.

`schemas/postgres/018_rls_authenticated_read_policies.sql` fixes that, and does
so in the tightest way that still lets the app work:

| Role | Read | Write |
| --- | --- | --- |
| `anon` (the key in this app) | **nothing** — no grants, no policies | nothing |
| `authenticated` (you, signed in) | SELECT on all 12 tables | **nothing** |
| `service_role` (server-side only, never shipped here) | everything | everything |

Consequences worth being explicit about:

- **Extracting the key from the app binary gets an attacker nothing.** Without
  a valid Auth session, every query returns permission denied. This is why the
  sign-in screen exists.
- **This app has no write path to any table.** Not "we chose not to write" —
  there is no policy that would permit it. That holds the repo's standing
  constraint that nothing here can place, modify, or cancel an order, and it
  keeps `risk_violations` / `decisions` intact as append-only audit trails.
- **Never put a `service_role` key in this app.** It bypasses RLS entirely.
  `electron/config.js` takes the anon key only.

Hardening in the app itself:

- `contextIsolation: true`, `nodeIntegration: false`, `sandbox: true`
- The preload exposes exactly one thing — the Supabase URL and anon key. There
  is no IPC surface, no filesystem access, no shell access.
- A CSP allows connections to the Supabase project host and nowhere else.
  `script-src` is `'self'` — no inline script, no eval.
- All permission requests (camera, mic, geolocation, …) are refused.
- External links open in the system browser; in-window navigation off `file://`
  is blocked.
- **No third-party network calls.** JetBrains Mono is bundled rather than
  fetched from Google Fonts, which the original HTML did on every load. APEX OS
  talks to exactly one host: your Supabase project.

### If you ever add a second user

The policies are `USING (true)` — every signed-in user reads every row, because
there is currently one operator and no per-user ownership column to filter on.
Narrow the policies **before** creating a second account, not after. Granting
first and narrowing later exposes everything in between.

---

## What's real vs. illustrative

Task 3 of the brief. The app labels this in the UI itself — `LIVE · SUPABASE`
tags on real data, `ILLUSTRATIVE` tags on everything else — so you don't have
to remember. Summary:

### Real (read live from Supabase on every load)

- **Risk Desk, in full.** Account list, broker, role, type, balance, equity,
  and every risk limit come from `accounts` + `risk_limits`. The account
  selector is populated from the query, not a hardcoded array. The "limits last
  updated" timestamp is the real `updated_at`.

### Real, but static (design decisions recorded in this repo, not measurements)

- The 15 agent definitions: names, roles, reporting lines, tool assignments.
- The 10 departments and the org tree structure.
- The escalation procedure text on the Risk Desk.

### Illustrative — hardcoded, not measured

- **Every agent "last check" line.** There is no agent runtime. Nothing has
  ever run. Tagged `ILLUSTRATIVE` on each card.
- **Agent status dots and the "live agents" counter.** These describe design
  status, not running processes.
- **"Open risk flags: 0" and "Scheduled reports/day: 4"** in the stat row.
- **The 185 placeholder roles.** Phase 4 organizational placeholders — titles
  defined, no backend.
- **The entire Super Brain page.** No ingest CLI, no embedding service, no
  pgvector index, no knowledge vault. The health scores (79/100, 57), storage
  layer states, folder counts, doctor checks, query path and constellation are
  all hand-authored. The page carries a standing banner saying so.
- **Org Chart asset-coverage filters** (forex/equities/commodities dots).
- **The broadcast bar and per-agent chat inputs** — disabled, no backend.

### Deliberately absent

Correlation exposure and news-blackout checks are out of scope per founder
direction. The correlation row on the Risk Desk reads "not evaluated" and
renders whatever the database holds (currently NULL) rather than inventing a
number. The escalation text was corrected to stop claiming a correlation check
happens.

---

## Layout

```
apex-os/
  electron/
    main.js        window, CSP, navigation lockdown, permission refusal
    preload.js     sandboxed; bridges config only
    config.js      Supabase URL + anon key (env-overridable)
  renderer/
    index.html     UI shell + sign-in gate
    styles.css     approved stylesheet, verbatim, + additive sections
    data.js        Supabase client, auth, the accounts+risk_limits query
    app.js         page rendering
    vendor/        generated by `npm run vendor` — not committed
  scripts/
    vendor.mjs     bundles supabase-js, copies the font
    smoke.js       headless boot test
```

## Configuration

Defaults are baked into `electron/config.js`. Override without editing tracked
source:

```bash
export APEX_SUPABASE_URL="https://<ref>.supabase.co"
export APEX_SUPABASE_ANON_KEY="<anon key>"
npm start
```
