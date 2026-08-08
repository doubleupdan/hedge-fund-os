# Decision 0002: Add trading_groups as a first-class entity

**Date:** 2026-08-07
**Status:** Decided
**Owner:** Founder + Chief AI Operating Partner

## Context

The original `accounts` table (schema `001`) modeled `owner` as free text,
with an implicit one-account-to-one-owner assumption. In practice, the
fund's real structure has trading groups/teams (e.g. "Average Joe Trading
Group") that manage **multiple accounts** under a single umbrella — a
trader or team, not an individual account, is often the more meaningful
unit for performance review, capital allocation, and reporting.

## Decision

Added `trading_groups` as a first-class table (migration `004`), with
`accounts.trading_group_id` as a nullable foreign key. Nullable so
standalone accounts (not managed under any group) remain valid without
forcing a placeholder group. `accounts.owner` is kept as-is for now — not
dropped — since it's still a useful human-readable label independent of
group structure; the two aren't mutually exclusive.

Also added `trading_group_summary`, a read-only view that rolls up
balance/equity across a group's active accounts, for reporting use. This
does NOT change how risk_limits work — those remain per-account, since
capital preservation rules should never soften just because an account
belongs to a larger, better-performing group.

## Alternatives considered

- **Rename `owner` and constrain it to a lookup table** — rejected;
  doesn't capture the one-to-many relationship (one group, many accounts),
  only relabels the same flawed one-to-one assumption.
- **Model groups as a self-referential hierarchy on accounts** (parent
  account / child account) — rejected as overcomplicated for the current
  need; a group is conceptually a manager/team, not an account itself, and
  conflating the two would make risk_limits ambiguous (which level do
  limits apply to?).

## Consequences

- Existing accounts inserted before this migration will have
  `trading_group_id = NULL` until manually assigned.
- Future account creation should set `trading_group_id` where applicable.
- Group-level risk rollups (e.g. "is this group's aggregate exposure too
  concentrated across its accounts") are a natural Phase 2+ extension now
  that the relationship exists, but are NOT implemented yet — only the
  balance/equity summary view exists so far.
