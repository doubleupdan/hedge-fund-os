-- =============================================================================
-- 011_zero_tolerance_rule_patch.sql
-- Standalone fix: migration 010 attempted to patch risk_parameters with a
-- zero_tolerance_rule field via jsonb_set targeting
-- {presentation_method,zero_tolerance_rule}, but at the time 010 ran, the
-- nested presentation_method/ea_automation_layer structure did not yet
-- exist on disk (migrations 007-009 had not been applied). jsonb_set with
-- create_missing=true only creates the FINAL missing key in a path, not
-- intermediate ones, so the patch silently no-op'd.
--
-- 007-009 have since been applied (confirmed via direct query), so the
-- nested structure now exists. This migration re-applies just the
-- zero_tolerance_rule patch, now that its target path is valid.
-- =============================================================================

UPDATE strategies
SET
    risk_parameters = jsonb_set(
        risk_parameters,
        '{presentation_method,zero_tolerance_rule}',
        '"RSI at 60 during a SELL = INVALID TRADE, hard block, no exceptions"'::jsonb,
        true
    ),
    updated_at = now()
WHERE strategy_name = 'AJTG Trendline Trading Strategy' AND version = '3.0';

-- Verify: this should return a non-null result after running the UPDATE above.
SELECT risk_parameters->'presentation_method'->'zero_tolerance_rule' AS zero_tolerance_rule_check
FROM strategies
WHERE strategy_name = 'AJTG Trendline Trading Strategy';
