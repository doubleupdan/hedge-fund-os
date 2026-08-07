#!/usr/bin/env python3
"""
server.py — Read-only market data MCP server.

Exposes exactly three tools: get_quote, get_historical_bars, search_symbols.
Deliberately does NOT expose (and must never grow) any tool that places,
modifies, or cancels an order. See README.md in this directory for the
architecture constraint this enforces.

Provider is selected via the PROVIDER env var. Defaults to the mock
provider so this server runs and is testable before a real vendor is
chosen (see docs/decision-log/OPEN-QUESTIONS.md #2).
"""

import os
from datetime import datetime
from typing import Optional

from mcp.server.fastmcp import FastMCP

from providers.mock_provider import MockProvider
# from providers.<vendor>_provider import <Vendor>Provider  # add once chosen

mcp = FastMCP("market-data-readonly")

PROVIDER_NAME = os.environ.get("PROVIDER", "mock")

if PROVIDER_NAME == "mock":
    provider = MockProvider()
else:
    raise NotImplementedError(
        f"Provider '{PROVIDER_NAME}' is not implemented yet. "
        f"Implement providers/{PROVIDER_NAME}_provider.py against providers/base.py "
        f"and wire it in here — see README.md 'Next steps once a data vendor is chosen'."
    )


@mcp.tool()
def get_quote(symbol: str) -> dict:
    """Get the latest quote for a symbol. Read-only — returns price data only."""
    q = provider.get_quote(symbol)
    return {
        "symbol": q.symbol, "price": q.price, "bid": q.bid, "ask": q.ask,
        "timestamp": q.timestamp.isoformat(), "source": q.source,
    }


@mcp.tool()
def get_historical_bars(symbol: str, timeframe: str, start: str, end: str) -> list[dict]:
    """Get historical OHLCV bars for a symbol.

    timeframe: one of '1m','5m','15m','1h','4h','1d','1w'
    start/end: ISO 8601 datetime strings, e.g. '2026-07-01T00:00:00'
    """
    bars = provider.get_historical_bars(
        symbol, timeframe, datetime.fromisoformat(start), datetime.fromisoformat(end)
    )
    return [
        {"timestamp": b.timestamp.isoformat(), "open": b.open, "high": b.high,
         "low": b.low, "close": b.close, "volume": b.volume}
        for b in bars
    ]


@mcp.tool()
def search_symbols(query: str, asset_class: Optional[str] = None) -> list[dict]:
    """Search for tradable symbols by name or ticker, optionally filtered by asset class."""
    results = provider.search_symbols(query, asset_class)
    return [
        {"symbol": s.symbol, "name": s.name, "asset_class": s.asset_class, "exchange": s.exchange}
        for s in results
    ]


if __name__ == "__main__":
    mcp.run()
