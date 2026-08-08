-- =============================================================================
-- 004_trading_groups.sql
-- Phase 1 (addendum): Trading groups.
--
-- Gap this closes: accounts.owner was originally free-text, with no real
-- entity behind it. In practice, a single trading group (e.g. "Average Joe
-- Trading Group") manages MULTIPLE accounts under itself, and the hedge
-- fund has multiple such groups/traders. This migration introduces
-- trading_groups as a first-class entity and links accounts to it, so
-- group-level rollups (aggregate performance, aggregate risk exposure
-- across every account a group manages) become possible later without
-- another schema rework.
--
-- accounts.owner is kept (not dropped) for now as a human-readable label /
-- backward-compat field, but the authoritative relationship going forward
-- is accounts.trading_group_id -> trading_groups.id.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- trading_groups
-- One row per trading group/team (which may be a single trader operating
-- solo, or a team managing several accounts under one strategy umbrella).
-- -----------------------------------------------------------------------------
CREATE TABLE trading_groups (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_name           TEXT NOT NULL UNIQUE,        -- e.g. 'Average Joe Trading Group'
    lead_trader           TEXT NOT NULL,                -- primary point of contact / responsible party
    description             TEXT,
    strategy_summary          TEXT,                        -- brief description of the group's core strategy/approach

    -- Group-level permissions mirror account-level ones (schema
    -- 001_accounts_and_risk_limits.sql) — a group can be restricted to
    -- certain asset classes / strategies even before drilling into
    -- individual account permissions, which should be a subset of these.
    asset_permissions          TEXT[] NOT NULL DEFAULT '{}',
    strategy_permissions          TEXT[] NOT NULL DEFAULT '{}',

    is_active                       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE trading_groups IS 'A trading group/team that manages one or more accounts (schema: accounts.trading_group_id). Enables group-level performance and risk rollups across all accounts a group manages.';

-- -----------------------------------------------------------------------------
-- Link accounts -> trading_groups
-- Nullable by design: not every account needs to belong to a group (e.g. a
-- standalone account managed directly by fund leadership). Accounts that DO
-- belong to a group should set this; accounts.owner remains as a
-- human-readable label either way.
-- -----------------------------------------------------------------------------
ALTER TABLE accounts
    ADD COLUMN trading_group_id UUID REFERENCES trading_groups(id);

CREATE INDEX idx_accounts_trading_group ON accounts(trading_group_id);

COMMENT ON COLUMN accounts.trading_group_id IS 'Optional FK to trading_groups. NULL means this account is not managed under a group (e.g. directly by fund leadership).';

-- -----------------------------------------------------------------------------
-- Convenience view: group-level rollup of account balances/equity.
-- Read-only aggregate — does not replace per-account risk_limits, which
-- still gate individual trades. This view is for reporting/dashboards.
-- -----------------------------------------------------------------------------
CREATE VIEW trading_group_summary AS
SELECT
    tg.id                       AS trading_group_id,
    tg.group_name,
    tg.lead_trader,
    COUNT(a.id)                  AS account_count,
    COALESCE(SUM(a.current_balance), 0) AS total_balance,
    COALESCE(SUM(a.current_equity), 0)  AS total_equity,
    COALESCE(SUM(a.starting_balance), 0) AS total_starting_balance
FROM trading_groups tg
LEFT JOIN accounts a ON a.trading_group_id = tg.id AND a.is_active = TRUE
WHERE tg.is_active = TRUE
GROUP BY tg.id, tg.group_name, tg.lead_trader;

COMMENT ON VIEW trading_group_summary IS 'Aggregate balance/equity per active trading group across its active accounts. Recomputed on every query — fine at this scale, revisit as a materialized view if account counts grow large.';
