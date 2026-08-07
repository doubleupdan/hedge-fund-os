# /docs/reports

Generated reports, organized by cadence: `daily/`, `weekly/`, `monthly/`,
`quarterly/`, `yearly/`. Each report should be generated FROM Postgres data
(trades, research_notes, risk_violations, account_snapshots) — never
hand-authored from scratch — so reports stay consistent with the system of
record and a report can always be regenerated or audited against the
underlying rows.

## Naming convention

`YYYY-MM-DD_<report-type>.md` for daily, `YYYY-WW_weekly.md` for weekly
(ISO week), `YYYY-MM_monthly.md`, `YYYY-QN_quarterly.md`, `YYYY_yearly.md`.

## Standard report contents (per the operating philosophy)

Every report — regardless of cadence — should cover, at minimum:
- Market conditions
- Open positions
- Risk status (including any `risk_violations` since the last report)
- Performance
- Research highlights
- Action items / problems / recommendations
- Next priorities

## Status

No reports generated yet — this directory structure is scaffolded ahead of
Phase 2/3, when the daily research agent and automated reporting loop come
online.
