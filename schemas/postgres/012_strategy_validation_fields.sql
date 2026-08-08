-- =============================================================================
-- 012_strategy_validation_fields.sql
-- Adds fields to proposed_trades needed to CODE-ENFORCE strategy-specific
-- rules (the AJTG Trendline Strategy's Zero Tolerance Rule and checklist
-- discipline requirement) rather than leaving them as documentation-only.
--
-- These fields are intentionally generic (not "ajtg_specific") so any
-- future strategy's own hard rules can reuse the same shape: a signal-time
-- RSI reading, and a checklist completion flag with itemized detail.
-- =============================================================================

ALTER TABLE proposed_trades
    ADD COLUMN signal_rsi NUMERIC(5,2);
    -- RSI(14) reading at the moment the signal was generated. Required for
    -- any strategy whose rules reference RSI (the Zero Tolerance Rule and
    -- entry/exit confirmations both do, for the Trendline Strategy).

ALTER TABLE proposed_trades
    ADD COLUMN checklist_complete BOOLEAN;
    -- Whether every required confirmation for the strategy's own checklist
    -- was satisfied before this signal was generated. NULL = not
    -- applicable / not a checklist-governed strategy. FALSE should hard
    -- block per "any deviation = no trade."

ALTER TABLE proposed_trades
    ADD COLUMN checklist_detail JSONB;
    -- Itemized checklist state, e.g. {"trend_identified": true,
    -- "trendline_drawn": true, "entry_zone_confirmed": true, "rsi_aligned":
    -- true}. Optional detail behind checklist_complete - not required for
    -- the hard-block check itself, but useful for audit/review.

COMMENT ON COLUMN proposed_trades.signal_rsi IS 'RSI(14) reading at signal generation time. Used by strategy-specific hard rules, e.g. the AJTG Trendline Strategy Zero Tolerance Rule.';
COMMENT ON COLUMN proposed_trades.checklist_complete IS 'Whether the strategy''s own required checklist was fully satisfied. FALSE hard-blocks per the strategy''s "any deviation = no trade" rule (see strategies.exit_rules for the Trendline Strategy''s specific wording). NULL = not a checklist-governed strategy.';
COMMENT ON COLUMN proposed_trades.checklist_detail IS 'Optional itemized checklist state for audit/review. Not required for the hard-block check, which relies on checklist_complete alone.';
