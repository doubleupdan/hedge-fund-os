# /sops

Standard Operating Procedures — human-readable, versioned via git (so
every change to "how we do things" has a diff and a commit message
explaining why).

## Subfolders

- `risk/` — risk validation, limit-setting, circuit-breaker procedures
- `trading/` — trade execution discipline, journaling requirements
- `research/` — research note standards, sourcing requirements
- `operations/` — reporting cadence, meeting formats, escalation paths

## Convention

Every SOP should state, at minimum:
1. **Owner** — which department/role is responsible
2. **Applies to** — scope
3. **Procedure** — the actual steps
4. **Related code/schema** — links to the files that implement it, so SOPs
   and code don't silently drift apart

First SOP: `/sops/risk/risk-validation-gate.md`.
