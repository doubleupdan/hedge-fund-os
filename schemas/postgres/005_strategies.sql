-- =============================================================================
-- 005_strategies.sql
-- Phase 2 (addendum): Strategy registry.
--
-- Gap this closes: strategies currently exist only as tags scattered across
-- proposed_trades.strategy_tag and trades.strategy_tag — free text, no
-- structure, no version history, no single source of truth for "what are
-- our rules for this strategy, and what's its status right now."
--
-- This table makes each strategy a first-class, versioned entity. A
-- strategy's *rules* live in structured/free-text fields here; its
-- *performance* is derived by querying trades/proposed_trades WHERE
-- strategy_id = X — this table does not duplicate performance data, only
-- strategy definition and current status.
--
-- Populated in this migration: AJTG Trendline Trading Strategy (fully
-- specified from EA source) and Volume Profile Trading System (PDF-only,
-- less detail available). Jstew Strategy and ASAITA are inserted as
-- placeholder rows — named and tracked, but explicitly marked
-- not_yet_documented rather than filled with invented detail.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- strategies
-- -----------------------------------------------------------------------------
CREATE TABLE strategies (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    strategy_name            TEXT NOT NULL,
    version                    TEXT NOT NULL DEFAULT '1.0',    -- e.g. '3.0' for the Trendline EA
    trading_group_id             UUID REFERENCES trading_groups(id),  -- which group owns/runs this strategy

    -- Lifecycle status — mirrors the deployment pipeline concept: a
    -- strategy should move through these deliberately, not jump straight
    -- to live. 'not_yet_documented' is a Phase-1-honest addition for
    -- strategies we know exist but haven't captured yet.
    status                          TEXT NOT NULL DEFAULT 'not_yet_documented' CHECK (status IN (
                                        'not_yet_documented', 'documented', 'backtesting',
                                        'paper_trading', 'live', 'restricted', 'paused', 'retired'
                                    )),

    -- Scope / permissions — mirrors accounts.asset_permissions and
    -- accounts.strategy_permissions (schema 001) so a strategy's declared
    -- scope can be checked against an account's permissions before it's
    -- allowed to generate signals there.
    allowed_asset_classes             TEXT[] NOT NULL DEFAULT '{}',   -- e.g. {'precious_metal'}
    allowed_symbols                     TEXT[] NOT NULL DEFAULT '{}',   -- e.g. {'XAUUSD'} — empty means "any symbol within allowed_asset_classes"
    allowed_timeframes                    TEXT[] NOT NULL DEFAULT '{}',   -- e.g. {'swing'}
    allowed_sessions                        TEXT[] NOT NULL DEFAULT '{}',   -- e.g. {'london','new_york'}

    -- Strategy definition. Kept as structured JSON rather than rigid
    -- columns because rule shapes differ wildly by strategy (a 7-state
    -- signal machine vs. a volume-profile read vs. a discretionary
    -- checklist) — forcing one column layout would either lose detail or
    -- require a schema change per strategy. summary is always required so
    -- the strategy is at least skimmable without parsing the JSON.
    summary                                    TEXT NOT NULL,
    entry_rules                                  TEXT,
    exit_rules                                     TEXT,
    position_sizing_rules                            TEXT,
    risk_parameters                                    JSONB,   -- e.g. {"sl_pips": 150, "tp1_pips": 100, "tp2_pips": 200, "tp3_pips": 300, "partial_close_sequence": [25,25,25,25]}
    underlying_framework                                 TEXT,    -- e.g. 'AJTG Smart Money Concepts / ICT curriculum'

    -- Automation linkage
    has_dedicated_ea                                        BOOLEAN NOT NULL DEFAULT FALSE,
    ea_filename                                               TEXT,   -- e.g. 'AJTG_TrendlineStrategy_EA.mq5'
    ea_reviewed                                                 BOOLEAN NOT NULL DEFAULT FALSE,  -- has a human done a line-by-line code review? See CLAUDE.md constraint #2.

    -- Known limitations / flags — explicit space for "here's what we
    -- don't trust yet about this strategy," so it isn't lost in someone's
    -- head. Complements risk_violations (schema 001), which is per-trade;
    -- this is per-strategy, structural risk.
    known_risk_flags                                              TEXT[] DEFAULT '{}',

    -- Source material provenance — so a strategy's documentation can be
    -- traced back to the actual files it was extracted from.
    source_materials                                                TEXT[] DEFAULT '{}',  -- e.g. {'AJTG_Trendline_Strategy_Presentation.pptx', 'AJTG_TrendlineStrategy_EA.mq5'}

    created_at                                                        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                                                        TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE(strategy_name, version)
);

