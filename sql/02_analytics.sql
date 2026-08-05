-- =====================================================================
-- Analytical views
-- v_deferred_revenue    : combined current + noncurrent deferred revenue
-- v_growth              : QoQ / YoY growth via window functions
-- v_deceleration        : YoY growth vs prior-year YoY growth
-- v_rollforward         : implied billings reconstruction
-- v_tableau_export      : final flat view for Tableau Public CSV export
-- =====================================================================

-- ---------------------------------------------------------------
-- 1. Combined deferred revenue per company per quarter
--    (handles filers that report current/noncurrent separately
--     vs. a single combined tag)
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_deferred_revenue AS
WITH per_tag AS (
    SELECT
        f.company_id,
        f.period_end,
        SUM(CASE WHEN f.tag IN ('ContractWithCustomerLiabilityCurrent',
                                'DeferredRevenueCurrent')      THEN f.value END) AS dr_current,
        SUM(CASE WHEN f.tag IN ('ContractWithCustomerLiabilityNoncurrent',
                                'DeferredRevenueNoncurrent')   THEN f.value END) AS dr_noncurrent,
        SUM(CASE WHEN f.tag = 'ContractWithCustomerLiability'  THEN f.value END) AS dr_combined
    FROM financial_facts f
    GROUP BY f.company_id, f.period_end
)
SELECT
    company_id,
    period_end,
    dr_current,
    dr_noncurrent,
    COALESCE(dr_combined, COALESCE(dr_current, 0) + COALESCE(dr_noncurrent, 0))
        AS deferred_revenue_total
FROM per_tag
WHERE COALESCE(dr_combined, dr_current, dr_noncurrent) IS NOT NULL;

-- ---------------------------------------------------------------
-- 2. Quarterly revenue (prefer ASC 606 tag, fall back to Revenues)
--    10-Q filings report Q1-Q3 as discrete ~90-day periods, but no
--    filing ever reports Q4 on its own: the 10-K reports the full
--    fiscal year (~365 days). We therefore DERIVE Q4 as
--        Q4 = full-year revenue - (Q1 + Q2 + Q3)
--    and flag it. A derived quarter absorbs any full-year true-ups
--    (rounding, annual-only adjustments) not present in the quarters,
--    so it is worth distinguishing from a reported quarter.
--    YTD facts (6-mo / 9-mo cumulative durations) are ignored by the
--    day-count filters; a filer that DOES report a discrete Q4 is used
--    as-is and the derivation is skipped for that year.
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_quarterly_revenue AS
WITH revenue_facts AS (
    -- one row per period; prefer the ASC 606 tag over generic Revenues
    SELECT DISTINCT ON (f.company_id, f.period_start, f.period_end)
        f.company_id,
        f.period_start,
        f.period_end,
        f.value,
        (f.period_end - f.period_start) AS duration_days
    FROM financial_facts f
    WHERE f.tag IN ('RevenueFromContractWithCustomerExcludingAssessedTax', 'Revenues')
      AND f.period_start IS NOT NULL
    ORDER BY f.company_id, f.period_start, f.period_end,
             CASE f.tag
                 WHEN 'RevenueFromContractWithCustomerExcludingAssessedTax' THEN 1
                 ELSE 2
             END
),
quarters AS (                              -- native discrete quarters (~90-day periods)
    SELECT company_id, period_start, period_end, value
    FROM revenue_facts
    WHERE duration_days BETWEEN 80 AND 100
),
annuals AS (                               -- full fiscal year (from the 10-K)
    SELECT company_id, period_start, period_end, value
    FROM revenue_facts
    WHERE duration_days BETWEEN 350 AND 380
),
derived_q4 AS (                            -- Q4 = annual - (Q1 + Q2 + Q3)
    SELECT
        a.company_id,
        a.period_end,
        a.value - SUM(q.value) AS value
    FROM annuals a
    JOIN quarters q
      ON q.company_id  = a.company_id
     AND q.period_start >= a.period_start
     AND q.period_end   <  a.period_end    -- the three quarters strictly inside the year
    WHERE NOT EXISTS (                     -- skip if the filer already reports a discrete Q4
        SELECT 1 FROM quarters q4
        WHERE q4.company_id = a.company_id
          AND q4.period_end = a.period_end
    )
    GROUP BY a.company_id, a.period_end, a.value
    HAVING COUNT(*) = 3                     -- only derive when all three quarters are present
)
SELECT company_id, period_end, value AS revenue, FALSE AS is_derived_q4
FROM quarters
UNION ALL
SELECT company_id, period_end, value AS revenue, TRUE  AS is_derived_q4
FROM derived_q4;

