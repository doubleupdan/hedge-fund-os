-- =============================================================================
-- 016_risk_limits_nullable_out_of_scope.sql
-- risk_limits was originally built with every column NOT NULL + a hardcoded
-- default (2.00, 3.00, 6.00, true, 15, 15, etc.) - this meant any INSERT
-- that didn't explicitly set every field silently inherited a default the
-- founder never chose, rather than leaving the field genuinely unset.
--
-- Correlation exposure and news-blackout checks are explicitly OUT OF SCOPE
-- for this repo (per founder direction - these belong to a future
-- AJTG-specific dashboard/agent build, not the fund's core risk gate).
-- Since they're out of scope, there's no correct default value to force -
-- these 4 columns become nullable so future account risk_limits rows can
-- honestly represent "not evaluated" rather than a fabricated number.
--
-- Position size, position risk, daily/weekly loss, drawdown, max open
-- positions, and max leverage remain NOT NULL - these ARE real, in-scope
-- risk dimensions the fund needs a deliberate value for on every account,
-- even if that value is a large "non-binding ceiling" chosen because the
-- account's real control lives in a different field (e.g. Flip Account's
-- max_daily_losing_trades / max_weekly_losing_trades rather than a %
-- based loss limit).
--
-- Applied live directly via the Supabase MCP tool on 2026-08-12 before
-- this file was written - this file documents that change for the repo's
-- own record and for any future fresh-database setup.
-- =============================================================================

ALTER TABLE risk_limits
    ALTER COLUMN max_correlated_exposure_pct DROP NOT NULL,
    ALTER COLUMN max_correlated_exposure_pct DROP DEFAULT,
    ALTER COLUMN block_trading_around_news DROP NOT NULL,
    ALTER COLUMN block_trading_around_news DROP DEFAULT,
    ALTER COLUMN news_blackout_minutes_before DROP NOT NULL,
    ALTER COLUMN news_blackout_minutes_before DROP DEFAULT,
    ALTER COLUMN news_blackout_minutes_after DROP NOT NULL,
    ALTER COLUMN news_blackout_minutes_after DROP DEFAULT;
</content>
