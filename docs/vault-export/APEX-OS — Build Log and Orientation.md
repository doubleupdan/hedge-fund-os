---
title: APEX OS — Build Log and Orientation
created: 2026-08-15
source-repo: doubleupdan/hedge-fund-os
audience: Claude agents (maghbu, maxxus) and future sessions
status: current
tags: [apex-os, hedge-fund-os, orientation, build-log, risk, supabase]
---

# APEX OS — Build Log and Orientation

**Read this before touching anything in `hedge-fund-os`.** It covers what was
built on 2026-08-14/15, where everything lives, what is real versus decorative,
and the constraints that are not negotiable.

---

## 1. Orientation in 60 seconds

**APEX OS** is the internal command centre for Precision Summit Tech / AJTG. It
is an **Electron desktop app** with four pages: Agent Roster, Org Chart, Risk
Desk, Super Brain.

It is a **read-only dashboard**. It cannot write to the database and it cannot
place, modify, or cancel an order. That is enforced by database policy, not by
convention — see §4.

Three things to internalise immediately:

1. **There are two Supabase projects.** Do not confuse them. See §3.
2. **Most of the UI is illustrative, not measured.** Do not cite numbers off it
   as fact. See §5.
3. **No agent runtime exists.** All 15 "agents" in the roster are *definitions*.
   Nothing runs. Nothing has ever run.

---

## 2. What was built

| | |
| --- | --- |
| **Before** | `dashboard/index_2.html` — a single static HTML mockup with all data hardcoded in JS arrays, including a hand-copied snapshot of the real accounts |
| **After** | A real installable desktop app whose Risk Desk reads live from Supabase under an authenticated session |

Specifically:

- **Electron app** at `apex-os/`, chosen over a Next.js port. Reasoning in
  decision log 0005 — short version: the approved design is the asset and a
  component rewrite mainly risks losing it, and Next.js would add a server-side
  execution surface to a repo whose first rule is that nothing can reach an order.
- **Risk Desk is live.** The hardcoded `ACCOUNTS` array is deleted. Accounts,
  brokers, roles, balances and every risk limit come from `accounts` +
  `risk_limits` per query.
- **RLS lockdown** — migration 018. This was the big finding; see §4.
- **Sign-in gate**, because anonymous access now reads nothing.
- **Provenance labelling** throughout the UI so fake data cannot be mistaken for
  real. See §5.
- **Generated app icon**, funding SOP, decision log 0005.

Verified on the founder's Windows machine: sign-in works, all six accounts load
with their own distinct limits, `dist:win` produces a working installer.

---

## 3. ⚠️ Two Supabase projects — do not mix them up

| Project | Ref | Region | What it is |
| --- | --- | --- | --- |
| **hedge-fund-os** | `fhdxzdpaigxzknhjvvfo` | us-west-2 | ✅ The trading/fund database. APEX OS reads this. All 18 migrations. |
| **maghbu-os** | `qvfamiopoifkxwdotafx` | ap-southeast-1 | ❌ Unrelated. Not touched by any of this work. |

Both are in the same Supabase org, so they appear side by side in any project
list. **Always pass the project ref explicitly.** Writing fund data into
`maghbu-os`, or worse, running a fund migration against it, would be a genuine
mess to unpick.

---

## 4. Security posture — read fully before touching auth

### What was found

RLS was **enabled on all 12 tables with zero policies**. In Postgres that means
deny-all. It had gone unnoticed because every tool up to that point used the
`service_role` key, which bypasses RLS entirely. The first client app to try
reading would have received **empty arrays, not an error** — a silent failure.

### What was decided

