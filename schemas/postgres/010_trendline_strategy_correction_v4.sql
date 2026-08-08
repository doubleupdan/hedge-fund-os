-- =============================================================================
-- 010_trendline_strategy_correction_v4.sql
-- Phase 2 (correction #4): Incorporates the AJTG Trading Journal / Checklist
-- document - a second primary source distinct from the presentation deck,
-- containing the compact checklist form of the same strategy plus exit
-- confirmations, a hard invalidation rule, and checklist discipline.
--
-- Corrections/additions in this pass:
-- 1. RESOLVED (not a real contradiction): "Breakout" naming refers to
--    direction relative to the trendline/action line being broken, not
--    direction relative to the original trend. Continuation's action-line
--    break continues "in direction of the trend line" (same direction as
--    the trend). Breakout's line break is "in opposite direction of the
--    trend line/safety line" (against the trendline's own slope) - in a
--    true reversal setup this often means against the original trend
--    direction too, which is why the checklist labels it "THE REVERSAL."
--    Both the presentation's chart annotations and the checklist document
--    describe the same mechanism; migration 009's understanding was
--    correct, just imprecisely worded.
-- 2. Exit confirmations EXPANDED from 2 signals to 6, per the checklist's
--    explicit "C. EXIT CONFIRMATIONS" section: RSI target (70/30),
--    Risk/Reward (2:1) hit, price rejection of S/R, chart patterns
--    (double top/bottom, wedge, flag), market structure shift (opposite
--    trend forming), RSI divergence/convergence. RSI and RR remain the
--    two PRIMARY/interchangeable signals per founder's earlier
--    correction (migration 009); the other four are additional,
--    secondary confirmations available per the checklist.
-- 3. ZERO TOLERANCE RULE added as a hard invalidation condition: RSI at
--    60 during a SELL = invalid trade, regardless of any other
--    confirmation. This is now a structural field, not prose.
-- 4. Checklist discipline rule captured: "All boxes must be checked = 
--    VALID TRADE. Any deviation = NO TRADE." - binding, not advisory.
-- 5. Entry RSI: checklist states the simpler "RSI at 50 level" for both
--    setup types. Founder's more precise direction-specific range
--    (50-54 buys / 50-46 sells, migration 009) is KEPT as primary since
--    it is more specific and founder-confirmed; the checklist's "50
--    level" phrasing is noted as the simplified/rounded shorthand
--    version of the same rule, not a conflicting rule.
--
-- This migration also creates trade_journal_entries, a new table separate
-- from `strategies` and `trades` - the journal document is a trade-level
-- reflective record (psychology, checklist adherence, notes), distinct
-- from the trades table's transactional/financial record. See table
-- comment below for how the two relate.
-- =============================================================================

UPDATE strategies
SET
    exit_rules = 'PRIMARY exit signals - two INTERCHANGEABLE signals (per founder correction, migration 009):
  1. RSI(14) reaching 70 (for buy/long exits) or 30 (for sell/short exits)
  2. A 2:1 risk:reward take-profit target being hit
Whichever fires first is actionable immediately, or the trader may hold for the second signal to pursue additional profit (typically pairing with a trailing stop once the first fires, to lock in a break-even-or-better outcome).

SECONDARY/additional exit confirmations (per AJTG Trading Journal checklist document - "C. EXIT CONFIRMATIONS," 6 total signals listed, of which the above 2 are the primary pair):
  3. Price rejection of a support/resistance level
  4. Chart patterns forming (double top/bottom, wedge, flag)
  5. Market structure shift (opposite trend beginning to form)
  6. RSI divergence/convergence confirming exit

HARD INVALIDATION RULE ("Zero Tolerance Rule," binding, not advisory): if RSI is at 60 during a SELL, the trade is INVALID regardless of any other confirmation aligning - the source material states plainly "Smart money is not behind the move." This should be treated as a hard block, not a warning, in any future automated risk/validation logic for this strategy.

CHECKLIST DISCIPLINE RULE (binding, per AJTG Trading Journal): "All boxes must be checked = VALID TRADE. Any deviation = NO TRADE." A trade missing any required checklist confirmation should not be taken, per the strategy''s own stated rule - this is a strategy-level discipline requirement, independent of and in addition to this system''s own risk_limits/risk_violations gate.

Explicit discipline note from the presentation source: do not be greedy - adjust stop loss as the trade moves into profit, and prefer taking profit when an exit confirmation hits over trying to catch additional profit and risking giving back gains or losing the trade entirely.',

    known_risk_flags = ARRAY[
        'ZERO TOLERANCE RULE not yet enforced anywhere in scripts/risk/validate_trade.py: RSI=60 during a SELL should hard-block the trade. This strategy-specific rule is currently only documented here, not code-enforced - a gap worth closing before this strategy reaches live/paper trading.',
        'Checklist discipline rule ("all boxes checked = valid, any deviation = no trade") is not yet code-enforced - currently relies on the trader''s own checklist review before entry.',
        'INCOMPLETE SOURCE MATERIAL: module 1 of 5 (presentation) plus the AJTG Trading Journal/Checklist document have been reviewed. "Setting up MT5 for Taking Trades" and "Documenting and Reviewing Trades" modules from the presentation''s table of contents are still not confirmed as reviewed - position sizing specifically remains unconfirmed as documented anywhere reviewed so far.',
        'EA has not yet had a line-by-line human code review (required before any live/scaled use per repo policy - see CLAUDE.md), and is still under active development.',
        'Possible but UNCONFIRMED alignment between EA fixed-pip TPs and the presentation''s 2:1 RR (SL 150 / TP2 300 = 2:1) - worth verifying explicitly once EA development finishes, not yet treated as confirmed.',
        'Backtest currently limited to Gold (XAUUSD) only - results should not be assumed to generalize to other instruments.',
        'Only the swing-trading variant is currently being tested; other timeframe variants (if any) are undocumented.',
        'Correlation and news-blackout risk checks in the validation gate are not yet wired for this or any strategy (see scripts/risk/validate_trade.py).'
    ],

    risk_parameters = jsonb_set(
        risk_parameters,
        '{presentation_method,zero_tolerance_rule}',
        '"RSI at 60 during a SELL = INVALID TRADE, hard block, no exceptions"'::jsonb,
        true
    ),

    source_materials = ARRAY[
        'AJTG_Trendline_Strategy_Presentation.pptx - module 1 of 5 (entry/exit rule detail, founder-corrected across migrations 007-009)',
        'AJTG Trading Journal template document (checklist form of setups A/B, full 6-signal exit confirmation list, Zero Tolerance Rule, checklist discipline rule - migration 010)',
        'AJTG_TrendlineStrategy_EA.mq5 (in development - automation layer only, not yet reconciled against presentation)',
        'Backtest Vault (4 categories)'
    ],

    updated_at = now()
WHERE strategy_name = 'AJTG Trendline Trading Strategy' AND version = '3.0';

-- -----------------------------------------------------------------------------
-- trade_journal_entries
-- A reflective, trade-level record distinct from `trades` (schema 002).
-- `trades` is the transactional/financial record (entry/exit price, size,
-- realized P&L). This table is the discipline/psychology/checklist layer
-- the AJTG Trading Journal template captures - linked 1:1 to a trades row
-- where one exists, but kept as a separate table since not every field
-- here (emotional state, checklist adherence, "what would I improve")
-- belongs mixed into a financial transaction record.
-- -----------------------------------------------------------------------------
CREATE TABLE trade_journal_entries (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    trade_id                UUID REFERENCES trades(id),  -- nullable: journal may be filled before trade row exists, or for a trade not tracked elsewhere in this system yet
    account_id              UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    strategy_id              UUID REFERENCES strategies(id),

    trade_date                DATE NOT NULL,
    symbol                      TEXT NOT NULL,
    session                       TEXT CHECK (session IN ('sydney', 'tokyo', 'london', 'new_york', NULL)),

    entry_price                    NUMERIC(18,6),
    stop_loss                       NUMERIC(18,6),
    take_profit                      NUMERIC(18,6),
    take_profit_type                  TEXT,  -- e.g. 'TSL' (trailing stop loss) as seen in source journal - free text since exit style varies

    risk_pct                            NUMERIC(5,2),
    rr_achieved                          NUMERIC(5,2),  -- risk:reward actually realized on this trade, e.g. 1.5 for "1.5:1"

    result                                 TEXT CHECK (result IN ('win', 'loss', 'break_even')),
    profit_loss_pips                        NUMERIC(10,2),
    profit_loss_amount                       NUMERIC(18,2),

    followed_checklist                        TEXT CHECK (followed_checklist IN ('yes', 'mostly', 'no')),
    -- Per the strategy''s own binding rule ("all boxes checked = valid, any
    -- deviation = no trade"), 'mostly' or 'no' here should prompt review -
    -- this system does not yet automatically flag that, see known_risk_flags.

    emotion_before                              TEXT,
    emotion_after                                TEXT,

    trade_rationale                               TEXT,  -- "Why did I take this trade?"
    was_valid_setup                                 BOOLEAN,
    valid_setup_notes                                 TEXT,  -- e.g. "Yes but we go no conservative entry" - free text since the nuance matters
    improvement_notes                                   TEXT,  -- "What would I improve?"

    screenshot_url                                        TEXT,  -- reference to a stored trade screenshot, not the image itself

    created_at                                              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                                              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_trade_journal_account ON trade_journal_entries(account_id);
CREATE INDEX idx_trade_journal_strategy ON trade_journal_entries(strategy_id);
CREATE INDEX idx_trade_journal_trade ON trade_journal_entries(trade_id) WHERE trade_id IS NOT NULL;
CREATE INDEX idx_trade_journal_date ON trade_journal_entries(trade_date DESC);
CREATE INDEX idx_trade_journal_checklist ON trade_journal_entries(followed_checklist) WHERE followed_checklist != 'yes';

COMMENT ON TABLE trade_journal_entries IS 'Reflective/discipline layer per the AJTG Trading Journal template - psychology, checklist adherence, and self-review notes for a trade. Distinct from trades (schema 002), which is the transactional/financial record. Link via trade_id where the corresponding trades row exists.';
