# /schemas

## /schemas/postgres

The database schema — source of truth for the whole system. Files are
numbered and run in order by `/scripts/db/migrate.sh`. Never edit an
already-applied numbered file in a way that changes its meaning; add a new
numbered file instead (e.g. `004_...sql`) so history stays honest. This
mirrors why `risk_violations` and `decisions` are append-only tables.

Current files:
- `001_accounts_and_risk_limits.sql` — accounts, account_snapshots,
  risk_limits, risk_violations
- `002_trades.sql` — proposed_trades (signals, no capital effect) and
  trades (actual placed trades, paper or live)
- `003_research_and_decisions.sql` — research_notes (Super Brain
  ingestion), decisions (structured decision log)
- `004_trading_groups.sql` — trading_groups (e.g. "Average Joe Trading
  Group") and the accounts.trading_group_id link, since a single group
  manages multiple accounts under itself
- `005_strategies.sql` — strategies registry (strategy IP log): versioned
  strategy definitions, status lifecycle, risk parameters, linked to
  proposed_trades/trades via strategy_id. Seeded with AJTG Trendline
  Trading Strategy and Volume Profile Trading System.
- `006_master_follower_accounts.sql` — accounts.account_role
  (master/copy_follower/standalone) and accounts.follows_account_id, to
  reflect the actual copy-trading legal structure: one actively-traded
  master account, participant accounts mirror it, no custody taken.

## /schemas/validation

JSON Schema (or equivalent) contracts for validating data shapes at
integration boundaries — e.g. what an MCP tool's response must look like,
or what an n8n workflow must produce before writing to Postgres. Populated
starting Phase 2 as those integrations are built.
