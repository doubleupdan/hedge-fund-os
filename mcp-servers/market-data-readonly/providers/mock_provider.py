"""
mock_provider.py — Deterministic fake data so the MCP server and any agent
code that calls it can be built and tested end-to-end before a real vendor
is chosen. Never point this at anything resembling real capital decisions —
its numbers are synthetic and clearly labeled as such.
"""

import hashlib
import math
from datetime import datetime, timedelta
from typing import Optional

from .base import Bar, MarketDataProvider, Quote, SymbolInfo, Timeframe


def _seeded_price(symbol: str) -> float:
    """Deterministic pseudo-price so repeated calls for the same symbol
    are stable within a session, without needing real market data."""
    digest = hashlib.sha256(symbol.encode()).hexdigest()
    return 10 + (int(digest[:8], 16) % 100000) / 100.0


class MockProvider(MarketDataProvider):
    def get_quote(self, symbol: str) -> Quote:
        price = _seeded_price(symbol)
        spread = price * 0.0005
        return Quote(
            symbol=symbol,
            price=round(price, 4),
            bid=round(price - spread, 4),
            ask=round(price + spread, 4),
            timestamp=datetime.utcnow(),
            source="mock_provider (SYNTHETIC DATA — not real market data)",
        )

    def get_historical_bars(
        self, symbol: str, timeframe: Timeframe, start: datetime, end: datetime
    ) -> list[Bar]:
        base = _seeded_price(symbol)
        bars = []
        step = {
            "1m": timedelta(minutes=1), "5m": timedelta(minutes=5),
            "15m": timedelta(minutes=15), "1h": timedelta(hours=1),
            "4h": timedelta(hours=4), "1d": timedelta(days=1), "1w": timedelta(weeks=1),
        }[timeframe]

        t = start
        i = 0
        while t <= end and i < 500:  # cap to keep mock output bounded
            wobble = math.sin(i / 7) * base * 0.01
            o = base + wobble
            c = o + (math.sin(i / 3) * base * 0.005)
            h = max(o, c) + abs(base * 0.002)
            l = min(o, c) - abs(base * 0.002)
            bars.append(Bar(timestamp=t, open=round(o, 4), high=round(h, 4),
                             low=round(l, 4), close=round(c, 4), volume=1000 + i * 10))
            t += step
            i += 1
        return bars

    def search_symbols(self, query: str, asset_class: Optional[str] = None) -> list[SymbolInfo]:
        catalog = [
            SymbolInfo("EURUSD", "Euro / US Dollar", "forex", "OTC"),
            SymbolInfo("XAUUSD", "Gold / US Dollar", "precious_metal", "OTC"),
            SymbolInfo("US500", "S&P 500 Index", "index", "CME"),
            SymbolInfo("AAPL", "Apple Inc.", "stocks", "NASDAQ"),
            SymbolInfo("WTI", "WTI Crude Oil", "energy", "NYMEX"),
        ]
        results = [s for s in catalog if query.upper() in s.symbol.upper() or query.lower() in s.name.lower()]
        if asset_class:
            results = [s for s in results if s.asset_class == asset_class]
        return results
