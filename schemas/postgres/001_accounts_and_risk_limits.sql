-- =============================================================================
-- 001_accounts_and_risk_limits.sql
-- Phase 1: Accounts and risk limits — foundation tables.
-- Every other table (trades, decision log) references accounts.id.
-- Risk limits are per-account, not global: a $5k account and a $500k
-- account should share percentage limits, not absolute-dollar limits.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------------------------
-- accounts
-- One row per trading account. Broker/platform intentionally free-text at
-- this stage (see docs/decision-log/OPEN-QUESTIONS.md #1) — constrain with a
-- CHECK or lookup table once the broker decision is made.
-- -----------------------------------------------------------------------------
CREATE TABLE accounts (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_name        TEXT NOT NULL UNIQUE,
    owner               TEXT NOT NULL,               -- trader/manager responsible
    broker              TEXT,                         -- e.g. 'IC Markets' — nullable until decided
    platform            TEXT NOT NULL DEFAULT 'MT5',  -- 'MT5', 'TradingView', etc.
    account_type        TEXT NOT NULL DEFAULT 'paper' -- 'paper' | 'live'
                             CHECK (account_type IN ('paper', 'live')),
    base_currency       TEXT NOT NULL DEFAULT 'USD',

    -- Balances. Kept here for convenience/latest-known-value; authoritative
    -- point-in-time history lives in account_snapshots (see below).
    starting_balance    NUMERIC(18,2) NOT NULL CHECK (starting_balance >= 0),
    current_balance     NUMERIC(18,2) NOT NULL CHECK (current_balance >= 0),
    current_equity      NUMERIC(18,2) NOT NULL CHECK (current_equity >= 0),

    -- Permissions — what this account is allowed to trade / which
    -- strategies may run on it. Enforced in application/validation code,
    -- not just documented here.
    asset_permissions   TEXT[] NOT NULL DEFAULT '{}',    -- e.g. {'forex','indices'}
    strategy_permissions TEXT[] NOT NULL DEFAULT '{}',   -- e.g. {'trend_following_daily'}

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE accounts IS 'One row per trading account. Source of truth for balances is updated by broker-pull jobs (Phase 3); manual updates should go through account_snapshots for auditability.';

-- -----------------------------------------------------------------------------
-- account_snapshots
-- Point-in-time balance/equity history. Populated by broker pulls (Phase 3)
-- or manual entry (Phase 1-2). This is what equity curves and drawdown
-- calculations are built from — never overwrite, always append.
-- -----------------------------------------------------------------------------
CREATE TABLE account_snapshots (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id      UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    balance         NUMERIC(18,2) NOT NULL,
    equity          NUMERIC(18,2) NOT NULL,
    margin_used     NUMERIC(18,2),
    open_pnl        NUMERIC(18,2),
    snapshot_source TEXT NOT NULL DEFAULT 'manual' CHECK (snapshot_source IN ('manual', 'broker_pull', 'eod_close')),
    snapshot_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_account_snapshots_account_time ON account_snapshots(account_id, snapshot_at DESC);

-- -----------------------------------------------------------------------------
-- risk_limits
-- Per-account risk limits. This is the table risk-validation code (Phase 2,
-- /scripts/risk/) reads before approving any proposed trade. Every limit is
-- expressed as a percentage where possible so it scales with account size;
-- absolute-dollar overrides are supported but discouraged as the primary
-- control.
-- -----------------------------------------------------------------------------
CREATE TABLE risk_limits (
    id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id                  UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,

    -- Position sizing
    max_position_size_pct       NUMERIC(5,2) NOT NULL DEFAULT 2.00
                                     CHECK (max_position_size_pct > 0 AND max_position_size_pct <= 100),
    max_position_risk_pct       NUMERIC(5,2) NOT NULL DEFAULT 1.00
                                     CHECK (max_position_risk_pct > 0 AND max_position_risk_pct <= 100),

    -- Loss limits (circuit breakers)
    daily_loss_limit_pct        NUMERIC(5,2) NOT NULL DEFAULT 3.00
                                     CHECK (daily_loss_limit_pct > 0 AND daily_loss_limit_pct <= 100),
    weekly_loss_limit_pct       NUMERIC(5,2) NOT NULL DEFAULT 6.00
                                     CHECK (weekly_loss_limit_pct > 0 AND weekly_loss_limit_pct <= 100),
    monthly_drawdown_limit_pct  NUMERIC(5,2) NOT NULL DEFAULT 10.00
                                     CHECK (monthly_drawdown_limit_pct > 0 AND monthly_drawdown_limit_pct <= 100),
    max_account_drawdown_pct    NUMERIC(5,2) NOT NULL DEFAULT 20.00
                                     CHECK (max_account_drawdown_pct > 0 AND max_account_drawdown_pct <= 100),

    -- Concentration / correlation
    max_correlated_exposure_pct NUMERIC(5,2) NOT NULL DEFAULT 6.00
                                     CHECK (max_correlated_exposure_pct > 0 AND max_correlated_exposure_pct <= 100),
    max_single_symbol_exposure_pct NUMERIC(5,2) NOT NULL DEFAULT 5.00
                                     CHECK (max_single_symbol_exposure_pct > 0 AND max_single_symbol_exposure_pct <= 100),
    max_open_positions           INTEGER NOT NULL DEFAULT 5 CHECK (max_open_positions > 0),

    -- Leverage
    max_leverage                NUMERIC(6,2) NOT NULL DEFAULT 10.00 CHECK (max_leverage > 0),

    -- Event/news risk
    block_trading_around_news    BOOLEAN NOT NULL DEFAULT TRUE,
    news_blackout_minutes_before INTEGER NOT NULL DEFAULT 15 CHECK (news_blackout_minutes_before >= 0),
    news_blackout_minutes_after  INTEGER NOT NULL DEFAULT 15 CHECK (news_blackout_minutes_after >= 0),

    -- State: when a circuit breaker trips, this flips and blocks new trades
    -- until manually reset (append-only reset log lives in risk_violations).
    trading_halted               BOOLEAN NOT NULL DEFAULT FALSE,
    halted_reason                TEXT,
    halted_at                    TIMESTAMPTZ,

    is_active                    BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Partial unique index (not a table-level UNIQUE constraint): enforces at
-- most one ACTIVE limit-set per account, while still allowing unlimited
-- historical (is_active = FALSE) rows to accumulate as limits change over
-- time. A plain UNIQUE(account_id, is_active) would wrongly also cap
-- inactive rows to one per account.
CREATE UNIQUE INDEX idx_risk_limits_one_active_per_account
    ON risk_limits(account_id) WHERE is_active = TRUE;

COMMENT ON TABLE risk_limits IS 'Per-account risk limits read by validation code before approving any proposed trade. Changing a limit should go through decision-log documentation, not a silent UPDATE.';

-- -----------------------------------------------------------------------------
-- risk_violations
-- Append-only audit log of every time a proposed trade was blocked, a
-- circuit breaker tripped, or a limit was manually overridden. This table
-- is as important as the trades table — it's the evidence that the risk
-- system is actually working.
-- -----------------------------------------------------------------------------
CREATE TABLE risk_violations (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_id          UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    violation_type      TEXT NOT NULL CHECK (violation_type IN (
                             'position_size_exceeded',
                             'position_risk_exceeded',
                             'daily_loss_limit_hit',
                             'weekly_loss_limit_hit',
                             'monthly_drawdown_limit_hit',
                             'max_account_drawdown_hit',
                             'correlated_exposure_exceeded',
                             'single_symbol_exposure_exceeded',
                             'max_open_positions_exceeded',
                             'max_leverage_exceeded',
                             'news_blackout_active',
                             'trading_halted_override',
                             'other'
                         )),
    severity            TEXT NOT NULL DEFAULT 'blocked' CHECK (severity IN ('blocked', 'warning', 'override_approved')),
    description          TEXT NOT NULL,
    proposed_trade_id    UUID,  -- FK added once trades table exists (see 002); nullable for non-trade violations
    triggered_by         TEXT NOT NULL,  -- agent/script name, e.g. 'risk_validator_v1'
    -- If a human explicitly overrode the block, that must be recorded — never silent.
    override_approved_by TEXT,
    override_reason      TEXT,
    resolved_at           TIMESTAMPTZ,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_risk_violations_account_time ON risk_violations(account_id, created_at DESC);
CREATE INDEX idx_risk_violations_unresolved ON risk_violations(account_id) WHERE resolved_at IS NULL;

COMMENT ON TABLE risk_violations IS 'Append-only. Every block, warning, and override is recorded here — this is the audit trail proving the risk system works, and the record of every human override for later review.';