-- ---------------------------------------------------------------
-- 3. Growth metrics: QoQ and YoY for deferred revenue and revenue
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_growth AS
WITH combined AS (
    SELECT
        d.company_id,
        d.period_end,
        d.deferred_revenue_total,
        r.revenue,
        COALESCE(r.is_derived_q4, FALSE) AS is_derived_q4
    FROM v_deferred_revenue d
    LEFT JOIN v_quarterly_revenue r
           ON r.company_id = d.company_id
          AND r.period_end = d.period_end
)
SELECT
    c.*,
    -- deferred revenue growth
    (deferred_revenue_total / NULLIF(LAG(deferred_revenue_total, 1)
        OVER w, 0) - 1) AS dr_qoq_growth,
    (deferred_revenue_total / NULLIF(LAG(deferred_revenue_total, 4)
        OVER w, 0) - 1) AS dr_yoy_growth,
    -- revenue growth
    (revenue / NULLIF(LAG(revenue, 4) OVER w, 0) - 1) AS rev_yoy_growth
FROM combined c
WINDOW w AS (PARTITION BY company_id ORDER BY period_end);

-- ---------------------------------------------------------------
-- 4. Deceleration score:
--    this quarter's YoY DR growth minus the same quarter's YoY DR
--    growth one year earlier. Negative + worsening = backlog not
--    being replenished.
--    Also flags quarters where DR growth < revenue growth
--    (burning backlog faster than replacing it).
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_deceleration AS
SELECT
    g.*,
    g.dr_yoy_growth - LAG(g.dr_yoy_growth, 4)
        OVER (PARTITION BY g.company_id ORDER BY g.period_end)
        AS dr_deceleration_score,
    (g.dr_yoy_growth < g.rev_yoy_growth) AS dr_lagging_revenue_flag
FROM v_growth g;

-- ---------------------------------------------------------------
-- 5. Roll-forward reconstruction:
--    implied billings = ending DR - beginning DR + revenue recognized
--    (assumes all revenue flows through deferred revenue; the gap
--    between implied and plausible billings is itself analytical
--    signal -- e.g., revenue billed-and-recognized in-period,
--    M&A opening balances, FX)
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_rollforward AS
SELECT
    g.company_id,
    g.period_end,
    LAG(g.deferred_revenue_total) OVER w  AS dr_beginning,
    g.deferred_revenue_total              AS dr_ending,
    g.revenue                             AS revenue_recognized,
    g.deferred_revenue_total
        - LAG(g.deferred_revenue_total) OVER w
        + g.revenue                       AS implied_billings,
    (g.deferred_revenue_total
        - LAG(g.deferred_revenue_total) OVER w
        + g.revenue) / NULLIF(g.revenue, 0)
                                          AS billings_to_revenue_ratio
FROM v_growth g
WINDOW w AS (PARTITION BY g.company_id ORDER BY g.period_end);

-- ---------------------------------------------------------------
-- 6. Final flat export for Tableau Public
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_tableau_export AS
SELECT
    co.name                     AS company,
    co.ticker,
    co.narrative_category,
    d.period_end,
    d.deferred_revenue_total,
    d.revenue,
    d.is_derived_q4,
    d.dr_qoq_growth,
    d.dr_yoy_growth,
    d.rev_yoy_growth,
    d.dr_deceleration_score,
    d.dr_lagging_revenue_flag,
    rf.dr_beginning,
    rf.implied_billings,
    rf.billings_to_revenue_ratio,
    ce.event_note,
    ce.source                   AS event_source
FROM v_deceleration d
JOIN companies co        ON co.company_id = d.company_id
LEFT JOIN v_rollforward rf ON rf.company_id = d.company_id
                          AND rf.period_end = d.period_end
LEFT JOIN context_events ce ON ce.company_id = d.company_id
                           AND ce.period_end = d.period_end
ORDER BY co.name, d.period_end;

-- Export from psql:
--   \copy (SELECT * FROM v_tableau_export) TO 'tableau_export.csv' CSV HEADER
