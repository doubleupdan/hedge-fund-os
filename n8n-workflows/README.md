# /n8n-workflows

Exported n8n workflow JSON, organized by the phase that introduced them.
n8n owns scheduling and delivery (report generation triggers, alert
routing) — it should call out to scripts/MCP servers for actual logic
rather than embedding trading or risk logic in workflow nodes. Keeping
logic in versioned, testable code (not workflow-UI logic) is what makes
this auditable.

## Subfolders

- `phase1-readonly/` — scaffolded now; first workflow to add is a simple
  scheduled pull from the market-data MCP server into `account_snapshots`
  or `research_notes`, once a data vendor is chosen.
- `phase2-research-loop/` — the daily research agent → report → delivery
  loop described in the Phase 2 build sequence.

## Convention

Export workflows as JSON (n8n's native export) and name them
descriptively: `daily-research-report.json`, not `workflow_3.json`. Add a
one-paragraph comment at the top of this README's relevant section
describing what each workflow does and what triggers it, since n8n JSON
itself isn't very readable in a diff.
