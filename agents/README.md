# /agents

Agent definitions and prompts, one subfolder per department. This directory
holds *what an agent is* (its scope, prompt, inputs/outputs) — not
execution code, which lives in `/scripts` or `/mcp-servers`.

## Convention

Each agent gets a folder: `/agents/<department>/<agent-name>/` containing:

- `AGENT.md` — role definition: responsibilities, inputs, outputs, escalation
  path, and which SOP(s) in `/sops` it follows.
- `prompt.md` — the actual system prompt / instructions, versioned.
- (optional) `examples/` — sample inputs/outputs for testing/eval.

## Current departments (scaffolded, agents to be added starting Phase 2)

- `research/` — macro, technical, fundamental, alt-data research agents
- `risk/` — risk validation and monitoring agents
- `portfolio/` — allocation and portfolio construction agents
- `trader-management/` — trade discipline, journaling, psychology-coaching agents
- `executive/` — coordination, summarization, decision-support agents

## Phase 4 note

Once the fund expands, these become the scoped Claude Code subagent
sessions referenced in the build sequence — each department folder is
designed to map directly onto a subagent's context, not require
restructuring later.
