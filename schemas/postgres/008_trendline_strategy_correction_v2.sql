-- =============================================================================
-- 008_trendline_strategy_correction_v2.sql
-- Phase 2 (correction #2): Second-pass correction after a full, deliberate
-- slide-by-slide re-review of AJTG_Trendline_Strategy_Presentation,
-- including chart image annotations, not just slide text.
--
-- Corrections made in this pass vs. migration 007:
-- 1. Step 1 (trend identification) reframed as two distinct named methods
--    (Uptrend / Downtrend), each with its own swing-sequence definition,
--    rather than implying one is just the mirror of the other.
-- 2. Step 2 downtrend trendline construction re-confirmed directly by
--    founder: connects FIRST HIGH to SECOND HIGH (this was already
--    correct in 007's entry_rules text, now founder-verified rather than
--    inferred from the PDF alone).
-- 3. EXIT LOGIC CORRECTED: migration 007 stated RSI(70/30) as the sole
--    exit confirmation. Re-review of the Step 5b chart annotations shows
--    a TWO-PART exit checklist: RSI reaching 70/30 AND/OR an RR
--    (risk:reward) take-profit target being hit ("RR TP Hit: YES/NO"
--    appears as an independently-tracked checklist item alongside the
--    RSI reading on both Continuation and Breakout exit chart examples).
--    The specific RR ratio value is NOT stated anywhere in the slides
--    reviewed so far and is NOT invented here - marked explicitly unknown.
-- 4. Breakout-setup-specific detail added: the trendline break itself
--    (not a separate action line) is the Step 4 confirmation signal for
--    Breakout setups, distinct from Continuation setups which require an
--    action line breakout. Also notes the "Conservative Entry After
--    Liquidity Sweep" framing shown specifically on the Breakout Uptrend
--    Step 5 chart, not present on the Continuation Step 5 charts.
-- 5. Explicit, honest gap flag: the presentation's own table of contents
--    names 4 additional modules (Trade Entry and Exit Confirmations;
--    Setting up MT5 for Taking Trades; Trading Checklist; Documenting and
--    Reviewing Trades) whose slide content has not been provided to this
--    system yet. Position sizing and the specific RR ratio very likely
--    live there. Not guessed at here.
-- =============================================================================

UPDATE strategies
SET
    summary = 'Trendline break/continuation strategy using swing-point trend identification with two direction-specific methods (Uptrend and Downtrend, each independently defined, not simply mirrored). RSI(14) is used for entry timing, and exit is confirmed by a TWO-PART checklist: RSI reaching 70 (longs) / 30 (shorts) AND/OR an RR (risk:reward) take-profit target being hit - the specific RR ratio is not yet documented in this system. Four setups: Continuation (Uptrend), Continuation (Downtrend), Breakout (Uptrend), Breakout (Downtrend), each with its own 5-step identification process taught in AJTG_Trendline_Strategy_Presentation. Currently under active backtesting for the swing-trading version, Gold (XAUUSD) only. A dedicated EA is in development but is NOT the source of truth for the rules below - the presentation is. NOTE: the presentation''s own table of contents references 4 further modules (Entry/Exit Confirmations detail, MT5 setup, Trading Checklist, Documenting/Reviewing Trades) not yet captured in this system - see known_risk_flags.',

    entry_rules = 'Two distinct trend-identification methods, one per direction - NOT simply the mirror of one rule:

METHOD A - Uptrend identification: sequence of Low, High, THEN Higher Low, Higher High.
METHOD B - Downtrend identification: sequence of High, Low, THEN Lower High, Lower Low.

Shared 5-step process applied once trend direction is identified (all 4 setups follow this shape, with direction-specific construction per Steps 1-2 above):

STEP 1 - Identify trend using Method A or B above, matched to current price structure.

STEP 2 - Draw trendline:
  Uptrend: connect the FIRST LOW to the SECOND LOW.
  Downtrend: connect the FIRST HIGH to the SECOND HIGH.
  Use the trendline tool, then extend with the ray tool. Prefer trendlines with the most candlestick body touches (connect bodies, not wicks).

STEP 3 - Continuation or Breakout classification: wait for the 3rd swing point to form (3rd low for uptrend setups via 2nd High to 3rd Low connection; 3rd high for downtrend setups via 2nd Low to 3rd High connection). Wait for candle CLOSE before classifying.
  - Continuation: price reaches the trendline, respects it, and rejects/bounces off it -> draw an action line (connects to candle tops).
  - Breakout: price reaches the trendline and CLOSES THROUGH it (does not respect it) -> proceed to Step 4. Breakout setups do not require a separate action line - the trendline break itself is the Step 4 confirmation signal (this differs from Continuation setups, which confirm via the action line).

STEP 4 - Find entry zone (2 sub-steps, confirmation signal differs by setup type):
  1. Wait for the break:
     - Continuation setups: the first candle in trend direction that closes above/through the ACTION LINE confirms the continuation.
     - Breakout setups: the first candle that closes through the TRENDLINE ITSELF confirms the breakout (no action line involved).
  2. Draw entry zone: the SECOND candlestick after the confirming candle from step 1 defines the entry zone (same rule for both setup types).

STEP 5 - Entry confirmation via RSI(14), two variants (same for all 4 setups):
  - Aggressive Entry: on the candle immediately following entry-zone formation, if RSI is at or near 50 (50-52), enter. If not, wait until RSI reaches that zone.
  - Conservative Entry: wait for price to push away from the entry zone, then for a retest of the entry zone; if RSI is at/near 50 on the retest, enter. If not, wait until RSI reaches that zone.
    NOTE: on the Breakout (Uptrend) example specifically, the conservative entry is labeled "Conservative Entry After Liquidity Sweep" - suggesting breakout-setup conservative entries may specifically wait for a liquidity sweep before the retest, not just any pullback. Not confirmed whether this applies to all 4 setups or is specific to breakout setups - flagged as an open question, not assumed either way.',

    exit_rules = 'TWO-PART exit confirmation checklist (corrected from migration 007, which stated RSI alone):
  1. RSI(14) reaching 70 (for buy/long exits) or 30 (for sell/short exits)
  2. An RR (risk:reward) take-profit target being hit

Both conditions are tracked independently on a checklist (seen directly in the presentation''s Step 5b chart annotations, e.g. "70 RSI: NO / RR TP Hit: YES" and "30 RSI HIT: YES / TP HIT OR TRAILING SL"), suggesting either condition being hit may be sufficient to act on, though the presentation does not explicitly state whether BOTH are required or EITHER is sufficient - flagged as unconfirmed, not assumed.

THE SPECIFIC RR RATIO IS NOT DOCUMENTED ANYWHERE IN THE SLIDES REVIEWED SO FAR. Do not assume a value (e.g. 1:2, 1:3) - this likely lives in the "Trade Entry and Exit Confirmations" module referenced in the presentation''s table of contents but not yet provided to this system.

Handling once an exit confirmation hits:
  - If price has not yet reached RSI exit level or RR target, either wait for it or use other/further confirmations to capture profit incrementally (presentation references a separate "managing and scaling in trades" presentation, not yet in this system).
  - If a confirmation HAS hit and the trader wants to extend the position, set a trailing stop loss to guarantee a break-even-or-better exit, then wait for further confirmation to capture additional pips.
  - Explicit discipline note from the source material: do not be greedy - adjust stop loss as the trade moves into profit, and prefer taking profit when an exit confirmation hits over trying to catch additional profit and ending up giving back gains or losing the trade entirely.',

    position_sizing_rules = 'Not specified in the presentation module reviewed so far (module 1 of 5: "Finding Setups, Charting Setups, Taking Trades"). The presentation''s own table of contents lists 4 further modules - "Trade Entry and Exit Confirmations," "Setting up MT5 for Taking Trades," "Trading Checklist," and "Documenting and Reviewing Trades" - not yet provided to this system. Position sizing rules, and likely the specific RR ratio referenced in exit_rules, probably live in one of these.',

    risk_parameters = '{
        "presentation_method": {
            "exit_type": "two-part checklist: RSI-based AND/OR RR (risk:reward) take-profit target",
            "rsi_period": 14,
            "entry_rsi_zone": "50 to 52",
            "exit_rsi_long": 70,
            "exit_rsi_short": 30,
            "rr_take_profit_ratio": "NOT DOCUMENTED - referenced as a checklist item (\"RR TP Hit\") in chart annotations but no specific ratio value is stated anywhere in the module 1 slides reviewed so far",
            "note": "This is the discretionary/manual method taught in AJTG_Trendline_Strategy_Presentation module 1. Corrected in migration 008 from an earlier RSI-only description - the exit is a two-condition checklist, not RSI alone."
        },
        "ea_automation_layer": {
            "status": "EA still under active development per founder (as of 2026-08-08) - NOT yet verified to match or supersede the presentation method",
            "sl_pips": 150, "tp1_pips": 100, "tp2_pips": 200, "tp3_pips": 300,
            "partial_close_sequence_pct": [25, 25, 25, 25],
            "instrument_note": "pip values are Gold (XAUUSD)-specific, do not assume they transfer to other instruments",
            "source": "extracted from AJTG_TrendlineStrategy_EA.mq5 source code by a separate session - treat as provisional until EA development is finalized and the EA is reconciled against or explicitly differentiated from the presentation method",
            "possible_reconciliation_note": "the EA''s fixed TP1/TP2/TP3 pip structure may turn out to BE the EA''s implementation of the presentation''s undocumented RR ratio - this is a plausible hypothesis, not a confirmed fact. Do not treat as confirmed until modules 2-5 are reviewed or the EA is finalized."
        }
    }'::jsonb,

    underlying_framework = 'Swing-point trend identification via two direction-specific methods (Uptrend: Low/High/Higher-Low/Higher-High; Downtrend: High/Low/Lower-High/Lower-Low), with RSI(14) entry timing and a two-part RSI+RR exit checklist. Presentation materials reference broader AJTG Smart Money Concepts/ICT curriculum as contextual background, but the Trendline Strategy itself as taught in module 1 is a self-contained trendline + RSI + RR method.',

    known_risk_flags = ARRAY[
        'INCOMPLETE SOURCE MATERIAL: only module 1 of 5 ("Finding Setups, Charting Setups, Taking Trades") has been reviewed. Modules 2-5 (Trade Entry and Exit Confirmations, Setting up MT5, Trading Checklist, Documenting and Reviewing Trades) are named in the presentation''s own table of contents but their content is not yet in this system. Position sizing and the specific RR take-profit ratio very likely live there.',
        'RR (risk:reward) take-profit ratio is referenced as an exit checklist item but its specific value is not documented anywhere reviewed so far - do not assume a number.',
        'Unconfirmed whether RSI-70/30 and RR-TP-hit are BOTH required for exit or EITHER is sufficient - presentation shows them as a checklist without stating the combination logic explicitly.',
        'EA has not yet had a line-by-line human code review (required before any live/scaled use per repo policy - see CLAUDE.md), and is still under active development - its fixed-pip parameters are NOT confirmed to match the presentation''s RSI+RR method, though they may turn out to be the EA''s implementation of the undocumented RR ratio (unconfirmed hypothesis).',
        'Backtest currently limited to Gold (XAUUSD) only - results should not be assumed to generalize to other instruments.',
        'Only the swing-trading variant is currently being tested; other timeframe variants (if any) are undocumented.',
        'The "Conservative Entry After Liquidity Sweep" label appears only on the Breakout (Uptrend) example chart - unconfirmed whether this liquidity-sweep condition applies to all 4 setups or is specific to breakout setups.'
    ],

    source_materials = ARRAY['AJTG_Trendline_Strategy_Presentation.pptx - module 1 of 5 only (PRIMARY SOURCE for entry/exit rules as documented so far)', 'AJTG_TrendlineStrategy_EA.mq5 (in development - automation layer only, not yet reconciled against presentation)', 'Backtest Vault (4 categories)'],

    updated_at = now()
WHERE strategy_name = 'AJTG Trendline Trading Strategy' AND version = '3.0';
