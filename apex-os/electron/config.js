/**
 * APEX OS connection config.
 *
 * On the anon key: it is NOT a secret and never was — it only identifies the
 * project and asserts the `anon` Postgres role. What makes it safe to ship
 * here is migration 018, which grants `anon` no privileges and no policies on
 * any table. A copy of this key on its own reads nothing. Real data requires a
 * Supabase Auth session, which the app obtains via the sign-in screen.
 *
 * A service_role key must never appear in this file or anywhere else in this
 * app — it bypasses RLS entirely and would hand full read/write access to
 * anyone who unpacked the bundle.
 *
 * Both values can be overridden by environment variable, which is how you
 * point a dev build at a branch database without editing tracked source.
 */

const SUPABASE_URL =
  process.env.APEX_SUPABASE_URL || 'https://fhdxzdpaigxzknhjvvfo.supabase.co';

const SUPABASE_ANON_KEY =
  process.env.APEX_SUPABASE_ANON_KEY ||
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZoZHh6ZHBhaWd4emtuaGp2dmZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxMTg4NjYsImV4cCI6MjEwMTY5NDg2Nn0.PKRB0jOY9AAYki_oG5N8m-oUMuDoaa8lB3TIcWuKE3c';

module.exports = { SUPABASE_URL, SUPABASE_ANON_KEY };
