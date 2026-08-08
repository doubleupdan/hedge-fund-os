-- =============================================================================
-- 009_trendline_strategy_correction_v3.sql
-- Phase 2 (correction #3): Founder-supplied corrections to migration 008.
--
-- Corrections in this pass:
-- 1. RR (risk:reward) take-profit ratio is 2:1 - founder-confirmed, no
--    longer marked "NOT DOCUMENTED."
-- 2. Exit logic corrected again: RSI(70/30) and RR-TP-hit are
--    INTERCHANGEABLE exit signals, not two independently-tracked
--    checklist items with unclear combination logic (as migration 008
--    left it). Whichever fires first is the primary signal; the trader
--    then chooses to take it or hold for the second confirmation to
--    pursue more profit.
-- 3. RSI entry zone corrected and made direction-specific (migration 008
--    had a single "50-52" range applied to all entries - this was
--    imprecise): BUYS/LONGS use RSI 50-54, SELLS/SHORTS use RSI 50-46.
-- 4. Aggressive entry refined: it is the candlestick immediately after
--    the entry zone candle, IF RSI lines up with the (now
--    direction-specific) entry requirement at that point - not a fixed
--    "50-52 for aggressive" rule as previously stated.
-- 5. Conservative entry refined: taken after a retest of the entry zone
--    has occurred AND HELD (not merely touched), combined with RSI
--    lining up with the entry requirement at that point.
-- 6. Step 2 (trendline construction) reframed with the same "two
--    distinct options" structure as Step 1 (Uptrend method OR Downtrend
--    method), per founder correction - this had been implicitly
--    structured this way in the entry_rules text but not explicitly
--    framed as "two options" the way Step 1 now is.
--
-- No change in this pass to the breakout-vs-continuation / action-line
-- logic from migration 008 - founder did not flag that as incorrect.
-- =============================================================================

UPDATE strategies
SET
    summary = 'Trendline break/continuation strategy using swing-point trend identification, with two distinct options at both Step 1 (trend identification: Uptrend or Downtrend) and Step 2 (trendline construction: connect lows for uptrend, connect highs for downtrend). RSI(14) is used for entry timing (direction-specific range: 50-54 for buys, 50-46 for sells) and exit is confirmed by two INTERCHANGEABLE signals - RSI reaching 70 (longs)/30 (shorts), or a 2:1 risk:reward take-profit target being hit - whichever fires first, with the option to hold for the second signal to pursue more profit. Four setups: Continuation (Uptrend), Continuation (Downtrend), Breakout (Uptrend), Breakout (Downtrend), each with its own 5-step identification process taught in AJTG_Trendline_Strategy_Presentation. Currently under active backtesting for the swing-trading version, Gold (XAUUSD) only. A dedicated EA is in development but is NOT the source of truth for the rules below - the presentation is. NOTE: the presentation''s own table of contents references 4 further modules (Entry/Exit Confirmations detail, MT5 setup, Trading Checklist, Documenting/Reviewing Trades) not yet fully captured in this system - see known_risk_flags.',

    entry_rules = 'STEP 1 - Identify trend: two options.
  Option A (Uptrend): sequence of Low, High, THEN Higher Low, Higher High.
  Option B (Downtrend): sequence of High, Low, THEN Lower High, Lower Low.

STEP 2 - Draw trendline: two options, matched to the direction identified in Step 1.
  Option A (Uptrend): connect the FIRST LOW to the SECOND LOW.
  Option B (Downtrend): connect the FIRST HIGH to the SECOND HIGH.
  Use the trendline tool, then extend with the ray tool. Prefer trendlines with the most candlestick body touches (connect bodies, not wicks).

STEP 3 - Continuation or Breakout classification: wait for the 3rd swing point to form (3rd low for uptrend setups via 2nd High to 3rd Low connection; 3rd high for downtrend setups via 2nd Low to 3rd High connection). Wait for candle CLOSE before classifying.
  - Continuation: price reaches the trendline, respects it, and rejects/bounces off it -> draw an action line (connects to candle tops).
  - Breakout: price reaches the trendline and CLOSES THROUGH it (does not respect it) -> proceed to Step 4. Breakout setups do not require a separate action line - the trendline break itself is the Step 4 confirmation signal (this differs from Continuation setups, which confirm via the action line).

STEP 4 - Find entry zone (2 sub-steps, confirmation signal differs by setup type):
  1. Wait for the break:
     - Continuation setups: the first candle in trend direction that closes above/through the ACTION LINE confirms the continuation.
     - Breakout setups: the first candle that closes through the TRENDLINE ITSELF confirms the breakout (no action line involved).
  2. Draw entry zone: the SECOND candlestick after the confirming candle from step 1 defines the entry zone (same rule for both setup types).

STEP 5 - Entry confirmation via RSI(14), direction-specific range, two entry styles:
  RSI entry requirement (corrected - direction-specific, not a single range for all entries):
    - Buys/Longs: RSI between 50 and 54.
    - Sells/Shorts: RSI between 50 and 46.

  Aggressive Entry: the first entry opportunity is the candlestick immediately AFTER the entry-zone candle, IF RSI lines up with the entry requirement above at that point. If RSI does not line up on that candle, wait until it does.

  Conservative Entry: taken after price retests the entry zone AND THAT RETEST HOLDS (not merely touches it), combined with RSI lining up with the entry requirement above at the point the retest holds.
    NOTE: on the Breakout (Uptrend) example specifically, this conservative entry is labeled "Conservative Entry After Liquidity Sweep" - suggesting breakout-setup conservative entries may specifically wait for a liquidity sweep before the retest. Not confirmed whether this applies to all 4 setups or is specific to breakout setups - flagged as an open question, not assumed either way.',

    exit_rules = 'Exit is confirmed by TWO INTERCHANGEABLE signals (corrected from migration 008, which left the combination logic ambiguous):
  1. RSI(14) reaching 70 (for buy/long exits) or 30 (for sell/short exits)
  2. A 2:1 risk:reward take-profit target being hit

