# Operating notes for Claude Code sessions in this repo

Read this first. Then read `README.md` for architecture, and
`docs/decision-log/` for what's already been decided (don't re-litigate)
and what's still open (needs founder input, don't guess).

## Non-negotiable constraints

1. **No execution code.** Nothing in this repo should be able to place,
   modify, or cancel a real order. `proposed_trades` and `trades` are
   separate tables specifically to enforce this at the schema level — a
   trade only exists once a human has placed it (or, far in the future,
   an explicitly authorized automation does so for a specifically proven
   strategy). If a task seems to require execution code, stop and confirm
   with the founder rather than assuming it's now in scope.
2. **No marketplace-installed skills for anything execution-adjacent.**
   OpenClaw and similar frameworks are approved for research/monitoring
   agents only (see `docs/decision-log/0001-...md`). Anything touching
   brokerage credentials is hand-written in this repo and reviewed
   line-by-line.
3. **Risk limits gate everything.** Any new agent or workflow that
   produces trade signals must route through `/scripts/risk/validate_trade.py`
   (or its future equivalent) before a signal can reach human approval.
   Don't build a shortcut around it, even for testing — use paper accounts
   and the mock data provider instead.
4. **Append-only where it matters.** `risk_violations` and `decisions` are
   audit trails. Don't UPDATE or DELETE rows there; add new rows instead.
5. **Schema changes are additive.** Add a new numbered file in
   `/schemas/postgres/`, don't rewrite an applied one.

## When something is ambiguous

Check `docs/decision-log/OPEN-QUESTIONS.md` first — if it's listed there,
it's a known gap, not an oversight. Don't silently pick a default for
broker, data vendor, or capital amount; surface the question instead.
For smaller implementation ambiguities, pick the most conservative
option (favoring capital preservation and auditability) and state the
assumption clearly rather than blocking.

## Where things live

- Agent definitions: `/agents/<department>/`
- SOPs (human-readable process docs): `/sops/`
- DB schema: `/schemas/postgres/` (run via `/scripts/db/migrate.sh`)
- Risk validation code: `/scripts/risk/`
- MCP servers: `/mcp-servers/` (read-only market data is the only one so far)
- n8n workflow exports: `/n8n-workflows/`
- Generated reports: `/docs/reports/`
- Decision history: `/docs/decision-log/` (markdown) and the `decisions`
  Postgres table (structured/queryable)

## Current phase

**Phase 1** (repo scaffolding, Postgres schema, one read-only MCP server)
is largely complete as of the initial scaffold. Phase 2 next: build the
first vertical slice — a daily research agent, human-in-the-loop, with the
risk validation gate wired into a real (paper) account.
