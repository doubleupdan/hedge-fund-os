-- =============================================================================
-- 014_mark_hard_rules_code_enforced.sql
-- Updates the AJTG Trendline Strategy's known_risk_flags now that the Zero
-- Tolerance Rule and checklist discipline rule are code-enforced in
-- scripts/risk/validate_trade.py (as of the same session as migrations
-- 012-013), removing the two flags that specifically said these were
-- documentation-only, and adding a note on how to actually supply the new
-- required fields.
-- =============================================================================

UPDATE strategies
SET
    known_risk_flags = ARRAY[
        'Zero Tolerance Rule and checklist discipline are now CODE-ENFORCED in scripts/risk/validate_trade.py (as of migrations 012-013) - but only if the generating agent/script populates proposed_trades.signal_rsi, proposed_trades.direction, and proposed_trades.checklist_complete. A signal missing these fields is rejected by default (fail closed), not silently passed.',
        'Position sizing methodology for this strategy is still not documented anywhere reviewed so far - no sizing rule exists to code-enforce yet. This is the current top priority gap for making this strategy fully tradeable.',
        'EA has not yet had a line-by-line human code review (required before any live/scaled use per repo policy - see CLAUDE.md), and is still under active development - solidification deferred until the fund is operational and generating real trading data to train against.',
        'Possible but UNCONFIRMED alignment between EA fixed-pip TPs and the presentation''s 2:1 RR (SL 150 / TP2 300 = 2:1) - worth verifying once EA development finishes.',
        'Backtest currently limited to Gold (XAUUSD) only - this is the only instrument approved for this strategy in the fund''s portfolio right now (founder-confirmed); results should not be assumed to generalize to other instruments if that scope changes later.',
        'Only the swing-trading variant is currently being tested; other timeframe variants (if any) are undocumented.',
        'Correlation and news-blackout risk checks in the validation gate remain unwired (no market-data/calendar source connected yet) - see scripts/risk/validate_trade.py fail-safe warnings. Founder has not yet decided an approach; deferred pending operational fund with real position data to design against.'
    ],
    updated_at = now()
WHERE strategy_name = 'AJTG Trendline Trading Strategy' AND version = '3.0';

-- Volume Profile Trading System stays exactly as-is (explicit placeholder,
-- assigned to a future backtesting/development agent per founder) - no
-- change needed, this statement documents that decision rather than
-- altering any row.
