# market-data-readonly MCP server

**Status: scaffolded, not wired to a live data source.**

This server is intentionally built against an abstract data-provider
interface rather than a specific vendor, because the market data source
hasn't been chosen yet (see `docs/decision-log/OPEN-QUESTIONS.md` #2).
When you decide on a provider, implement `providers/base.py`'s interface
for that vendor and wire it in `server.py` — no other code should need to
change.

## Design constraints (non-negotiable per architecture decision)

- **Read-only.** This server exposes tools to *fetch* market data
  (quotes, historical bars, symbol search). It does not and must not
  expose any tool capable of placing, modifying, or cancelling an order.
  Execution-capable MCP servers are a separate, later, hand-reviewed
  build — never bolted onto this one.
- No brokerage credentials of any kind belong in this server or its
  `.env`. If a chosen data vendor happens to be the same company as a
  future broker, still keep the API keys and the codebase separate.

## Planned tools (Phase 1 scope)

- `get_quote(symbol)` — latest price for a symbol
- `get_historical_bars(symbol, timeframe, start, end)` — OHLCV history
- `search_symbols(query, asset_class)` — symbol lookup

## Structure

```
market-data-readonly/
├── server.py           # MCP server entrypoint — tool definitions
├── providers/
│   ├── base.py          # Abstract provider interface (implement this per-vendor)
│   └── mock_provider.py # Deterministic fake data for local dev before a vendor is chosen
├── requirements.txt
└── .env.example
```

## Next steps once a data vendor is chosen

1. Add `providers/<vendor>_provider.py` implementing `MarketDataProvider`.
2. Set `PROVIDER=<vendor>` in `.env`.
3. Add the vendor's API key to `.env` (never commit `.env` — see root `.gitignore`).
4. Update this README's "Planned tools" section to "Live tools" once tested.
