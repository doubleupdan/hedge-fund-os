"""
base.py — Abstract interface every market data provider must implement.

This exists so the choice of data vendor (see docs/decision-log/OPEN-QUESTIONS.md
#2) never leaks into server.py's tool definitions or into agent code that
calls this MCP server. Swapping vendors — or running two in parallel for
redundancy later — should mean writing one new file here, nothing else.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import datetime
from typing import Literal, Optional


@dataclass
class Quote:
    symbol: str
    price: float
    bid: Optional[float]
    ask: Optional[float]
    timestamp: datetime
    source: str  # provider name, for traceability when data looks wrong


@dataclass
class Bar:
    timestamp: datetime
    open: float
    high: float
    low: float
    close: float
    volume: Optional[float]


@dataclass
class SymbolInfo:
    symbol: str
    name: str
    asset_class: str  # matches the CHECK constraint values in schemas/postgres/002_trades.sql
    exchange: Optional[str]


Timeframe = Literal["1m", "5m", "15m", "1h", "4h", "1d", "1w"]


class MarketDataProvider(ABC):
    """Every concrete provider (e.g. PolygonProvider, TwelveDataProvider)
    implements this. Keep implementations read-only — no order methods
    belong on this interface, ever."""

    @abstractmethod
    def get_quote(self, symbol: str) -> Quote:
        ...

    @abstractmethod
    def get_historical_bars(
        self, symbol: str, timeframe: Timeframe, start: datetime, end: datetime
    ) -> list[Bar]:
        ...

    @abstractmethod
    def search_symbols(self, query: str, asset_class: Optional[str] = None) -> list[SymbolInfo]:
        ...