CREATE INDEX idx_strategies_status ON strategies(status);
CREATE INDEX idx_strategies_trading_group ON strategies(trading_group_id);
CREATE INDEX idx_strategies_symbols ON strategies USING GIN(allowed_symbols);

COMMENT ON TABLE strategies IS 'Strategy IP registry / strategy definitions with version history. Performance is NOT stored here — derive it by querying trades/proposed_trades WHERE strategy_id = this.id. This table answers "what are the rules and current status," not "how is it performing."';

-- -----------------------------------------------------------------------------
-- Link trades / proposed_trades to strategies by ID, not just free-text tag.
-- strategy_tag columns are KEPT (not dropped) for backward compatibility
-- and for trades that predate this table or don't map to a registered
-- strategy (e.g. genuinely discretionary, untagged trades) — strategy_id
-- is nullable for exactly that reason.
-- -----------------------------------------------------------------------------
ALTER TABLE proposed_trades ADD COLUMN strategy_id UUID REFERENCES strategies(id);
ALTER TABLE trades ADD COLUMN strategy_id UUID REFERENCES strategies(id);

CREATE INDEX idx_proposed_trades_strategy ON proposed_trades(strategy_id);
CREATE INDEX idx_trades_strategy ON trades(strategy_id);

COMMENT ON COLUMN proposed_trades.strategy_id IS 'Optional FK to strategies. NULL for discretionary or untagged signals — strategy_tag (free text) remains as a fallback label.';
COMMENT ON COLUMN trades.strategy_id IS 'Optional FK to strategies. NULL for discretionary or untagged trades — strategy_tag (free text) remains as a fallback label.';

-- -----------------------------------------------------------------------------
-- Seed data: the two fully-documented strategies, plus placeholder rows
-- for the two named-but-undocumented ones. Trading group is linked to
-- Average Joe Trading Group where one already exists with that exact
-- name; otherwise NULL and left for manual linking.
-- -----------------------------------------------------------------------------

INSERT INTO strategies (
    strategy_name, version, trading_group_id, status,
    allowed_asset_classes, allowed_symbols, allowed_timeframes,
    summary, entry_rules, exit_rules, position_sizing_rules,
    risk_parameters, underlying_framework,
    has_dedicated_ea, ea_filename, ea_reviewed,
    known_risk_flags, source_materials
)
SELECT
    'AJTG Trendline Trading Strategy', '3.0',
    (SELECT id FROM trading_groups WHERE group_name = 'Average Joe Trading Group' LIMIT 1),
    'backtesting',
    ARRAY['precious_metal'],       -- current backtest scope is Gold-only; broaden once validated on other instruments
    ARRAY['XAUUSD'],
    ARRAY['swing'],
    'Trendline break/continuation strategy built on Smart Money Concepts/ICT framework (market structure BOS/CHoCH, liquidity sweeps, order blocks, Fair Value Gaps, Kill Zones, SMT divergence, Judas Swing). Implemented as a 7-state signal machine in a dedicated MT5 EA. Currently under active backtesting for the swing-trading version, Gold (XAUUSD) only.',
    'Classifies setups into 4 types via swing detection: Breakout (Uptrend), Breakout (Downtrend), Continuation (Uptrend), Continuation (Downtrend). Entry filtered through an RSI condition on top of the structural trendline signal. Full entry logic lives in the 7-state signal machine in the EA source — this summary is not a substitute for reading the code.',
    'Three-tier profit-taking with partial closes: TP1/TP2/TP3 correspond to a 25/25/25/25 close-and-trail sequence (final 25% trails).',
    'Position sizing methodology not yet extracted into structured form — pending review.',
    '{"sl_pips": 150, "tp1_pips": 100, "tp2_pips": 200, "tp3_pips": 300, "partial_close_sequence_pct": [25, 25, 25, 25], "instrument_note": "pip values are Gold(XAUUSD)-specific, do not assume they transfer to other instruments"}'::jsonb,
    'AJTG Smart Money Concepts / ICT curriculum (AJTG 201 full execution confluence)',
    TRUE, 'AJTG_TrendlineStrategy_EA.mq5', FALSE,
    ARRAY[
        'EA has not yet had a line-by-line human code review (required before any live/scaled use per repo policy — see CLAUDE.md)',
        'Backtest currently limited to Gold (XAUUSD) only — results should not be assumed to generalize to other instruments',
        'Position sizing methodology not yet documented in structured form',
        'Correlation and news-blackout risk checks in the validation gate are not yet wired for this or any strategy (see scripts/risk/validate_trade.py)',
        'Only the swing-trading variant is currently being tested; other timeframe variants (if any) are undocumented'
    ],
    ARRAY['AJTG_Trendline_Strategy_Presentation.pptx', 'AJTG_TrendlineStrategy_EA.mq5', 'Backtest Vault (4 categories)']
