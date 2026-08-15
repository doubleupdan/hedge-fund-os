# 0005 — APEX OS as an Electron desktop app, gated behind Supabase Auth

**Date:** 2026-08-14
**Status:** Accepted — implemented and verified on the founder's machine 2026-08-15
**Supersedes:** nothing
**Related:** `schemas/postgres/018_rls_authenticated_read_policies.sql`, `apex-os/`,
`sops/operations/funding-an-account.md`

---

## Context

`dashboard/index_2.html` was a single-file, static HTML/CSS/JS mockup of APEX OS
— the internal command centre (Agent Roster, Org Chart, Risk Desk, Super Brain).
Its visual design had already been iterated on and approved. All of its data was
hardcoded JavaScript arrays, including a hand-copied snapshot of the five real
trading accounts and their risk limits.

The brief was to turn it into a real installable desktop app with the Risk Desk
reading live Supabase data, and to decide between two architectures.

## Decision 1 — Electron wrapper (Option A), not a Next.js port (Option B)

**Chosen: Option A.** The existing UI moves into an Electron shell essentially
as-is and talks to Supabase directly from the renderer.

Reasoning:

1. **The design is the asset, and a port is the main way to lose it.** The
   approved artefact is 640 lines of hand-tuned CSS and DOM-string rendering.
   Re-expressing that as React components is a large diff whose *best* possible
   outcome is "looks exactly the same". Every hour spent on it is an hour spent
   risking the one thing explicitly marked as not-to-be-changed.

2. **Next.js is a server, and this system's defining constraint is that it
   cannot execute.** Option B would introduce `app/api/*` routes — a server-side
   execution surface holding credentials, sitting inside a repo whose first
   non-negotiable rule is that nothing in it can place, modify, or cancel an
   order. The Electron build has no server, no API routes, and (after migration
   018) no database write path at all. The architecture enforces the constraint
   instead of documenting it.

3. **What the app actually does today is read four tables and draw them.** That
   does not need SSR, routing, a build pipeline, or a component framework.

4. **FounderOS-DEMO's value here was structural, not code to import.** Its
   business logic is for an unrelated personal-brand project and was explicitly
   out of bounds. What it demonstrated — how an agent/brain/org backend is
   organised — is a Phase 4 concern, not a Phase 2 one.

