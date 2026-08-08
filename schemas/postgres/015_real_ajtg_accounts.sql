-- =============================================================================
-- 015_real_ajtg_accounts.sql
-- Replaces the Phase 1 test data with the real account structure, per
-- founder-supplied account list.
--
-- Structure:
-- - 301511 (LTI) is THE master account for Precision Summit Fund - the
--   only master, full legal access, copy-trading hub. account_role =
--   'master'.
-- - 100892, 100076 (LTI) are "Test Real Accounts" - real money, used to
--   test strategies before they're considered ready for the fund
--   portfolio. Independent accounts, NOT copy-followers of 301511.
--   account_role = 'standalone'.
-- - 48830 (LHFX) is the "flip" account. account_role = 'standalone'.
-- - 00000 (Verity) is the "100 to 100k" challenge-style account.
--   account_role = 'standalone'.
-- - Demo Account 1-6: placeholder rows for testing new strategies: no
--   broker/numbers assigned yet, founder will organize/rename later.
--   account_role = 'standalone', account_type = 'paper' since these are
--   demo/practice accounts, not real capital.
--
-- All accounts linked to the Average Joe Trading Group trading_group,
-- since AJTG is the entity operating them, per founder confirmation.
--
-- starting_balance/current_balance/current_equity are NOT known for any
-- of these accounts yet - inserted as 0 rather than guessed, with an
-- explicit flag in known_risk_flags-equivalent commentary. These MUST be
-- updated with real figures before any of these accounts are used for
-- actual risk-gated signal generation (validate_trade.py's position-size
-- and position-risk checks are meaningless against a $0 equity account).
-- =============================================================================

INSERT INTO accounts (account_name, owner, broker, platform, account_type, account_role, starting_balance, current_balance, current_equity, trading_group_id)
SELECT 'Precision Summit Fund Master (301511)', 'Manuel', 'LTI', 'MT5', 'live', 'master', 0, 0, 0,
       (SELECT id FROM trading_groups WHERE group_name = 'Average Joe Trading Group' LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE account_name = 'Precision Summit Fund Master (301511)');

INSERT INTO accounts (account_name, owner, broker, platform, account_type, account_role, starting_balance, current_balance, current_equity, trading_group_id)
SELECT 'AJTG Test Real Account (100892)', 'Manuel', 'LTI', 'MT5', 'live', 'standalone', 0, 0, 0,
       (SELECT id FROM trading_groups WHERE group_name = 'Average Joe Trading Group' LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE account_name = 'AJTG Test Real Account (100892)');

INSERT INTO accounts (account_name, owner, broker, platform, account_type, account_role, starting_balance, current_balance, current_equity, trading_group_id)
SELECT 'AJTG Test Real Account (100076)', 'Manuel', 'LTI', 'MT5', 'live', 'standalone', 0, 0, 0,
       (SELECT id FROM trading_groups WHERE group_name = 'Average Joe Trading Group' LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE account_name = 'AJTG Test Real Account (100076)');

INSERT INTO accounts (account_name, owner, broker, platform, account_type, account_role, starting_balance, current_balance, current_equity, trading_group_id)
SELECT 'AJTG Flip Account (48830)', 'Manuel', 'LHFX', 'MT5', 'live', 'standalone', 0, 0, 0,
       (SELECT id FROM trading_groups WHERE group_name = 'Average Joe Trading Group' LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE account_name = 'AJTG Flip Account (48830)');

INSERT INTO accounts (account_name, owner, broker, platform, account_type, account_role, starting_balance, current_balance, current_equity, trading_group_id)
SELECT 'AJTG 100-to-100k Challenge (00000)', 'Manuel', 'Verity', 'MT5', 'live', 'standalone', 0, 0, 0,
       (SELECT id FROM trading_groups WHERE group_name = 'Average Joe Trading Group' LIMIT 1)
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE account_name = 'AJTG 100-to-100k Challenge (00000)');

-- Demo accounts 1-6: placeholders, no broker/number assigned yet.
INSERT INTO accounts (account_name, owner, broker, platform, account_type, account_role, starting_balance, current_balance, current_equity, trading_group_id)
SELECT 'AJTG Demo Account ' || n, 'Manuel', NULL, 'MT5', 'paper', 'standalone', 0, 0, 0,
       (SELECT id FROM trading_groups WHERE group_name = 'Average Joe Trading Group' LIMIT 1)
FROM generate_series(1, 6) AS n
WHERE NOT EXISTS (SELECT 1 FROM accounts WHERE account_name = 'AJTG Demo Account ' || n);
