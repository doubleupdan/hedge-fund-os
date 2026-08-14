# SOP — Recording a deposit or balance change on an account

**Applies to:** any row in `accounts`
**Immediate use:** AJTG Flip Account (48830), funding with **$150** on Sunday
before market open

---

## Why this needs a procedure at all

`accounts.current_balance` is a convenience field holding the latest known
value. The authoritative history lives in `account_snapshots`, which is
**append-only** — it's what equity curves and drawdown calculations are built
from (see the table comment in `schemas/postgres/001_accounts_and_risk_limits.sql`).

So updating the balance alone is wrong. It silently overwrites the current
figure and leaves no record that a deposit happened, which means drawdown maths
later can't distinguish "account grew $150" from "someone deposited $150". Both
steps below, in one transaction.

**APEX OS cannot do this.** The desktop app is read-only by construction —
migration 018 grants no write policy to any client role. Run this in the
Supabase SQL editor (or via tooling holding the service_role key).

---

## Before you run anything

Confirm the money is actually in the account. Do not pre-record an expected
deposit — a balance that says $150 when the account holds $0 will size real
positions off a number that isn't there.

---

## The procedure

Both statements in one transaction so you can't end up with a snapshot and no
balance, or the reverse.

```sql
BEGIN;

-- 1. Append the audit record. Never UPDATE or DELETE rows in this table.
INSERT INTO account_snapshots (account_id, balance, equity, snapshot_source, snapshot_at)
SELECT id, 150.00, 150.00, 'manual', now()
FROM accounts
WHERE account_name = 'AJTG Flip Account (48830)';

-- 2. Update the convenience fields APEX OS reads.
UPDATE accounts
SET current_balance = 150.00,
    current_equity  = 150.00,
    updated_at      = now()
WHERE account_name = 'AJTG Flip Account (48830)';

COMMIT;
```

If this is the account's **first** funding, also set the starting balance —
it's the baseline every drawdown percentage is measured against, and leaving it
at 0 makes `max_account_drawdown_pct` meaningless:

```sql
UPDATE accounts
SET starting_balance = 150.00
WHERE account_name = 'AJTG Flip Account (48830)'
  AND starting_balance = 0;
```

For any other account, change the name and the two amounts. Set `equity` equal
to `balance` only when there are no open positions; otherwise use the real
equity figure from the platform.

---

## Verify

```sql
SELECT a.account_name, a.starting_balance, a.current_balance, a.current_equity,
       s.balance AS snapshot_balance, s.snapshot_at
FROM accounts a
LEFT JOIN LATERAL (
  SELECT balance, snapshot_at FROM account_snapshots
  WHERE account_id = a.id ORDER BY snapshot_at DESC LIMIT 1
) s ON true
WHERE a.account_name = 'AJTG Flip Account (48830)';
```

Then open APEX OS → **Risk Desk** → select the account and hit **refresh**.
You should see:

- `balance $150.00` and `equity $150.00` in the account meta row
- The amber **"Balance is $0.00 in the database"** warning **gone**
- The amber **"Starting capital $150 confirmed for Sunday"** founder note also
  **gone** — that note is coded to clear itself once a real balance lands, so
  there's no code change to remember and no stale annotation left behind

If either note is still showing, the `UPDATE` didn't commit.

---

## What this changes about risk

Once funded, the percentage limits stop being structural and start binding for
real. For this account:

| Limit | Value | At $150 |
| --- | --- | --- |
| `max_position_risk_pct` | 10% | **$15.00 max risk per trade** |
| `max_account_drawdown_pct` | 25% | halt at **$112.50** |
| `max_daily_losing_trades` | 2 | 2 losers → stop for the day |
| `max_weekly_losing_trades` | 5 | 5 losers → stop for the week |

The $15/trade figure is the one to sanity-check against your actual lot sizing
before the first trade — migration 017 derived the 10% from a 150-pip stop at
$1/pip on 0.01 lot XAUUSD against a $150 account. If the real stop distance or
lot size differs on the day, the percentage is wrong and should be corrected in
`risk_limits` **before** trading, not after.

---

## Related

- `schemas/postgres/001_accounts_and_risk_limits.sql` — table definitions
- `schemas/postgres/017_risk_limits_all_real_accounts.sql` — where these limits came from
- `scripts/risk/validate_trade.py` — what actually enforces them
- `docs/decision-log/0005-apex-os-desktop-app.md` — why APEX OS can't write
