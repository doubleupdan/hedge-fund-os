# Open Questions — Needs Founder Input

Items here are blocking or semi-blocking later phases. Nothing in Phase 1
depends on these being answered, by design — the schema is built to be
broker/data-source agnostic. But Phase 2 (paper trading) and the first
MCP server need answers.

## 1. Broker / platform for first live connection
- MT5 is confirmed as a target platform.
- Not yet chosen: which broker, and what the API access path looks like
  (native MT5 API, a bridge like MetaApi, FIX, or broker-specific REST).
- This affects `accounts.platform` / `accounts.broker` values and the
  shape of the future execution MCP server (Phase 3+) — it does **not**
  block Phase 1 schema work, which is broker-agnostic.

## 2. Market data source for the first read-only MCP server
- Candidates to evaluate: broker-native market data feed (if MT5 bridge
  chosen), a dedicated data vendor (e.g. Polygon, Twelve Data, Alpha
  Vantage), or TradingView's data (note: TradingView doesn't offer a
  general public data API — would likely mean webhook/scraping approaches
  with their own reliability tradeoffs).
- Recommendation when you're ready to decide: pick based on (a) asset
  class coverage matching your stated markets — forex, stocks, indices,
  commodities — and (b) whether you need real-time or delayed-is-fine for
  the research-agent use case in Phase 2. Delayed data is fine for daily
  research; it is not fine anywhere near execution.

## 3. Real capital amount / account structure for Phase 2 → live transition
- Needed to populate initial rows in `accounts` and to set realistic
  `risk_limits` (a $5k account and a $500k account should not share the
  same absolute-dollar loss limits, only the same percentage limits).
- Not needed to finish Phase 1 — the schema stores this per-account, so
  it can be populated whenever you decide.

---
*Add new questions here as they come up. Move resolved questions into a
numbered decision-log entry rather than deleting them.*
