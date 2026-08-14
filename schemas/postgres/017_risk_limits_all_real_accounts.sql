-- =============================================================================
-- 017_risk_limits_all_real_accounts.sql
-- Adds risk_limits rows for the remaining 4 real AJTG/Precision Summit Fund
-- accounts (Master 301511, Test Real 100892/100076, Verity 100-to-100k
-- 00000), following the same structure established for the Flip Account
-- (48830) in the same session:
--
-- - max_position_risk_pct = 10.00: derived from a 150-pip SL at $1/pip
--   (LTI, 0.01 lot XAUUSD) against a $150 base account size - see Flip
--   Account math in the same session. Applied uniformly here per
--   founder's explicit "yes, same as that" confirmation, even though
--   these accounts' real starting balances/lot sizes are not yet
--   finalized (all currently $0).
-- - max_account_drawdown_pct = 25.00, max_daily_losing_trades = 2,
--   max_weekly_losing_trades = 5: founder's stated numbers, reused
--   across all real trading accounts uniformly.
-- - max_position_size_pct / daily_loss_limit_pct / weekly_loss_limit_pct
--   / monthly_drawdown_limit_pct = 100.00, max_open_positions = 999:
--   deliberately non-binding ceilings - these accounts' real trading
--   control is pip-based SL + risk-% + the trade-count circuit breakers,
--   not these %-of-equity or fixed-position-count fields. Set explicitly
--   high rather than left at the schema's old low defaults (2%, 3%, 6%,
--   5 positions) which were never chosen by the founder for these
--   accounts and would have silently under- or over-constrained them.
-- - max_correlated_exposure_pct / block_trading_around_news /
--   news_blackout_minutes_before / news_blackout_minutes_after: left
--   NULL (now nullable per migration 016) - correlation and news checks
--   are explicitly out of scope for this repo.
--
-- IMPORTANT: these 4 accounts are still at $0 balance as of this
-- migration. These risk_limits rows are structural prep, not a signal
-- that the accounts are ready for live signal generation - real balances
-- still need to be entered before any of these are meaningfully
-- risk-gated in practice.
--
-- Applied live directly via the Supabase MCP tool on 2026-08-12 before
-- this file was written - this file documents that change for the
-- repo's own record and for any future fresh-database setup.
-- =============================================================================

INSERT INTO risk_limits (account_id, max_position_size_pct, max_position_risk_pct, daily_loss_limit_pct, weekly_loss_limit_pct, monthly_drawdown_limit_pct, max_account_drawdown_pct, max_open_positions, max_daily_losing_trades, max_weekly_losing_trades, is_active)
SELECT id, 100.00, 10.00, 100.00, 100.00, 100.00, 25.00, 999, 2, 5, true
FROM accounts
WHERE account_name IN (
    'Precision Summit Fund Master (301511)',
    'AJTG Test Real Account (100892)',
    'AJTG Test Real Account (100076)',
    'AJTG 100-to-100k Challenge (00000)'
)
AND id NOT IN (SELECT account_id FROM risk_limits);
</content>
