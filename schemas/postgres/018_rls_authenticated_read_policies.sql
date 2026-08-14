-- =============================================================================
-- 018_rls_authenticated_read_policies.sql
-- Row Level Security read policies for the APEX OS desktop app.
--
-- WHY THIS EXISTS
-- ---------------
-- RLS was already ENABLED on all 12 public tables, but zero policies had
-- ever been created. In Postgres, "RLS enabled + no policy" means deny-all
-- for every non-superuser role. The practical effect: the Supabase `anon`
-- and `authenticated` roles could read nothing at all — every PostgREST
-- query returned an empty array rather than an error. Server-side tooling
-- kept working because the service_role key bypasses RLS entirely, so this
-- was invisible until a client app tried to read.
--
-- APEX OS (the desktop command centre) needs to read accounts and
-- risk_limits, so it needs real policies.
--
-- THE ACCESS DECISION (founder, 2026-08-14)
-- -----------------------------------------
-- A desktop app ships its Supabase key inside the installed bundle. Anything
-- readable by `anon` is therefore readable by anyone who unpacks the app —
-- effectively public. This data is personal (real account numbers, brokers,
-- balances, per-account risk limits), so the founder chose maximum privacy:
--
--   *** NO POLICIES ARE GRANTED TO `anon`. ***
--
-- Read access requires a real Supabase Auth session (`authenticated` role).
-- APEX OS presents a sign-in screen and holds a session; an unauthenticated
-- copy of the app — or a stolen anon key on its own — reads nothing.
--
-- WRITES REMAIN FULLY CLOSED
-- --------------------------
-- This migration creates SELECT policies ONLY. No INSERT, UPDATE, or DELETE
-- policy is created for any role on any table. With RLS enabled and no write
-- policy, PostgREST cannot write to these tables under any client key. This
-- is deliberate and it reinforces two standing repo constraints:
--   - `risk_violations` and `decisions` are append-only audit trails
--     (CLAUDE.md #4) — they are not writable from a client at all.
--   - Nothing in this repo may place, modify, or cancel an order
--     (CLAUDE.md #1) — `proposed_trades` and `trades` are read-only here.
-- Writes continue to go through server-side tooling using the service_role
-- key, which bypasses RLS and is never shipped in the desktop app.
--
-- Additive per CLAUDE.md #5 — no earlier migration is rewritten.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Belt-and-braces: assert RLS is on before adding policies. If a table were
-- ever created later without RLS, a SELECT policy would give a false sense of
-- protection, so enable it explicitly rather than assuming.
-- -----------------------------------------------------------------------------
ALTER TABLE accounts              ENABLE ROW LEVEL SECURITY;
ALTER TABLE account_snapshots     ENABLE ROW LEVEL SECURITY;
ALTER TABLE risk_limits           ENABLE ROW LEVEL SECURITY;
ALTER TABLE risk_violations       ENABLE ROW LEVEL SECURITY;
ALTER TABLE trades                ENABLE ROW LEVEL SECURITY;
ALTER TABLE proposed_trades       ENABLE ROW LEVEL SECURITY;
ALTER TABLE trading_groups        ENABLE ROW LEVEL SECURITY;
ALTER TABLE strategies            ENABLE ROW LEVEL SECURITY;
ALTER TABLE trade_journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE weekly_trade_reviews  ENABLE ROW LEVEL SECURITY;
ALTER TABLE research_notes        ENABLE ROW LEVEL SECURITY;
ALTER TABLE decisions             ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- SELECT policies — `authenticated` only, never `anon`.
--
-- Scope note: the fund is currently single-operator, so every signed-in user
-- may read every row. There is deliberately no per-user row filtering yet
-- because there is no per-user ownership column to filter on. If a second
-- human or a limited-scope agent identity is ever added, these policies must
-- be narrowed (e.g. USING (owner = auth.jwt() ->> 'email')) BEFORE that
-- account is created — granting the account first and narrowing later would
-- expose every row in the interim.
-- -----------------------------------------------------------------------------

CREATE POLICY "authenticated read accounts"
    ON accounts FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated read account_snapshots"
    ON account_snapshots FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated read risk_limits"
    ON risk_limits FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated read risk_violations"
    ON risk_violations FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated read trades"
    ON trades FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated read proposed_trades"
    ON proposed_trades FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated read trading_groups"
    ON trading_groups FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated read strategies"
    ON strategies FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated read trade_journal_entries"
    ON trade_journal_entries FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated read weekly_trade_reviews"
    ON weekly_trade_reviews FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated read research_notes"
    ON research_notes FOR SELECT TO authenticated USING (true);

CREATE POLICY "authenticated read decisions"
    ON decisions FOR SELECT TO authenticated USING (true);

-- -----------------------------------------------------------------------------
-- Revoke the blanket table grants PostgREST's roles inherit by default.
-- RLS is the row-level gate; these GRANTs are the table-level gate. Removing
-- write privileges here means a future accidental "CREATE POLICY ... FOR ALL"
-- still cannot produce a writable client, and removing `anon` entirely means
-- an unauthenticated caller is rejected at the privilege layer before RLS is
-- even consulted.
-- -----------------------------------------------------------------------------
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;

-- Future tables default to the same posture rather than inheriting write access.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO authenticated;
