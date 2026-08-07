-- =============================================================================
-- 003_research_and_decisions.sql
-- Phase 1: Research notes and the executive decision log.
--
-- research_notes is the "Super Brain" ingestion point — every research
-- agent (macro, technical, fundamental, alt-data) writes here in a common
-- shape so it's all searchable together regardless of source.
--
-- decisions is separate from risk_violations: risk_violations is an
-- automated audit trail of the risk system doing its job; decisions is a
-- human-authored record of *why* — strategic calls, limit changes,
-- capital allocation moves, agent design changes. This table is the
-- database-backed counterpart to /docs/decision-log markdown files —
-- markdown for narrative-heavy architecture decisions, this table for
-- structured, queryable operational decisions.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- research_notes
-- -----------------------------------------------------------------------------
CREATE TABLE research_notes (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category           TEXT NOT NULL CHECK (category IN (
                            'macro', 'central_bank', 'inflation', 'rates', 'geopolitics',
                            'economic_report', 'government_policy', 'industry_trend',
                            'company_earnings', 'financial_statement', 'conference_call',
                            'investor_presentation', 'market_news', 'institutional_activity',
                            'options_flow', 'alternative_data', 'technical_analysis',
                            'sector_rotation', 'other'
                        )),
    title               TEXT NOT NULL,
    summary              TEXT NOT NULL,          -- required: every note must be skimmable without opening body
    body                   TEXT,
    related_symbols         TEXT[] DEFAULT '{}',
    related_asset_classes    TEXT[] DEFAULT '{}',
    sentiment                 TEXT CHECK (sentiment IN ('bullish', 'bearish', 'neutral', 'mixed', NULL)),
    confidence                 TEXT CHECK (confidence IN ('low', 'medium', 'high', NULL)),

    source                       TEXT,             -- e.g. 'Bloomberg', 'FinancialJuice', 'SEC EDGAR'
    source_url                    TEXT,
    generated_by                   TEXT NOT NULL,   -- agent name or human author

    -- Lightweight tagging for cross-linking without a full graph DB yet.
    -- Obsidian layer (optional) can render these as a knowledge graph.
    tags                             TEXT[] DEFAULT '{}',
    linked_decision_id                UUID,          -- optional FK to decisions, set below

    published_at                      TIMESTAMPTZ,     -- when the underlying event/report happened
    created_at                        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_research_notes_category ON research_notes(category);
CREATE INDEX idx_research_notes_symbols ON research_notes USING GIN(related_symbols);
CREATE INDEX idx_research_notes_tags ON research_notes USING GIN(tags);
CREATE INDEX idx_research_notes_created ON research_notes(created_at DESC);
-- Full-text search across title/summary/body — the actual "searchable" requirement.
CREATE INDEX idx_research_notes_fts ON research_notes
    USING GIN(to_tsvector('english', title || ' ' || summary || ' ' || COALESCE(body, '')));

COMMENT ON TABLE research_notes IS 'Common ingestion shape for all research agents (macro, technical, fundamental, alt-data). This is the primary table behind the "Super Brain" search.';

-- -----------------------------------------------------------------------------
-- decisions
-- Structured, queryable decision log. Complements /docs/decision-log
-- markdown files (which are better for long narrative architecture
-- decisions). Use this table for operational decisions you'll want to
-- query later: "show me every risk limit change in Q1."
-- -----------------------------------------------------------------------------
CREATE TABLE decisions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    decision_type        TEXT NOT NULL CHECK (decision_type IN (
                              'strategy_change', 'risk_limit_change', 'capital_allocation',
                              'account_change', 'agent_design_change', 'trade_override',
                              'process_change', 'hiring_agent', 'other'
                          )),
    title                  TEXT NOT NULL,
    description              TEXT NOT NULL,
    rationale                  TEXT NOT NULL,
    alternatives_considered      TEXT,
    related_account_id            UUID REFERENCES accounts(id),
    decided_by                     TEXT NOT NULL,
    status                          TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'superseded', 'reversed')),
    supersedes_decision_id            UUID REFERENCES decisions(id),
    created_at                        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_decisions_type ON decisions(decision_type);
CREATE INDEX idx_decisions_created ON decisions(created_at DESC);

COMMENT ON TABLE decisions IS 'Structured operational decision log — queryable counterpart to the narrative markdown files in /docs/decision-log.';

ALTER TABLE research_notes
    ADD CONSTRAINT fk_research_notes_decision
    FOREIGN KEY (linked_decision_id) REFERENCES decisions(id);