The founder chose maximum privacy (their words: *"as much privacy as possible
with all this since a lot of it is personal"*). Migration 018 implements:

| Role | Read | Write |
| --- | --- | --- |
| `anon` — the key shipped inside the app | **nothing** (no grants, no policies) | nothing |
| `authenticated` — signed-in session | SELECT on all 12 tables | **nothing** |
| `service_role` — server-side only | everything | everything |

Consequences an agent must not undo:

- **The anon key in `apex-os/electron/config.js` is not a secret and grants
  nothing.** Extracting it gets you zero rows. Do not "fix" this by adding anon
  policies.
- **No INSERT/UPDATE/DELETE policy exists for any client role.** This is the
  mechanism that keeps `risk_violations` and `decisions` append-only in practice,
  and a second lock on the no-execution rule. Do not add write policies to make
  something convenient.
- **Never put a `service_role` key in the desktop app** or any client-side code.

### The `USING (true)` caveat — and why it does *not* currently apply to you

The policies grant every signed-in user every row, because there is one operator
and no per-user ownership column to filter on.

**maghbu and maxxus run on the founder's machine and use the founder's existing
credentials and session.** No second Supabase identity exists, so nothing is
over-exposed today.

That changes the moment anyone creates a *separate* login for an agent or a
second human. **If that is ever proposed: narrow the policies first, before the
account exists.** Creating the account and narrowing afterwards exposes every
row in the interim. There is currently no ownership column to scope by, so
scoping means designing one — that is a real task, not a config tweak.

---

## 5. What is REAL vs ILLUSTRATIVE

**This is the section that matters most for an agent.** Reporting an
illustrative number as fact would be a serious error, especially in a risk
context. The UI tags these inline (`LIVE · SUPABASE` vs `ILLUSTRATIVE`), but
here it is explicitly.

### Real — read live from the database

- **The entire Risk Desk.** Account list, broker, role, account type, balance,
  equity, and every risk limit. The "limits last updated" stamp is the real
  `updated_at`.

### Real, but static — design decisions recorded in the repo, not measurements

- The 15 agent definitions: names, roles, reporting lines, tool assignments.
- The 10 departments and the org tree.
- The escalation procedure text.

### ILLUSTRATIVE — hardcoded, never measured. Do not cite.

- **Every agent "last check" line.** No agent runtime exists. Nothing has run.
- **Agent status dots and the "live agents" counter** — design status, not process state.
- **"Open risk flags: 0"** and **"Scheduled reports/day: 4"**.
- **The 185 placeholder roles** — Phase 4 organisational placeholders.
- **The entire Super Brain page.** There is no ingest CLI, no embedding service,
  no pgvector index and no knowledge vault in the repo. The health scores
  (79/100, 57), storage-layer states, folder counts, doctor checks, query path
  and constellation are all hand-authored.
- **Org Chart asset-coverage filters** (forex/equities/commodities dots).
- **Broadcast bar and per-agent chat inputs** — disabled, no backend.

### Deliberately absent — do not build without being asked

Correlation exposure and news-blackout checks are **explicitly out of scope** by
founder direction. They are not stubs awaiting implementation. The Risk Desk
shows "not evaluated" and renders the NULL the database holds rather than
inventing a value.

---

## 6. Where things live

```
hedge-fund-os/
  CLAUDE.md                    ← non-negotiable constraints. Read first.
  apex-os/                     ← the desktop app
    electron/main.js           window, CSP, navigation lockdown
    electron/config.js         Supabase URL + anon key (env-overridable)
    electron/preload.js        sandboxed; bridges config only, no IPC surface
    renderer/index.html        UI shell + sign-in gate
    renderer/styles.css        approved stylesheet, verbatim + additions
    renderer/data.js           ← Supabase client, auth, the accounts query
    renderer/app.js            page rendering
    scripts/make-icon.mjs      generates the app icon from code
    scripts/smoke.js           headless boot test, 14 assertions
    build/icon.png|.ico        generated, committed
  dashboard/index_2.html       original mockup, superseded, kept as design reference
  schemas/postgres/            18 migrations, additive only
    018_rls_...sql             ← the security posture
  scripts/risk/validate_trade.py   ← what actually enforces risk limits
  sops/operations/funding-an-account.md   ← deposit procedure
  sops/risk/risk-validation-gate.md
  docs/decision-log/0005-...   ← full reasoning for all of the above
  docs/decision-log/OPEN-QUESTIONS.md
  ea-source/                   real MT5 EA source (v7.5)
```

**Start with `CLAUDE.md`, then `docs/decision-log/`.** The decision log records
what is already settled — do not re-litigate it — and `OPEN-QUESTIONS.md`
records what genuinely needs founder input, so do not guess at those.

---

## 7. Hard constraints (from CLAUDE.md — these are not suggestions)

1. **No execution code.** Nothing may place, modify, or cancel a real order.
   `proposed_trades` and `trades` are separate tables to enforce this at the
   schema level — a trade exists only once a human has placed it.
2. **No marketplace-installed skills for anything execution-adjacent.**
3. **Risk limits gate everything.** Any new trade signal must route through
   `scripts/risk/validate_trade.py`. Do not build a shortcut around it, even for
   testing — use paper accounts and the mock provider.
4. **Append-only where it matters.** Never UPDATE or DELETE in `risk_violations`
   or `decisions`. Add rows.
5. **Schema changes are additive.** New numbered file in `schemas/postgres/`.
   Never rewrite an applied one.

Two hard rules are already **code-enforced** in `validate_trade.py`:

- **Zero Tolerance Rule** — RSI exactly 60 on a SELL signal is a hard invalid
  trade, no exceptions.
- **Checklist discipline** — all required confirmations checked, or the trade is
  rejected.

Only the **AJTG Trendline Strategy** is approved for real fund trading. Volume
Profile, Jstew and ASAITA are placeholder rows — not ready, not active.

Note the strategy has two intentional, distinct variants that are **not** a
conflict: `presentation_method` (discretionary — RSI 50-54 buys / 50-46 sells)
and `ea_automation_layer` (the EA's own — RSI 50-55 buys / 45-50 sells,
confirmed against the real v7.5 EA source).

---

## 8. Open items

- **Account funding.** All five live accounts sit at **$0.00**. The
  percentage-based limits are structural until funded — they constrain nothing
  yet. Procedure: `sops/operations/funding-an-account.md`. Note the important
  bit: updating `accounts.current_balance` alone is wrong, because
  `account_snapshots` is the append-only source drawdown is computed from.
- **AJTG Flip Account (48830)** funds at **$150** before market open Sunday
  2026-08-16. At 10% position risk that is **$15 max risk per trade**, halt at
  $112.50. **That $15 figure should be sanity-checked against real lot sizing
  before the first trade** — the 10% was derived from an assumed 150-pip stop at
  $1/pip on 0.01 lot XAUUSD.
- **No agent runtime.** Building one is unstarted work, not a wiring task.
- **Super Brain is entirely unbuilt** behind the visuals.

---

## 9. Running it

```powershell
cd apex-os
npm install
npm start                 # dev
npm run dist:win          # Windows installer -> dist\APEX OS Setup 0.1.0.exe
npx electron scripts/smoke.js    # 14-assertion headless test
```

**Windows gotcha:** `dist:win` fails on a standard account while unpacking
`winCodeSign-2.6.0.7z` (it contains macOS symlinks; creating symlinks needs a
privilege standard accounts lack). Fix: enable **Developer Mode**
(`start ms-settings:developers`). The `dist:win:noadmin` fallback works but
skips `rcedit`, so the exe keeps the default Electron icon.

Sign-in requires a Supabase Auth user to exist — one was created in the
dashboard for `hmanue00@outlook.com`. Sessions persist per machine.

---

## 10. Related notes

- [[Decision Log 0005 — APEX OS desktop app]] — full reasoning, alternatives considered
- [[SOP — Recording a deposit or balance change]]
- [[Migration 018 — RLS authenticated read policies]]

*Canonical source for all of the above is the `hedge-fund-os` git repo. If this
note and the repo disagree, the repo is right — check
`docs/decision-log/0005-apex-os-desktop-app.md`.*
