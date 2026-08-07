# SOP: Risk Validation Gate

**Owner:** Risk Management
**Applies to:** every proposed trade, regardless of which agent or human generated it
**Related code:** `/scripts/risk/validate_trade.py`
**Related schema:** `/schemas/postgres/001_accounts_and_risk_limits.sql`, `002_trades.sql`

## Purpose

No proposed trade reaches a human approval queue — let alone an account —
without passing a deterministic, auditable risk check first. This SOP
describes what that gate does and does not do.

## What this gate checks (Phase 1 coverage)

1. Is trading halted on this account? (circuit breaker state)
2. Is the position size within `max_position_size_pct` of equity?
3. Is the risk-if-stopped-out within `max_position_risk_pct` of equity?
4. Has the account hit its `daily_loss_limit_pct`?
5. Has the account hit its `weekly_loss_limit_pct`?
6. Has the account hit its `max_account_drawdown_pct`?
7. Would this exceed `max_open_positions`?
8. Would this push single-symbol exposure over `max_single_symbol_exposure_pct`?

## What this gate does NOT yet check (known Phase 1 gaps)

- **Correlated exposure** across open positions — requires a correlation
  matrix built from historical price series, which requires the market-data
  MCP server to be live and connected. Until then, the script prints an
  explicit warning to stderr rather than silently passing this check.
- **News/event blackout windows** — requires an economic calendar source.
  Same treatment: explicit warning, not a silent pass.

**Operating rule while these gaps exist:** a "PASSED" result from the
script means *only* that the implemented checks passed. Anyone reviewing a
proposed trade for approval should manually sanity-check correlation and
upcoming news risk until Phase 2 closes these gaps.

## What "PASSED" does NOT mean

A passed risk check is not trade approval. It means the trade did not
violate a hard rule. The trade still sits in `proposed_trades` with
`status = 'pending_review'` until a human explicitly sets it to `approved`.
Risk clearance and approval are two separate gates by design.

## What happens on a block

1. `proposed_trades.risk_check_status` is set to `blocked`.
2. One row per violated rule is written to `risk_violations` with
   `severity = 'blocked'`.
3. The proposed trade does not advance. It is not deleted — it stays as a
   record of what was proposed and why it was blocked.

## Overriding a block

Overrides are supported at the schema level (`risk_violations.severity =
'override_approved'`, with `override_approved_by` and `override_reason`
required) but there is **no automated override path** in Phase 1. Any
override is a manual, logged, human decision — never a script setting.
This is intentional: overrides should be rare and visible, not a
convenience toggle.

## Changing a risk limit

Risk limits (`risk_limits` table) should not be edited silently. Any
change should be paired with a row in `decisions`
(`decision_type = 'risk_limit_change'`) stating the rationale. See
`/schemas/postgres/003_research_and_decisions.sql`.

## Open gaps to close in Phase 2

- Wire correlation-matrix data once the market-data MCP server is live.
- Wire an economic calendar source for news blackout enforcement.
- Add automated position-level monitoring (not just at proposal time) so a
  position that becomes non-compliant *after* entry — e.g. due to a
  correlated position added later — gets flagged, not just new proposals.
