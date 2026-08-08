-- =============================================================================
-- 006_master_follower_accounts.sql
-- Phase 2 (addendum): Master/follower account structure for copy trading.
--
-- Context this reflects (per founder clarification): Precision Summit
-- Tech runs ONE master account that the fund has full legal access to and
-- actively trades. Other participants' accounts CONNECT TO and MIRROR
-- that master account via copy-trading — Precision Summit never takes
-- custody of, or holds login access to, participants' funds. This is the
-- specific mechanism that keeps the fund clear of managed-money legal
-- liability while still running a real trading operation.
--
-- The prior schema treated every account as a flat, independent peer, with
-- no way to express "this account is the one we actually trade" vs. "this
-- account mirrors that one and isn't independently traded." This migration
-- adds that structure.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- accounts.account_role
-- 'master'         — an account Precision Summit has full legal access to
--                     and actively trades directly. Signals/proposed_trades
--                     should only ever target master accounts.
-- 'copy_follower'  — a participant's own account, connected via copy-trading
--                     to mirror a master account. Precision Summit has no
--                     custody or login access. Never a target for
--                     proposed_trades — it only ever receives mirrored
--                     fills from its master, tracked for reporting/journal
--                     purposes only.
-- 'standalone'     — default/back-compat value for existing accounts (e.g.
--                     the Phase 1 test account, and any account that is
--                     neither a master nor a copy-follower — for instance
--                     a personal account not part of the copy-trading web).
-- -----------------------------------------------------------------------------
ALTER TABLE accounts
    ADD COLUMN account_role TEXT NOT NULL DEFAULT 'standalone'
        CHECK (account_role IN ('master', 'copy_follower', 'standalone'));

ALTER TABLE accounts
    ADD COLUMN follows_account_id UUID REFERENCES accounts(id);

-- A copy_follower should always point somewhere; a master/standalone
-- should never point anywhere. Enforced here rather than left as a
-- convention, since this distinction is legally load-bearing, not just
-- organizational.
ALTER TABLE accounts
    ADD CONSTRAINT chk_follows_account_consistency CHECK (
        (account_role = 'copy_follower' AND follows_account_id IS NOT NULL)
        OR (account_role IN ('master', 'standalone') AND follows_account_id IS NULL)
    );

-- A follower cannot follow itself, and (practically) should follow a
-- master, not another follower — enforced for the "not itself" part at
-- the DB level; "must point to a master" is enforced in application logic
-- (scripts/risk validation) since Postgres CHECK constraints can't easily
-- reference another row's column without a trigger, and a trigger is
-- more machinery than Phase 1-2 needs yet.
ALTER TABLE accounts
    ADD CONSTRAINT chk_no_self_follow CHECK (follows_account_id IS NULL OR follows_account_id != id);

CREATE INDEX idx_accounts_role ON accounts(account_role);
CREATE INDEX idx_accounts_follows ON accounts(follows_account_id) WHERE follows_account_id IS NOT NULL;

COMMENT ON COLUMN accounts.account_role IS 'master = actively traded, full legal access. copy_follower = participant-owned, mirrors a master via copy trading, no custody/login access. standalone = neither (default/back-compat).';
COMMENT ON COLUMN accounts.follows_account_id IS 'For copy_follower accounts only: which master account this one mirrors. NULL for master/standalone accounts.';

-- -----------------------------------------------------------------------------
-- Guardrail note for future signal-generation code (documented here since
-- it is not practical to enforce with a simple CHECK constraint):
--
-- proposed_trades.account_id and trades.account_id should only ever
-- reference accounts where account_role = 'master'. A copy_follower
-- account never independently receives a proposed trade or an
-- independently-entered trade — it only ever mirrors whatever the master
-- it follows does. Any script or agent generating proposed_trades should
-- validate this before inserting. Enforcing this as a DB trigger is a
-- reasonable Phase 2+ hardening step once real signal-generation code
-- exists to test it against.
-- -----------------------------------------------------------------------------

-- -----------------------------------------------------------------------------
-- Convenience view: master accounts and how many followers each has,
-- for a quick "what's actually being copy-traded and by how many people"
-- read without joining manually every time.
-- -----------------------------------------------------------------------------
CREATE VIEW master_account_summary AS
SELECT
    m.id                    AS master_account_id,
    m.account_name          AS master_account_name,
    m.current_balance       AS master_current_balance,
    m.current_equity        AS master_current_equity,
    COUNT(f.id)              AS follower_count
FROM accounts m
LEFT JOIN accounts f ON f.follows_account_id = m.id AND f.is_active = TRUE
WHERE m.account_role = 'master' AND m.is_active = TRUE
GROUP BY m.id, m.account_name, m.current_balance, m.current_equity;

COMMENT ON VIEW master_account_summary IS 'Each active master account and how many active copy_follower accounts currently mirror it.';

-- -----------------------------------------------------------------------------
-- Note on existing Phase 1 test data: the 'ajtg-test-paper-account' row
-- inserted during Step 7 risk-gate testing keeps its default
-- account_role = 'standalone', which is correct — it was a synthetic test
-- account, not a real master or follower. No UPDATE needed. When real AJTG
-- accounts (100076, 100892 "10x Acct," Prerequisites, Signal Demo) are
-- entered, each should get an explicit account_role — likely 'master' for
-- whichever one Precision Summit actually trades directly, and
-- 'copy_follower' for participant-owned accounts once the copy-trading
-- connections are known.
-- -----------------------------------------------------------------------------
