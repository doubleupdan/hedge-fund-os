# Decision 0001: Core Architecture & Build Sequence

**Date:** 2026-08-07
**Status:** Decided
**Owner:** Founder + Chief AI Operating Partner

## Decision

Rejected two alternative architectures before settling on this one:

1. **"Three separate Claude Projects"** (Executive / Trading / Engineering) —
   rejected because it fragments state across three chat contexts with no
   shared source of truth, and duplicates coordination overhead that a repo
   + database already solves natively.
2. **"Nine department Claude Projects"** — rejected for the same reason at
   greater scale; more fragmentation, not less.

**Chosen architecture:** one repo-based system.

- **Claude Code** is the builder/operator, working directly against the repo.
- **MCP servers** are the tool and data layer. Read-only market data first;
  execution-capable servers only much later, hand-reviewed, never installed
  from a marketplace.
- **n8n** is the scheduler and delivery layer (reports, alerts). It does not
  own trading logic.
- **Postgres** is the single source of truth (accounts, trades, research
  notes, decision log, risk limits).
- **Obsidian** is optional, a human-readable graph layered on top of
  Postgres — not a second source of truth.

## OpenClaw

Investigated as a candidate execution/agent framework. Findings:

- General-purpose open-source agent framework, 250k+ GitHub stars.
- NOT a vetted trading platform.
- Marketplace has 13,700+ skills; ~311 finance-related; all community-built
  and unvetted.

**Decision:** OpenClaw is approved for research/monitoring agents only. It
is explicitly **not** approved for execution or for anything holding live
brokerage credentials. The execution path is custom-built in this repo,
reviewed line-by-line, never installed from a skill marketplace.

## Governing principle

"AI never touches your money — it generates deterministic signals/scripts;
a human or an explicit, separately-audited approval gate controls the
switch." Execution stays gated behind human approval until a real track
record exists under live (or paper) conditions.

## Build sequence

| Phase | Scope |
|---|---|
| 1 | Repo scaffolding, Postgres schema (accounts, trades, research notes, decision log, risk limits), one read-only market-data MCP server |
| 2 | One vertical slice, human-in-the-loop: daily research agent → report → n8n delivery. Risk rules as literal validating code gating every proposed trade. Paper trading before real capital |
| 3 | Automate the loop: open/midday/close/weekly reports, read-only broker pull for auto trade journaling. Execution remains human-approved |
| 4 | Specialized department agents (macro, technical, portfolio optimizer) as scoped Claude Code subagent sessions reporting into the executive decision log |

## Open questions (tracked separately)

See `OPEN-QUESTIONS.md` in this directory.
