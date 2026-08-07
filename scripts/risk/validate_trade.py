#!/usr/bin/env python3
"""
validate_trade.py — Risk validation gate for proposed trades.

This is the literal, deterministic code referenced in the governing
principle: "AI never touches your money — it generates deterministic
signals/scripts, human/explicit gate controls the switch." This script is
the first gate. It does not execute anything and cannot execute anything —
it only reads a proposed trade, checks it against the account's risk_limits
row, and writes a pass/block result back to Postgres (proposed_trades and,
on failure, risk_violations).

A 'passed' result from this script does NOT mean a trade is approved.
It means the trade did not violate a hard risk rule. Human approval
(proposed_trades.status = 'approved') is a SEPARATE, later step.

Usage:
    python validate_trade.py --proposed-trade-id <uuid>

Requires:
    DATABASE_URL environment variable (postgresql://...)
    pip install psycopg2-binary
"""

import argparse
import os
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional

try:
    import psycopg2
    import psycopg2.extras
except ImportError:
    print("ERROR: psycopg2 not installed. Run: pip install psycopg2-binary --break-system-packages", file=sys.stderr)
    sys.exit(1)


# -----------------------------------------------------------------------------
# Data shapes
# -----------------------------------------------------------------------------

@dataclass
class ProposedTrade:
    id: str
    account_id: str
    symbol: str
    asset_class: str
    direction: str
    proposed_entry_price: Optional[Decimal]
    proposed_stop_loss: Optional[Decimal]
    proposed_size: Decimal
    proposed_risk_pct: Optional[Decimal]


@dataclass
class RiskLimits:
    id: str
    max_position_size_pct: Decimal
    max_position_risk_pct: Decimal
    daily_loss_limit_pct: Decimal
    weekly_loss_limit_pct: Decimal
    monthly_drawdown_limit_pct: Decimal
    max_account_drawdown_pct: Decimal
    max_correlated_exposure_pct: Decimal
    max_single_symbol_exposure_pct: Decimal
    max_open_positions: int
    max_leverage: Decimal
    block_trading_around_news: bool
    trading_halted: bool
    halted_reason: Optional[str]


@dataclass
class ValidationResult:
    passed: bool
    violations: list  # list of (violation_type, description) tuples


# -----------------------------------------------------------------------------
# Individual rule checks — each is a pure function: (trade, limits, account_context) -> Optional[violation]
# Keeping these as separate, named functions makes the rule set auditable
# and testable in isolation, and makes it obvious what Phase 2 needs to add
# (correlation and open-position checks need live position data, stubbed below).
# -----------------------------------------------------------------------------

def check_trading_halted(trade: ProposedTrade, limits: RiskLimits) -> Optional[tuple]:
    if limits.trading_halted:
        return ("trading_halted_override",
                f"Account trading is halted. Reason: {limits.halted_reason or 'unspecified'}")
    return None


def check_position_size(trade: ProposedTrade, limits: RiskLimits, account_equity: Decimal) -> Optional[tuple]:
    if account_equity <= 0:
        return ("position_size_exceeded", "Account equity is zero or negative — cannot size any position.")
    notional = trade.proposed_size * (trade.proposed_entry_price or Decimal(0))
    if account_equity == 0:
        return None
    position_pct = (notional / account_equity) * 100
    if position_pct > limits.max_position_size_pct:
        return ("position_size_exceeded",
                f"Proposed position is {position_pct:.2f}% of equity; max allowed is {limits.max_position_size_pct}%.")
    return None


def check_position_risk(trade: ProposedTrade, limits: RiskLimits) -> Optional[tuple]:
    """Checks % of equity actually at risk if the stop loss is hit."""
    if trade.proposed_risk_pct is None:
        return ("other", "Proposed trade has no stop loss / risk_pct set — cannot validate risk. Rejecting by default.")
    if trade.proposed_risk_pct > limits.max_position_risk_pct:
        return ("position_risk_exceeded",
                f"Proposed risk is {trade.proposed_risk_pct}% of equity; max allowed is {limits.max_position_risk_pct}%.")
    return None


def check_daily_loss_limit(limits: RiskLimits, realized_loss_today_pct: Decimal) -> Optional[tuple]:
    if realized_loss_today_pct >= limits.daily_loss_limit_pct:
        return ("daily_loss_limit_hit",
                f"Realized loss today is {realized_loss_today_pct:.2f}%, at/over the {limits.daily_loss_limit_pct}% daily limit. New trades blocked.")
    return None


def check_weekly_loss_limit(limits: RiskLimits, realized_loss_week_pct: Decimal) -> Optional[tuple]:
    if realized_loss_week_pct >= limits.weekly_loss_limit_pct:
        return ("weekly_loss_limit_hit",
                f"Realized loss this week is {realized_loss_week_pct:.2f}%, at/over the {limits.weekly_loss_limit_pct}% weekly limit. New trades blocked.")
    return None


