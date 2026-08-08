-- =============================================================================
-- 007_trendline_strategy_from_presentation.sql
-- Phase 2 (correction): Rebuild AJTG Trendline Trading Strategy entry/exit
-- rules from the actual presentation PDF (AJTG_Trendline_Strategy_Presentation),
-- which is the settled, teachable source of truth for how the strategy is
-- identified and taken by hand. The EA (AJTG_TrendlineStrategy_EA.mq5) is
-- still under active development per founder — its parameters are kept but
-- explicitly labeled as the EA's own automation layer, not necessarily
-- identical to the manual/discretionary method taught in the presentation.
--
-- This does not reduce the row count in strategies (still one row for
-- Trendline v3.0) — it corrects entry_rules, exit_rules, and summary, and
-- restructures risk_parameters to clearly separate "presentation method"
-- from "EA parameters (in development, unverified against presentation)."
-- =============================================================================

UPDATE strategies
SET
    summary = 'Trendline break/continuation strategy built on a swing-point trend identification method (Smart Money Concepts/ICT-influenced), with RSI(14) used as both the entry-timing filter and the primary exit signal. Four distinct setups: Continuation (Uptrend), Continuation (Downtrend), Breakout (Uptrend), Breakout (Downtrend) — each with its own 5-step identification process taught step-by-step in the AJTG_Trendline_Strategy_Presentation. Currently under active backtesting for the swing-trading version, Gold (XAUUSD) only. A dedicated EA is in development but is NOT the source of truth for the rules below — the presentation is.',

    entry_rules = 'Shared 5-step process for all 4 setups:

STEP 1 — Identify trend: Uptrend = Low, High, then Higher Low, Higher High. Downtrend = High, Low, then Lower High, Lower Low.

STEP 2 — Draw trendline: Uptrend connects the FIRST LOW to the SECOND LOW. Downtrend connects the FIRST HIGH to the SECOND HIGH. Use the trendline tool then extend with the ray tool. Prefer trendlines with the most candlestick body touches (connect bodies, not wicks).

STEP 3 — Continuation or Breakout classification: wait for the 3rd swing point (3rd low for uptrend setups, connecting 2nd high to 3rd low / 2nd low to 3rd high per direction) to form. Wait for candle CLOSE before classifying.
  - Continuation: price reaches the trendline, respects it, and rejects/bounces off it → draw the action line (connects to candle tops).
  - Breakout: price reaches the trendline and closes through it (does not respect it) → proceed to Step 4 for entry zone.

STEP 4 — Find entry zone (2 sub-steps):
  1. Wait for the break: for Continuation setups, the first candle in the direction of the trendline that closes above/through the action line confirms the continuation. For Breakout setups, the first candle that closes through the trendline itself confirms the breakout.
  2. Draw entry zone: the SECOND candlestick after the confirming candle from step 1 defines the entry zone.

STEP 5 — Entry confirmation via RSI(14), two variants:
  - Aggressive Entry: on the candle immediately following entry-zone formation, if RSI is at or near 50 (50-52), enter. If not, wait until RSI reaches that zone.
  - Conservative Entry: wait for price to push away from the entry zone, then for a retest of the entry zone; if RSI is at/near 50 on the retest, enter. If not, wait until RSI reaches that zone.',

    exit_rules = 'Primary exit confirmation is RSI(14) reaching 70 (for buy/long exits) or 30 (for sell/short exits).
  - If price has not yet reached the RSI exit level, either wait for it or use other exit confirmations to capture profit incrementally (see "managing and scaling in trades" presentation, not yet in this system).
  - If price HAS reached the RSI exit level and the trader wants to extend the position, set a trailing stop loss to guarantee a break-even-or-better exit, then wait for further exit confirmation to capture additional pips.
  - Explicit discipline note from the source material: do not be greedy — adjust stop loss as the trade moves into profit, and prefer taking profit when an exit confirmation hits over trying to catch additional profit and ending up giving back gains or losing the trade entirely.',

    position_sizing_rules = 'Not specified in the presentation material reviewed so far (the presentation covers setup identification and entry/exit, not position sizing). Presentation folder structure references a separate "Trading Checklist" and "Setting up MT5 for Taking Trades" module — position sizing rules may live there and have not yet been extracted into this system.',

    risk_parameters = '{
        "presentation_method": {
            "exit_type": "RSI-based, not fixed pip targets",
            "rsi_period": 14,
            "entry_rsi_zone": "50 to 52",
            "exit_rsi_long": 70,
            "exit_rsi_short": 30,
            "note": "This is the discretionary/manual method taught in AJTG_Trendline_Strategy_Presentation. No fixed SL/TP pip values are specified in this source."
        },
        "ea_automation_layer": {
            "status": "EA still under active development per founder (as of 2026-08-08) - NOT yet verified to match or supersede the presentation method",
            "sl_pips": 150, "tp1_pips": 100, "tp2_pips": 200, "tp3_pips": 300,
            "partial_close_sequence_pct": [25, 25, 25, 25],
            "instrument_note": "pip values are Gold (XAUUSD)-specific, do not assume they transfer to other instruments",
            "source": "extracted from AJTG_TrendlineStrategy_EA.mq5 source code by a separate session - treat as provisional until EA development is finalized and the EA is reconciled against or explicitly differentiated from the presentation method"
        }
    }'::jsonb,

    underlying_framework = 'Swing-point trend identification (higher-high/higher-low or lower-high/lower-low sequencing) with RSI(14) entry/exit timing. Presentation materials reference broader AJTG Smart Money Concepts/ICT curriculum (market structure, liquidity, order blocks, FVGs) as contextual background, but the Trendline Strategy itself as taught is a self-contained trendline + RSI method, not a full SMC/ICT execution system.',

    known_risk_flags = ARRAY[
        'EA has not yet had a line-by-line human code review (required before any live/scaled use per repo policy - see CLAUDE.md), and is still under active development - its parameters are NOT confirmed to match the presentation method',
        'Position sizing methodology is not specified in the presentation material reviewed so far - needs the "Trading Checklist" or "Setting up MT5" module before this strategy has a complete, tradeable rule set',
        'Backtest currently limited to Gold (XAUUSD) only - results should not be assumed to generalize to other instruments',
        'Correlation and news-blackout risk checks in the validation gate are not yet wired for this or any strategy (see scripts/risk/validate_trade.py)',
        'Only the swing-trading variant is currently being tested; other timeframe variants (if any) are undocumented',
        'Exit method is discretionary/RSI-based per the presentation, which does not translate directly into the fixed SL/TP pip fields on proposed_trades/trades - entries logged for this strategy should note whether they followed the presentation method or the EA method'
    ],

    source_materials = ARRAY['AJTG_Trendline_Strategy_Presentation.pptx (PRIMARY SOURCE for entry/exit rules)', 'AJTG_TrendlineStrategy_EA.mq5 (in development - automation layer only, not yet reconciled against presentation)', 'Backtest Vault (4 categories)'],

    updated_at = now()
WHERE strategy_name = 'AJTG Trendline Trading Strategy' AND version = '3.0';