These are interchangeable, not sequential or both-required: the trader is watching for EITHER signal to fire first. Once one fires:
  - Take the exit immediately, OR
  - Hold the position and wait for the SECOND signal to also fire, to pursue additional profit - typically paired with setting a trailing stop loss once the first signal has fired, to guarantee a break-even-or-better outcome while holding for more.

Explicit discipline note from the source material: do not be greedy - adjust stop loss as the trade moves into profit, and prefer taking profit when an exit confirmation hits over trying to catch additional profit and ending up giving back gains or losing the trade entirely.',

    position_sizing_rules = 'Not specified in the presentation module reviewed so far (module 1 of 5: "Finding Setups, Charting Setups, Taking Trades"). The presentation''s own table of contents lists 4 further modules - "Trade Entry and Exit Confirmations," "Setting up MT5 for Taking Trades," "Trading Checklist," and "Documenting and Reviewing Trades." Founder has confirmed entry zone, trendline break, and entry confirmation detail all live in the PDF (now captured above); position sizing specifically has not yet been confirmed as present or extracted.',

    risk_parameters = '{
        "presentation_method": {
            "exit_type": "two interchangeable signals: RSI(14) 70/30 OR 2:1 risk:reward take-profit - either can trigger, trader may hold for the second to pursue more profit",
            "rsi_period": 14,
            "entry_rsi_buys": "50 to 54",
            "entry_rsi_sells": "50 to 46",
            "exit_rsi_long": 70,
            "exit_rsi_short": 30,
            "rr_take_profit_ratio": "2:1 (founder-confirmed)",
            "note": "This is the discretionary/manual method taught in AJTG_Trendline_Strategy_Presentation module 1. Corrected in migration 009 (RR ratio confirmed as 2:1, exit signals confirmed interchangeable, entry RSI range corrected to be direction-specific)."
        },
        "ea_automation_layer": {
            "status": "EA still under active development per founder (as of 2026-08-08) - NOT yet verified to match or supersede the presentation method",
            "sl_pips": 150, "tp1_pips": 100, "tp2_pips": 200, "tp3_pips": 300,
            "partial_close_sequence_pct": [25, 25, 25, 25],
            "instrument_note": "pip values are Gold (XAUUSD)-specific, do not assume they transfer to other instruments",
            "source": "extracted from AJTG_TrendlineStrategy_EA.mq5 source code by a separate session - treat as provisional until EA development is finalized and the EA is reconciled against or explicitly differentiated from the presentation method",
            "reconciliation_check": "with RR now confirmed as 2:1, check whether EA TP1/TP2/TP3 pip values (100/200/300 against a 150-pip SL) actually express a 2:1 ratio at some stage - SL 150 vs TP2 300 is exactly 2:1, which may confirm the EA and presentation methods are more aligned than previously assumed. Still unconfirmed - flagged as a hypothesis worth checking, not stated as fact."
        }
    }'::jsonb,

    underlying_framework = 'Swing-point trend identification via two direction-specific options at both trend-ID (Step 1) and trendline construction (Step 2): Uptrend (Low/High/Higher-Low/Higher-High, trendline connects lows) or Downtrend (High/Low/Lower-High/Lower-Low, trendline connects highs). RSI(14) entry timing with direction-specific ranges, and a two-signal interchangeable exit (RSI 70/30 or 2:1 RR). Presentation materials reference broader AJTG Smart Money Concepts/ICT curriculum as contextual background, but the Trendline Strategy itself as taught in module 1 is a self-contained trendline + RSI + 2:1 RR method.',

    known_risk_flags = ARRAY[
        'INCOMPLETE SOURCE MATERIAL: only module 1 of 5 ("Finding Setups, Charting Setups, Taking Trades") has been fully reviewed. Founder confirmed entry zone, trendline break, and entry confirmation detail are all in this module (now captured). Position sizing specifically not yet confirmed as present in module 1 or requiring modules 2-5.',
        'EA has not yet had a line-by-line human code review (required before any live/scaled use per repo policy - see CLAUDE.md), and is still under active development.',
        'Possible but UNCONFIRMED alignment between EA fixed-pip TPs and the presentation''s 2:1 RR (SL 150 / TP2 300 = 2:1) - worth verifying explicitly once EA development finishes, not yet treated as confirmed.',
        'Backtest currently limited to Gold (XAUUSD) only - results should not be assumed to generalize to other instruments.',
        'Only the swing-trading variant is currently being tested; other timeframe variants (if any) are undocumented.',
        'The "Conservative Entry After Liquidity Sweep" label appears only on the Breakout (Uptrend) example chart - unconfirmed whether this liquidity-sweep condition applies to all 4 setups or is specific to breakout setups.',
        'Correlation and news-blackout risk checks in the validation gate are not yet wired for this or any strategy (see scripts/risk/validate_trade.py).'
    ],

    source_materials = ARRAY['AJTG_Trendline_Strategy_Presentation.pptx - module 1 of 5 (PRIMARY SOURCE for entry/exit rules, founder-corrected across migrations 007-009)', 'AJTG_TrendlineStrategy_EA.mq5 (in development - automation layer only, not yet reconciled against presentation)', 'Backtest Vault (4 categories)'],

    updated_at = now()
WHERE strategy_name = 'AJTG Trendline Trading Strategy' AND version = '3.0';