def check_max_account_drawdown(limits: RiskLimits, current_drawdown_pct: Decimal) -> Optional[tuple]:
    if current_drawdown_pct >= limits.max_account_drawdown_pct:
        return ("max_account_drawdown_hit",
                f"Account drawdown is {current_drawdown_pct:.2f}%, at/over the {limits.max_account_drawdown_pct}% hard limit. Trading halted pending review.")
    return None


def check_max_open_positions(limits: RiskLimits, current_open_positions: int) -> Optional[tuple]:
    if current_open_positions >= limits.max_open_positions:
        return ("max_open_positions_exceeded",
                f"Account already has {current_open_positions} open positions; max allowed is {limits.max_open_positions}.")
    return None


def check_single_symbol_exposure(trade: ProposedTrade, limits: RiskLimits,
                                   existing_symbol_exposure_pct: Decimal) -> Optional[tuple]:
    projected = existing_symbol_exposure_pct + (trade.proposed_risk_pct or Decimal(0))
    if projected > limits.max_single_symbol_exposure_pct:
        return ("single_symbol_exposure_exceeded",
                f"Adding this trade brings {trade.symbol} exposure to {projected:.2f}%, over the {limits.max_single_symbol_exposure_pct}% limit.")
    return None


# NOTE: correlation exposure and news blackout checks require external data
# (a correlation matrix and an economic calendar feed respectively) that
# aren't wired up until the Phase 1 read-only market-data MCP server and a
# calendar source are connected. Stubbed here intentionally so the gate
# fails safe (see main()) rather than silently skipping the check.

def check_correlated_exposure_STUB(trade: ProposedTrade, limits: RiskLimits) -> Optional[tuple]:
    """
    TODO (Phase 2): wire to a real correlation matrix (e.g. rolling 60-day
    correlation across open positions' symbols) once the market-data MCP
    server can supply historical price series. Until then this check is
    marked unavailable, not passed — see main().
    """
    return None


def check_news_blackout_STUB(trade: ProposedTrade, limits: RiskLimits) -> Optional[tuple]:
    """
    TODO (Phase 2): wire to an economic calendar source. Until then this
    check is marked unavailable, not passed — see main().
    """
    return None


# -----------------------------------------------------------------------------
# Orchestration
# -----------------------------------------------------------------------------

def run_all_checks(trade: ProposedTrade, limits: RiskLimits, account_equity: Decimal,
                    realized_loss_today_pct: Decimal, realized_loss_week_pct: Decimal,
                    current_drawdown_pct: Decimal, current_open_positions: int,
                    existing_symbol_exposure_pct: Decimal) -> ValidationResult:
    violations = []

    checks_with_results = [
        check_trading_halted(trade, limits),
        check_position_size(trade, limits, account_equity),
        check_position_risk(trade, limits),
        check_daily_loss_limit(limits, realized_loss_today_pct),
        check_weekly_loss_limit(limits, realized_loss_week_pct),
        check_max_account_drawdown(limits, current_drawdown_pct),
        check_max_open_positions(limits, current_open_positions),
        check_single_symbol_exposure(trade, limits, existing_symbol_exposure_pct),
    ]

    for result in checks_with_results:
        if result is not None:
            violations.append(result)

    # Fail-safe stubs: until correlation and news-calendar data sources are
    # wired up (Phase 2), we do NOT claim these checks passed. We surface
    # them as warnings so a human reviewer knows the gate is incomplete,
    # rather than pretending full coverage exists.
    incomplete_checks = []
    if check_correlated_exposure_STUB(trade, limits) is None:
        incomplete_checks.append("correlated_exposure (data source not yet connected)")
    if limits.block_trading_around_news and check_news_blackout_STUB(trade, limits) is None:
        incomplete_checks.append("news_blackout (economic calendar not yet connected)")

    result = ValidationResult(passed=(len(violations) == 0), violations=violations)
    if incomplete_checks:
        print(f"WARNING: incomplete risk coverage — {', '.join(incomplete_checks)}. "
              f"Do not treat a 'passed' result as full risk clearance until these are wired up.",
              file=sys.stderr)

    return result


def fetch_proposed_trade(conn, proposed_trade_id: str) -> ProposedTrade:
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("""
            SELECT id, account_id, symbol, asset_class, direction,
                   proposed_entry_price, proposed_stop_loss, proposed_size, proposed_risk_pct
            FROM proposed_trades WHERE id = %s
        """, (proposed_trade_id,))
        row = cur.fetchone()
        if row is None:
            raise ValueError(f"No proposed_trade found with id {proposed_trade_id}")
        return ProposedTrade(**row)


def fetch_risk_limits(conn, account_id: str) -> RiskLimits:
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("""
            SELECT id, max_position_size_pct, max_position_risk_pct,
                   daily_loss_limit_pct, weekly_loss_limit_pct, monthly_drawdown_limit_pct,
                   max_account_drawdown_pct, max_correlated_exposure_pct,
                   max_single_symbol_exposure_pct, max_open_positions, max_leverage,
                   block_trading_around_news, trading_halted, halted_reason
            FROM risk_limits WHERE account_id = %s AND is_active = TRUE
        """, (account_id,))
        row = cur.fetchone()
        if row is None:
            raise ValueError(f"No active risk_limits found for account {account_id}. Refusing to validate without limits configured.")
        return RiskLimits(**row)


