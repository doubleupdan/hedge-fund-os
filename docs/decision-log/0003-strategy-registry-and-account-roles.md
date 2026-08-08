# Decision 0003: Strategy registry + master/follower account structure

**Date:** 2026-08-08
**Status:** Decided
**Owner:** Founder + Chief AI Operating Partner

## Context

Two related gaps surfaced once real AJTG/Precision Summit material was
brought into the system (via a separate "AJTG folder memory chat"
conversation that had inventoried the AJTG Google Drive export):

1. Strategies existed only as free-text tags (`strategy_tag` on
   `proposed_trades`/`trades`) with no structured definition, no version
   history, and no single place answering "what are the rules for this
   strategy and what's its current status."
2. `accounts` treated every account as a flat, independent peer. The
   fund's actual operating model is copy trading: **one master account**
   Precision Summit has full legal access to and trades directly;
   participants' own accounts **connect to and mirror** that master.
   Precision Summit never takes custody of or holds login access to
   participant funds — this is the specific mechanism that keeps the
   fund clear of managed-money legal liability. The prior schema had no
   way to represent this distinction.

## Decision

**Strategy registry (`005_strategies.sql`):** added `strategies` as a
first-class, versioned table. Rule detail is stored as a mix of
structured JSON (`risk_parameters`) and free text (`entry_rules`,
`exit_rules`, etc.) rather than rigid columns, because rule shapes differ
too much between strategies (a 7-state signal machine vs. a
volume-profile read) to force into one layout. `status` follows a
lifecycle (`not_yet_documented` → `documented` → `backtesting` →
`paper_trading` → `live` → `restricted`/`paused`/`retired`) rather than a
simple boolean, since "is this strategy allowed to trade" is not binary.

Performance is deliberately NOT duplicated into this table — it's derived
by querying `trades`/`proposed_trades` where `strategy_id` matches. This
table is strategy *definition*, not strategy *performance*.

Seeded with the two strategies that had real source material:
- **AJTG Trendline Trading Strategy** (v3.0) — extracted from actual EA
  source code: 7-state signal machine, Gold-specific SL/TP pip values,
  25/25/25/25 partial-close sequence, RSI filter, Smart Money
  Concepts/ICT framework. Status: `backtesting` (matches current real
  activity — swing version, XAUUSD only).
- **Volume Profile Trading System** (v1.0) — PDF-only, less detail
  available. Status: `documented` (not yet backtesting).

Two additional strategies named in conversation but without source
material (**Jstew Strategy**, **ASAITA**) were inserted as honest
placeholder rows — `status = 'not_yet_documented'`, summary states
plainly that no materials exist yet. This was a deliberate choice over
either omitting them (losing the fact that they're known to exist) or
inventing plausible-sounding detail (which would be actively misleading
data sitting in a risk-relevant system).

**Master/follower accounts (`006_master_follower_accounts.sql`):** added
`accounts.account_role` (`master` / `copy_follower` / `standalone`) and
`accounts.follows_account_id` (self-referencing FK, required for
followers, forbidden for master/standalone — enforced via CHECK
constraint). A `master_account_summary` view rolls up follower counts per
master account for quick reporting.

The `standalone` default preserves backward compatibility with the Phase
1 test account created in Step 7 — no existing data needed migration.

## Alternatives considered

- **JSON Schema files instead of a `strategies` table** — rejected;
  strategies need to be joined against trades for performance analysis,
  which is far more natural in the same relational database than in
  separate files.
- **Skip the master/follower distinction, model all accounts as peers**
  — rejected. This isn't just a data-modeling nicety: the master/follower
  split IS the legal structure that avoids managed-money liability. Not
  representing it in the schema would mean the system of record doesn't
  reflect the actual compliance boundary the fund operates inside.
- **Enforce "follower must follow a master, not another follower" via a
  DB trigger** — deferred. A CHECK constraint can't easily reference
  another row's column; a trigger is real but was judged more machinery
  than needed before any actual signal-generation code exists to test it
  against. Documented as an application-level responsibility for now
  (see comment in `006_master_follower_accounts.sql`), to revisit in
  Phase 2+ hardening.

## Consequences

- Any future signal-generation agent/script must only target `master`
  accounts when inserting into `proposed_trades` — this is currently an
  documented convention, not yet a hard DB constraint. Worth adding a
  trigger once real signal generation exists to validate against.
- The EA behind the Trendline Strategy (`AJTG_TrendlineStrategy_EA.mq5`)
  has **not** had a line-by-line human code review yet — flagged
  explicitly in `strategies.known_risk_flags`. Per `CLAUDE.md`'s
  non-negotiable constraints, this review is required before the EA is
  used for anything beyond backtesting.
- Real AJTG accounts (100076, 100892 "10x Acct," Prerequisites, Signal
  Demo) still need to be entered into `accounts` with explicit
  `account_role` values — not yet done as of this migration.