**What Option A costs, honestly:** if APEX OS later needs server-side work
(scheduled agent runs, secrets that can't ship to a client, multi-user access),
that logic will need somewhere to live, and Electron gives it no natural home.
The mitigation is that this decision is cheap to revisit: the data layer is
isolated in `renderer/data.js`, so a future backend means swapping that file's
implementation, not rewriting the UI. The UI never learns where its data came
from.

## Decision 2 — authenticated-only access, no anonymous reads

Investigating the live project surfaced a latent problem: **RLS was enabled on
all 12 tables with zero policies.** In Postgres that is deny-all. It had gone
unnoticed because all tooling to date used the `service_role` key, which
bypasses RLS entirely. The first client app to try reading would have received
empty arrays — not an error, just silently nothing.

So policies had to be written, which forced the real question: read access for
whom?

A desktop app ships its key inside the installed bundle. Anything readable by
`anon` is therefore readable by anyone who unpacks the app — effectively public.
The data in question is real account numbers, brokers, balances and per-account
risk limits.

**Decision: no `anon` access of any kind. Read requires a Supabase Auth
session.** APEX OS presents a sign-in screen; the session persists per machine.
The founder's stated preference was maximum privacy, and this data is personal.

Migration 018 implements this:

- SELECT policies for `authenticated` only, on all 12 tables.
- No policy of any kind for `anon`; table grants revoked from it as well, so it
  is rejected at the privilege layer before RLS is consulted.
- **No INSERT/UPDATE/DELETE policy for any role.** The client cannot write. This
  is what keeps `risk_violations` and `decisions` append-only in practice rather
  than by convention, and it is a second, independent lock on the no-execution
  rule.
- Default privileges set so future tables inherit the same posture instead of
  silently starting open.

### Known limitation

The policies are `USING (true)` — any authenticated user reads every row. There
is one operator and no per-user ownership column to filter on, so row-level
scoping would be inventing a data model that doesn't exist. **If a second human
or a scoped agent identity is ever added, narrow the policies first.** Creating
the account and narrowing afterwards exposes everything in the interim.

## Decision 3 — label illustrative data in the UI, don't quietly drop it

Most of APEX OS is not backed by anything: there is no agent runtime, so no
agent has ever run, and the entire Super Brain page describes infrastructure
that does not exist. The mockup rendered plausible-looking run summaries and
health scores that could be mistaken for measurements.

Three options were available: delete the unbacked UI, leave it as-is, or keep it
and mark it. **Marking it was chosen** — the illustrative pages communicate
intent and are useful for that, but a dashboard that shows invented numbers
indistinguishably from real ones is actively dangerous in a risk context.

Implementation: `LIVE · SUPABASE` and `ILLUSTRATIVE` tags rendered inline,
standing banners on the two mostly-illustrative pages, and non-functional
controls disabled with explanatory tooltips rather than left looking operational.
`apex-os/README.md` carries the full inventory.

One factual correction was made to page copy while doing this: the Risk Desk
escalation text claimed a correlation-exposure check. Correlation is explicitly
out of scope, so the sentence was corrected rather than left asserting a control
that does not and will not exist.

## Consequences

- APEX OS is installable via `npm run dist` (dmg / NSIS / AppImage + deb).
- The Risk Desk is live. The hardcoded `ACCOUNTS` array is deleted.
- The app makes no third-party network calls — JetBrains Mono is bundled rather
  than fetched from Google Fonts on every launch.
- Builds are unsigned; first launch needs a Gatekeeper/SmartScreen bypass.
- The app icon is generated from code (`npm run icon`) rather than committed as
  an opaque binary, and reuses the UI's own "spark" glyph coordinates so the two
  cannot drift apart.

### Windows build requires Developer Mode

`npm run dist:win` unpacks `winCodeSign-2.6.0.7z`, which contains macOS symlinks.
Creating a symlink on Windows needs a privilege standard accounts do not hold,
so the build fails at that step (the app itself packages first — only the
installer is lost). Fix is **Settings → System → For developers → Developer
Mode**, or an Administrator shell.

`npm run dist:win:noadmin` exists as a fallback and skips the download entirely,
but it also skips `rcedit`, so the exe keeps the default Electron icon. Now that
there is a real icon, Developer Mode is the preferred path.

## Verification (2026-08-14/15)

Confirmed working on the founder's Windows machine, not just in CI:

- Supabase Auth user created in the dashboard; sign-in succeeds.
- Risk Desk loads all six accounts (five live + one paper) and renders each
  account's own limits — verified by switching accounts and watching the values
  change, which is what distinguishes a live query from a replayed array.
- `npm run dist:win` completes with Developer Mode enabled; the icon is embedded
  (the `default Electron icon is used` warning disappears) and
  `dist\APEX OS Setup 0.1.0.exe` is produced.

Headless smoke test (`scripts/smoke.js`, 14 assertions) passes with no console
errors or CSP violations.

## Follow-ups (not done here)

- Populate real balances. All five live accounts sit at $0.00, so the
  percentage-based limits are structural until funded — the Risk Desk says so
  per-account rather than implying the limits are active.
- The AJTG Flip Account's $150 starting capital is rendered as an explicitly
  labelled founder note, not written into the balance field. The note is tied to
  `balance === 0` so it clears itself once real money is recorded. Procedure for
  recording it: `sops/operations/funding-an-account.md`. **The $15/trade figure
  this implies (10% of $150) should be sanity-checked against real lot sizing
  before the first trade** — the 10% was derived from an assumed 150-pip stop at
  $1/pip on 0.01 lot XAUUSD, and if the real stop differs, `risk_limits` should
  be corrected before trading rather than after.
- No agent runtime exists. All 15 agents are defined but none run, and the entire
  Super Brain page is illustrative. Both are labelled in the UI; neither is built.