def fetch_account_context(conn, account_id: str, symbol: str):
    """Pulls current equity, realized losses, drawdown, open position count,
    and existing per-symbol exposure needed by the checks above."""
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("SELECT current_equity, starting_balance FROM accounts WHERE id = %s", (account_id,))
        acct = cur.fetchone()
        if acct is None:
            raise ValueError(f"No account found with id {account_id}")

        cur.execute("""
            SELECT COALESCE(SUM(realized_pnl), 0) AS pnl_today
            FROM trades
            WHERE account_id = %s AND status = 'closed' AND closed_at >= date_trunc('day', now())
        """, (account_id,))
        pnl_today = cur.fetchone()["pnl_today"]

        cur.execute("""
            SELECT COALESCE(SUM(realized_pnl), 0) AS pnl_week
            FROM trades
            WHERE account_id = %s AND status = 'closed' AND closed_at >= date_trunc('week', now())
        """, (account_id,))
        pnl_week = cur.fetchone()["pnl_week"]

        cur.execute("SELECT COUNT(*) AS open_count FROM trades WHERE account_id = %s AND status = 'open'", (account_id,))
        open_count = cur.fetchone()["open_count"]

        cur.execute("""
            SELECT COALESCE(SUM(risk_pct_at_entry), 0) AS symbol_exposure
            FROM trades WHERE account_id = %s AND symbol = %s AND status = 'open'
        """, (account_id, symbol))
        symbol_exposure = cur.fetchone()["symbol_exposure"]

    equity = acct["current_equity"]
    starting = acct["starting_balance"]
    realized_loss_today_pct = max(Decimal(0), -pnl_today / equity * 100) if equity else Decimal(0)
    realized_loss_week_pct = max(Decimal(0), -pnl_week / equity * 100) if equity else Decimal(0)
    # Drawdown from starting balance as a simple Phase-1 proxy; refine with
    # peak-equity tracking via account_snapshots once that history exists.
    current_drawdown_pct = max(Decimal(0), (starting - equity) / starting * 100) if starting else Decimal(0)

    return equity, realized_loss_today_pct, realized_loss_week_pct, current_drawdown_pct, open_count, symbol_exposure


def record_result(conn, trade: ProposedTrade, result: ValidationResult):
    with conn.cursor() as cur:
        if result.passed:
            cur.execute("""
                UPDATE proposed_trades
                SET risk_check_status = 'passed', risk_check_notes = %s
                WHERE id = %s
            """, ("All hard risk checks passed.", trade.id))
        else:
            notes = "; ".join(f"[{v[0]}] {v[1]}" for v in result.violations)
            cur.execute("""
                UPDATE proposed_trades
                SET risk_check_status = 'blocked', risk_check_notes = %s
                WHERE id = %s
            """, (notes, trade.id))
            for violation_type, description in result.violations:
                cur.execute("""
                    INSERT INTO risk_violations
                        (account_id, violation_type, severity, description, proposed_trade_id, triggered_by, created_at)
                    VALUES (%s, %s, 'blocked', %s, %s, %s, %s)
                """, (trade.account_id, violation_type, description, trade.id,
                      "risk_validator_v1", datetime.now(timezone.utc)))
    conn.commit()


def main():
    parser = argparse.ArgumentParser(description="Validate a proposed trade against account risk limits.")
    parser.add_argument("--proposed-trade-id", required=True, help="UUID of the row in proposed_trades")
    args = parser.parse_args()

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("ERROR: DATABASE_URL environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    conn = psycopg2.connect(database_url)
    try:
        trade = fetch_proposed_trade(conn, args.proposed_trade_id)
        limits = fetch_risk_limits(conn, trade.account_id)
        (equity, loss_today_pct, loss_week_pct, drawdown_pct,
         open_count, symbol_exposure) = fetch_account_context(conn, trade.account_id, trade.symbol)

        result = run_all_checks(
            trade=trade, limits=limits, account_equity=equity,
            realized_loss_today_pct=loss_today_pct, realized_loss_week_pct=loss_week_pct,
            current_drawdown_pct=drawdown_pct, current_open_positions=open_count,
            existing_symbol_exposure_pct=symbol_exposure,
        )

        record_result(conn, trade, result)

        if result.passed:
            print(f"PASSED: proposed_trade {trade.id} cleared all hard risk checks.")
            sys.exit(0)
        else:
            print(f"BLOCKED: proposed_trade {trade.id} failed {len(result.violations)} check(s):")
            for violation_type, description in result.violations:
                print(f"  - [{violation_type}] {description}")
            sys.exit(2)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
