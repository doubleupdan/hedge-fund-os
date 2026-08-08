# Decision 0004: Presentation PDF as primary source over EA-derived summary

**Date:** 2026-08-08
**Status:** Decided
**Owner:** Founder + Chief AI Operating Partner

## Context

The `strategies` row for "AJTG Trendline Trading Strategy" (migration `005`)
was originally populated using detail from a separate prior conversation
("AJTG folder memory chat"), which had extracted entry/exit rules by
reading the EA source code (`AJTG_TrendlineStrategy_EA.mq5`). The founder
clarified that the EA is **still under active development**, and that the
`AJTG_Trendline_Strategy_Presentation` (a step-by-step visual walkthrough
with annotated MT5 chart screenshots) is the actual settled, teachable
source of truth for how the strategy is identified and manually traded.

## Decision

Rebuilt `entry_rules`, `exit_rules`, `summary`, and `risk_parameters` from
the presentation PDF directly (uploaded and read in this conversation),
rather than from the EA-derived summary. Key differences the correction
surfaced:

- **Exit method**: the presentation teaches an RSI(14)-based exit (70 for
  longs, 30 for shorts, with trailing-stop extension), not fixed SL/TP pip
  targets. The previously-stored EA parameters (SL 150 / TP1 100 / TP2 200
  / TP3 300 pips, 25/25/25/25 partial close) may be real and specific to
  the EA's own automation logic, but are not the same thing as the
  presentation's manual method — the two should not be conflated as one
  "the strategy's risk parameters."
- **Entry timing**: the presentation specifies a precise RSI entry
  condition (at/near 50, specifically 50-52 for the aggressive variant)
  that the EA-derived summary only loosely described as "an RSI filter."
- **Setup classification**: the presentation's 5-step process per setup
  (identify trend → draw trendline → classify continuation vs. breakout at
  the 3rd swing point → find entry zone via a 2-candle confirmation → RSI
  entry confirmation) is now captured precisely, including the
  Aggressive-vs-Conservative entry variants.

`risk_parameters` was restructured into two clearly labeled sub-objects —
`presentation_method` and `ea_automation_layer` — rather than overwriting
one with the other. This preserves both pieces of real information while
making explicit that they come from different sources at different levels
of maturity, and that the EA layer is provisional until development
finishes and it's reconciled against (or explicitly differentiated from)
the presentation method.

## Alternatives considered

- **Simply overwrite the EA-derived fields with the presentation's** —
  rejected. The EA parameters aren't necessarily wrong, just
  unverified/in-progress and possibly describing a different execution
  mode (automated) than the presentation (manual/discretionary). Deleting
  them would lose real information.
- **Keep the EA-derived version as primary, add presentation detail as a
  note** — rejected per explicit founder instruction that the presentation
  is the source of truth for how the strategy works; the EA is not done.

## Consequences

- Any future trade logged against this strategy should note whether it
  followed the presentation's RSI-based exit method or the EA's fixed-pip
  method, since they are not interchangeable — this is now flagged in
  `known_risk_flags`.
- When the EA is finalized, a follow-up migration should reconcile
  `ea_automation_layer` against `presentation_method` — either confirming
  they converge, or explicitly documenting how/why the automated version
  differs from the manual one.
- Position sizing rules remain unspecified — the presentation module
  reviewed so far doesn't cover sizing; likely lives in the separate
  "Trading Checklist" or "Setting up MT5 for Taking Trades" modules
  referenced in the presentation's own table of contents, not yet
  extracted into this system.

## Addendum: Second correction pass (migration 008, same day)

A deliberate, full slide-by-slide re-review — including chart image
annotations, not just slide text — surfaced two further corrections:

1. **Exit logic was still wrong.** This decision's original correction
   (migration 007) stated the exit was RSI(70/30) alone. Chart annotations
   on the Step 5b slides (e.g. "70 RSI: NO / RR TP Hit: YES") show the
   real exit confirmation is a **two-part checklist**: RSI reaching 70/30
   *and/or* an RR (risk:reward) take-profit target being hit. The specific
   RR ratio value is not stated anywhere in the module reviewed —
   `risk_parameters.presentation_method.rr_take_profit_ratio` is marked
   explicitly `"NOT DOCUMENTED"` rather than filled with a plausible
   number.
2. **Step 1 reframed** as two independently-defined trend-identification
   methods (Uptrend, Downtrend) per founder correction, rather than
   implying one is simply the mirror of the other. Step 2's downtrend
   trendline construction (connect FIRST HIGH to SECOND HIGH) was already
   correct in migration 007 and is now founder-confirmed rather than only
   PDF-inferred.

This addendum is the concrete lesson: a first read of source material,
even a careful one, can still miss detail that only surfaces on a second,
slower pass focused specifically on image content rather than slide text.
Where a value is referenced but not stated (the RR ratio here), the
correct move is to mark it unknown, not to infer a plausible-sounding
number — an incorrect but confident-looking number in a risk-relevant
system is worse than an honest gap.