WHERE NOT EXISTS (
    SELECT 1 FROM strategies WHERE strategy_name = 'AJTG Trendline Trading Strategy' AND version = '3.0'
);

INSERT INTO strategies (
    strategy_name, version, trading_group_id, status,
    allowed_asset_classes, allowed_symbols, allowed_timeframes,
    summary, entry_rules, exit_rules, position_sizing_rules,
    has_dedicated_ea, known_risk_flags, source_materials
)
SELECT
    'Volume Profile Trading System', '1.0',
    (SELECT id FROM trading_groups WHERE group_name = 'Average Joe Trading Group' LIMIT 1),
    'documented',
    '{}', '{}', '{}',
    'Volume-profile-based trading system, documented via standalone PDF. No dedicated EA exists yet — automation status and whether this is actively traded vs. reference/educational material is unconfirmed.',
    'Not yet extracted from source PDF into structured form.',
    'Not yet extracted from source PDF into structured form.',
    'Not yet extracted from source PDF into structured form.',
    FALSE,
    ARRAY[
        'Unclear whether this strategy is actively traded or reference/educational only — confirm before relying on it for signals',
        'No EA/automation exists — any use is currently fully discretionary',
        'Entry/exit/sizing rules not yet extracted from the source PDF into structured fields'
    ],
    ARRAY['AJTG_Volume_Profile_Trading_System.pdf']
WHERE NOT EXISTS (
    SELECT 1 FROM strategies WHERE strategy_name = 'Volume Profile Trading System' AND version = '1.0'
);

INSERT INTO strategies (strategy_name, version, trading_group_id, status, summary, known_risk_flags)
SELECT
    'Jstew Strategy', '1.0',
    (SELECT id FROM trading_groups WHERE group_name = 'Average Joe Trading Group' LIMIT 1),
    'not_yet_documented',
    'Advanced-level teaching strategy referenced for top-tier students. No source materials currently on file — deprioritized until supplied.',
    ARRAY['No documentation exists yet — do not use for live or paper signals until specified']
WHERE NOT EXISTS (
    SELECT 1 FROM strategies WHERE strategy_name = 'Jstew Strategy' AND version = '1.0'
);

INSERT INTO strategies (strategy_name, version, trading_group_id, status, summary, known_risk_flags)
SELECT
    'ASAITA (American Sniper AI Trading Agent)', '1.0',
    (SELECT id FROM trading_groups WHERE group_name = 'Average Joe Trading Group' LIMIT 1),
    'not_yet_documented',
    'Confirmed to exist by name; no source materials on file yet.',
    ARRAY['No documentation exists yet — do not use for live or paper signals until specified']
WHERE NOT EXISTS (
    SELECT 1 FROM strategies WHERE strategy_name = 'ASAITA (American Sniper AI Trading Agent)' AND version = '1.0'
);
