-- =============================================================================
-- 013_strategy_violation_types.sql
-- Adds two dedicated risk_violations.violation_type values so
-- strategy-specific hard-rule violations (Zero Tolerance Rule, checklist
-- discipline) are distinguishable in reporting/audit queries instead of
-- collapsing into the generic 'other' bucket.
--
-- Postgres doesn't support ALTER TABLE ... ALTER CONSTRAINT for CHECK
-- constraints directly - the constraint must be dropped and recreated.
-- =============================================================================

ALTER TABLE risk_violations DROP CONSTRAINT risk_violations_violation_type_check;

ALTER TABLE risk_violations ADD CONSTRAINT risk_violations_violation_type_check
    CHECK (violation_type IN (
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
        'strategy_hard_rule_violation',   -- NEW: e.g. AJTG Trendline Strategy Zero Tolerance Rule
        'checklist_incomplete',           -- NEW: e.g. AJTG "any deviation = no trade" rule
        'other'
    ));