Full modules 2–5 of the presentation (Entry/Exit Confirmations detail,
MT5 setup, Trading Checklist, Documenting/Reviewing Trades) have still
not been provided to this system as of migration 008 — flagged in
`known_risk_flags` rather than guessed at.

## Addendum 2: Third correction pass (migration 009, same day)

Founder supplied direct corrections, superseding parts of migration 008's
still-imperfect understanding:

1. **RR ratio confirmed as 2:1** — no longer marked undocumented.
2. **Exit signals are interchangeable, not an ambiguous checklist.**
   Migration 008 correctly identified two exit signals (RSI 70/30 and an
   RR take-profit) but left their combination logic unstated. Founder
   clarified: whichever fires first is actionable immediately; the trader
   may instead hold for the second signal to pursue further profit. This
   is now stated plainly rather than flagged as an open question.
3. **RSI entry range corrected and made direction-specific.** Migration
   008 stated a single "50–52" range for all entries. The actual rule is
   direction-specific: buys/longs use RSI 50–54, sells/shorts use RSI
   50–46. This was a real error, not just an imprecision — a single
   symmetric range was wrong for a strategy with direction-dependent
   entries.
4. **Aggressive/Conservative entry definitions refined.** Aggressive =
   first candle after the entry zone, if RSI qualifies at that point (not
   a fixed number tied to "aggressive" specifically). Conservative = entry
   zone retest that *holds* (not just touches), combined with RSI
   qualifying at that point.
5. **Step 2 reframed with explicit "two options" structure**, matching
   Step 1's framing, per founder correction — Uptrend (connect lows) or
   Downtrend (connect highs) as two named choices rather than one rule
   with an implied inverse case.
6. A speculative but flagged-as-unconfirmed observation was added: the
   EA's SL 150 / TP2 300 pip values work out to exactly a 2:1 ratio,
   matching the now-confirmed RR figure — this may mean the EA and
   presentation methods are more aligned than earlier migrations assumed,
   but this is stated as a hypothesis to verify, not a confirmed fact.

The lesson from this round: even a careful second pass can still leave
real ambiguity (the exit "checklist" framing) that only gets resolved by
asking the source directly rather than continuing to infer from images
alone. Where migration 008 correctly flagged something as uncertain
rather than guessing, that discipline paid off — the founder was able to
give a precise, confident correction because the earlier version had
honestly marked the gap instead of asserting a wrong answer.

## Addendum 3: Fourth correction pass (migration 010, same day) — new source document

Founder provided a second, distinct primary source: the **AJTG Trading
Journal** template, which contains a compact checklist form of the same
strategy (labeled Setup A "Continuation — The Bounce" and Setup B
"Breakout — The Reversal") plus a full exit confirmation list, a hard
invalidation rule, and binding checklist discipline language.

**Apparent contradiction resolved, not real:** the checklist describes
Breakout's confirming candle as closing "in opposite direction of the
trend line/safety line," which read as conflicting with the
presentation's framing until re-examined. Both sources describe the same
mechanism — "direction" in the checklist refers to direction *relative to
the line being broken*, not direction relative to the original trend.
Continuation's action-line break continues "in direction of the trend
line" (same slope, same trend); Breakout's line break goes against the
trendline's own slope, which in a genuine reversal setup often also means
against the original trend — hence "THE REVERSAL" as its name. No
correction to the underlying rules was needed here, only to how the
distinction was worded.

**New information incorporated:**
- Exit confirmations expanded from 2 to 6 signals: RSI(70/30) and 2:1 RR
  remain the two *primary, interchangeable* signals (per migration 009);
  four secondary confirmations are now documented — S/R rejection, chart
  patterns (double top/bottom, wedge, flag), market structure shift, and
  RSI divergence/convergence.
- **Zero Tolerance Rule** added as a hard, binding invalidation condition:
  RSI at 60 during a SELL invalidates the trade regardless of other
  confirmations. Flagged in `known_risk_flags` as not yet code-enforced —
  a real gap between documented rule and system behavior.
- **Checklist discipline rule** ("all boxes checked = valid, any deviation
  = no trade") captured as binding strategy-level discipline, separate
  from and in addition to this system's own risk-limits gate.
- Entry RSI: the journal's simpler "RSI at 50 level" phrasing is noted as
  shorthand for the more precise direction-specific range already
  captured (50–54 buys / 50–46 sells, migration 009) — kept as
  complementary, not conflicting.

**New table added:** `trade_journal_entries` — a reflective/discipline
record (psychology, checklist adherence, self-review notes) distinct from
the transactional `trades` table, modeled directly on the journal
document's own fields (session, RR achieved, emotion before/after, "why
did I take this trade," "what would I improve").
