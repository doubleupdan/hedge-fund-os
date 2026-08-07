# Hedge Fund OS

An AI-native operating system for a founding-stage hedge fund. Built as a single
repo-based system — not a chat assistant bolted onto spreadsheets.

## Core philosophy

1. **Capital preservation > risk-adjusted returns > process over emotion.**
2. **Automation only after a human-validated loop exists.** Nothing graduates
   from manual to automatic without a track record.
3. **AI never touches money.** Agents generate deterministic signals, reports,
   and scripts. A human (or an explicit, separately-audited approval gate)
   controls the switch that sends anything to a broker.
4. **Everything is documented, everything is queryable.** Postgres is the
   source of truth. Nothing valuable is lost to a chat transcript.

## Architecture

```
                    ┌─────────────────────┐
                    │   Claude Code        │  ← the builder / operator
                    │   (this repo)         │
                    └──────────┬────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                       │
 ┌──────▼──────┐      ┌────────▼────────┐     ┌────────▼────────┐
 │ MCP servers  │      │   Postgres       │     │   n8n            │
 │ (data/tools) │◄────►│  (source of      │◄───►│  (scheduler /    │
 │ read-only    │      │   truth)         │     │   delivery)      │
 │ first        │      │                  │     │                  │
 └──────────────┘      └──────────────────┘     └──────────────────┘
                               │
                    ┌──────────▼───────────┐
                    │  Obsidian (optional)  │  ← human-readable view
                    │  on top of Postgres   │     on top of the DB
                    └───────────────────────┘
```

- **Claude Code** is the builder and, later, the orchestrator of scoped
  subagent sessions (Phase 4).
- **MCP servers** are the tool/data layer. Read-only market data first.
  Execution-capable servers come much later and are hand-reviewed line by
  line — never installed from a marketplace.
- **Postgres** is the single source of truth: accounts, trades, research
  notes, decision log, risk limits, risk violations.
- **n8n** handles scheduling and delivery (reports, alerts) — it does not
  hold trading logic itself.
- **Obsidian** is an optional, human-readable window over the same data —
  not a second source of truth.

## Why not OpenClaw for execution

OpenClaw is a capable general-purpose open-source agent framework, but its
skill marketplace is community-built and unvetted (~311 finance-related
skills out of 13,700+, none audited). It is approved for **research and
monitoring agents only**. Anything that touches live brokerage credentials
or sends orders is custom-built in this repo, reviewed line-by-line, and
never installed from a marketplace skill.

## Build sequence

- **Phase 1** (this phase): repo scaffolding, Postgres schema, one read-only
  market-data MCP server.
- **Phase 2**: one vertical slice, human-in-the-loop — daily research agent
  → report → n8n delivery. Risk rules as literal validating code gating
  every proposed trade. Paper trading before real capital.
- **Phase 3**: automate the loop (open/midday/close/weekly reports,
  read-only broker pull for auto trade journaling). Execution stays
  human-approved.
- **Phase 4**: specialized department agents (macro, technical, portfolio
  optimizer) as scoped Claude Code subagent sessions reporting into the
  executive decision log.

## Repo layout

```
/agents            Agent definitions & prompts, one subfolder per department
/sops               Standard Operating Procedures (human-readable, versioned)
/schemas            Postgres DDL + JSON Schema validation contracts
/scripts            Risk validation, DB utilities, operational scripts
/mcp-servers        MCP server implementations (read-only first)
/n8n-workflows      Exported n8n workflow JSON, organized by phase
/docs/decision-log  One markdown file per significant decision (immutable)
/docs/reports       Generated reports: daily / weekly / monthly / quarterly / yearly
```

## Status

**Phase 1 in progress.** See `/docs/decision-log` for what's been decided and
`/docs/decision-log/OPEN-QUESTIONS.md` for what's still pending founder input.
