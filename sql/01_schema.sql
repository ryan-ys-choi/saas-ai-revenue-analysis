-- =====================================================================
-- SaaS Revenue Recognition & AI Response Analysis
-- Schema: companies, financial facts, qualitative context
-- =====================================================================

DROP TABLE IF EXISTS context_events;
DROP TABLE IF EXISTS financial_facts;
DROP TABLE IF EXISTS companies;

CREATE TABLE companies (
    company_id          SERIAL PRIMARY KEY,
    name                TEXT NOT NULL UNIQUE,
    ticker              TEXT NOT NULL,
    cik                 CHAR(10) NOT NULL,
    narrative_category  TEXT NOT NULL  -- 'AI disruption' | 'Strategic AI pivot' | 'Platform adaptation'
);

CREATE TABLE financial_facts (
    fact_id       SERIAL PRIMARY KEY,
    company_id    INT NOT NULL REFERENCES companies(company_id),
    tag           TEXT NOT NULL,           -- XBRL tag, e.g. ContractWithCustomerLiabilityCurrent
    period_start  DATE,                    -- NULL for instant (balance sheet) facts
    period_end    DATE NOT NULL,
    value         NUMERIC(18, 2) NOT NULL,
    fiscal_year   INT,
    fiscal_period TEXT,                    -- 'Q1'..'Q4' or 'FY'
    form_type     TEXT NOT NULL,           -- '10-K' | '10-Q'
    filed_date    DATE NOT NULL,
    -- period_start is part of the key: income-statement tags report multiple
    -- durations ending on the same date (e.g. a 3-month Q3 fact AND a 9-month
    -- YTD fact both end on the same day). Keying on period_end alone would
    -- collapse them and could keep the YTD value instead of the quarter.
    -- (instant/balance-sheet facts have period_start NULL -> one row per end.)
    UNIQUE (company_id, tag, period_start, period_end)
);

CREATE TABLE context_events (
    event_id     SERIAL PRIMARY KEY,
    company_id   INT NOT NULL REFERENCES companies(company_id),
    period_end   DATE NOT NULL,            -- quarter the event maps to
    event_note   TEXT NOT NULL,            -- short annotation for dashboard tooltips
    source       TEXT NOT NULL             -- e.g. 'Q1 2025 earnings call'
);

-- Seed companies
INSERT INTO companies (name, ticker, cik, narrative_category) VALUES
    ('Chegg',    'CHGG', '0001364954', 'AI disruption'),
    ('Duolingo', 'DUOL', '0001562088', 'Strategic AI pivot'),
    ('Coursera', 'COUR', '0001651562', 'Platform adaptation');

-- Seed qualitative context (from earnings calls / filings research)
INSERT INTO context_events (company_id, period_end, event_note, source) VALUES
    ((SELECT company_id FROM companies WHERE name = 'Chegg'),
     '2025-03-31',
     'Subscribers -31% YoY; management explicitly cites ChatGPT and Google AI Overviews',
     'Q1 2025 earnings call'),
    ((SELECT company_id FROM companies WHERE name = 'Chegg'),
     '2026-03-31',
     'Revenue -48% YoY; second layoff round attributed to "the new realities of AI"',
     'Q1 2026 earnings call'),
    ((SELECT company_id FROM companies WHERE name = 'Duolingo'),
     '2026-03-31',
     'Deliberate bookings deceleration: >$50M foregone bookings to expand free AI features and grow DAU',
     'Q1 2026 earnings call'),
    ((SELECT company_id FROM companies WHERE name = 'Coursera'),
     '2025-09-30',
     'First learning platform embedded directly in ChatGPT (OpenAI partnership)',
     'Q3 2025 shareholder letter'),
    ((SELECT company_id FROM companies WHERE name = 'Coursera'),
     '2026-06-30',
     'Normalized revenue -1% YoY (transactional pressure); subscriptions now >85% of revenue; Udemy acquired May 2026',
     'Q2 2026 earnings call');
