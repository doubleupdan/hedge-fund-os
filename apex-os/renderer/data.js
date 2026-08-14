'use strict';

/**
 * Supabase access layer for APEX OS.
 *
 * Read-only by construction. Migration 018 grants the `authenticated` role
 * SELECT and nothing else, and grants `anon` nothing at all — so this file has
 * no write path to offer even if someone later asked it to. That is the point:
 * per CLAUDE.md #1 nothing in this system may place, modify, or cancel an
 * order, and a dashboard that literally cannot write is the cheapest way to
 * keep that true.
 */

const APEX = (window.APEX = window.APEX || {});

const cfg = window.APEX_CONFIG;

const client =
  cfg && cfg.supabaseUrl && cfg.supabaseAnonKey
    ? window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey, {
        auth: {
          // Keeps the founder signed in across app restarts. The refresh token
          // lives in this app's own Electron profile, not a shared browser.
          persistSession: true,
          autoRefreshToken: true,
          // No OAuth redirect flow in a desktop app — email + password only.
          detectSessionInUrl: false,
        },
      })
    : null;

APEX.client = client;
APEX.configured = Boolean(client);

/* ---------------------------------------------------------------- auth --- */

APEX.auth = {
  async currentSession() {
    if (!client) return null;
    const { data } = await client.auth.getSession();
    return data.session || null;
  },

  async signIn(email, password) {
    if (!client) throw new Error('Supabase is not configured.');
    const { data, error } = await client.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data.session;
  },

  async signOut() {
    if (!client) return;
    await client.auth.signOut();
  },

  onChange(fn) {
    if (!client) return;
    client.auth.onAuthStateChange((_event, session) => fn(session));
  },
};

/* ---------------------------------------------------------------- data --- */

/**
 * PostgREST returns NUMERIC as a string ("10.00") to avoid float precision
 * loss in transit. Every risk percentage in this app is a NUMERIC column, so
 * converting explicitly here keeps string concatenation out of the render
 * layer — "10.00" + "%" is fine, but "10.00" > 5 is not, and a comparison bug
 * in a risk display is exactly the kind of thing this repo cannot afford.
 */
const num = (v) => (v === null || v === undefined ? null : Number(v));
const int = (v) => (v === null || v === undefined ? null : parseInt(v, 10));

/**
 * Local annotations — context the founder has confirmed verbally but which is
 * not yet a value in the database. Rendered as an explicitly-labelled note,
 * never merged into a numeric field, so the UI never shows an invented number
 * as though Supabase returned it.
 */
const ACCOUNT_NOTES = {
  'AJTG Flip Account (48830)':
    'Starting capital $150 confirmed for Sunday before market open. Not yet reflected in the balance field below.',
};

/**
 * Loads every account that has a risk_limits row, with its limits embedded.
 *
 * Accounts without limits are excluded rather than shown with blanks: an
 * account with no configured limits has nothing to display on a risk desk, and
 * rendering empty cells next to real ones invites misreading them as zeroes.
 */
APEX.fetchAccounts = async function fetchAccounts() {
  if (!client) throw new Error('Supabase is not configured.');

  const { data, error } = await client
    .from('accounts')
    .select(
      `id, account_name, broker, platform, account_type, account_role,
       current_balance, current_equity, is_active,
       risk_limits ( max_position_size_pct, max_position_risk_pct,
                     daily_loss_limit_pct, weekly_loss_limit_pct,
                     monthly_drawdown_limit_pct, max_account_drawdown_pct,
                     max_correlated_exposure_pct, max_single_symbol_exposure_pct,
                     max_open_positions, max_leverage,
                     max_daily_losing_trades, max_weekly_losing_trades,
                     trading_halted, halted_reason, is_active, updated_at )`
    )
    .eq('is_active', true)
    .order('account_name');

  if (error) throw error;

  return (data || [])
    .map((row) => {
      const limitRows = row.risk_limits || [];
      // A row may in principle carry superseded limit rows; prefer the active one.
      const rl = limitRows.find((l) => l.is_active) || limitRows[0];
      if (!rl) return null;

      return {
        id: row.id,
        name: row.account_name,
        broker: row.broker || '—',
        platform: row.platform,
        accountType: row.account_type,
        role: row.account_role || 'standalone',
        balance: num(row.current_balance),
        equity: num(row.current_equity),

        maxPositionSizePct: num(rl.max_position_size_pct),
        maxPositionRiskPct: num(rl.max_position_risk_pct),
        dailyLossLimitPct: num(rl.daily_loss_limit_pct),
        weeklyLossLimitPct: num(rl.weekly_loss_limit_pct),
        monthlyDrawdownLimitPct: num(rl.monthly_drawdown_limit_pct),
        maxAccountDrawdownPct: num(rl.max_account_drawdown_pct),
        maxCorrelatedExposurePct: num(rl.max_correlated_exposure_pct),
        maxSingleSymbolExposurePct: num(rl.max_single_symbol_exposure_pct),
        maxOpenPositions: int(rl.max_open_positions),
        maxLeverage: num(rl.max_leverage),
        maxDailyLosingTrades: int(rl.max_daily_losing_trades),
        maxWeeklyLosingTrades: int(rl.max_weekly_losing_trades),
        tradingHalted: Boolean(rl.trading_halted),
        haltedReason: rl.halted_reason || null,
        limitsUpdatedAt: rl.updated_at || null,

        note: ACCOUNT_NOTES[row.account_name] || null,
      };
    })
    .filter(Boolean)
    // Live accounts first, then paper — the real money belongs at the top of
    // the selector, and paper accounts are labelled where they appear.
    .sort((a, b) => {
      if (a.accountType !== b.accountType) return a.accountType === 'live' ? -1 : 1;
      return a.name.localeCompare(b.name);
    });
};
