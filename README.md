# Deferred Revenue as an Early Warning System: Three SaaS Responses to AI

**Author:** Ryan Choi, CPA | [LinkedIn](#) | [Tableau Dashboard](#)

## Business Question

Deferred revenue and bookings deceleration are leading indicators of slowing SaaS momentum, appearing quarters before headline revenue declines. But the same surface signal can mean fundamentally different things. This project reconstructs revenue recognition mechanics (ASC 606) from public SEC filings for three companies with three different postures toward AI:

| Company | Posture | Story |
|---|---|---|
| **Chegg** (CHGG) | Disrupted | Management directly attributes subscriber collapse to ChatGPT and Google AI Overviews |
| **Duolingo** (DUOL) | Strategic pivot | Deliberately sacrificed $50M+ in bookings to expand free AI features and grow DAU |
| **Coursera** (COUR) | Platform adaptation | First learning platform embedded directly inside ChatGPT; subscriptions now >85% of revenue |

**Key takeaway:** a quantitative deceleration signal requires qualitative context to interpret correctly. Chegg's deceleration was existential; Duolingo's was self-inflicted and strategic; Coursera's transactional softness masks a subscription-mix improvement.

## Pipeline

```
SEC EDGAR XBRL API  →  Python  →  PostgreSQL  →  Tableau Public
   (companyconcept)    (extract,     (window fns,     (interactive
                        clean)        roll-forward)    dashboard)
```

- **Extraction** (`/extraction/pull_sec_data.py`): pulls deferred revenue (contract liability), recognized revenue, and RPO tags per company via SEC's `companyconcept` endpoint; dedupes amended filings
- **Storage & analytics** (`/sql`): normalized schema; analytical views using window functions (`LAG`) for QoQ/YoY growth, a deceleration score, and a **deferred revenue roll-forward reconstruction** (implied billings = ΔDR + revenue recognized)
- **Delivery**: PostgreSQL views exported to CSV for Tableau Public (which does not support live database connections)

## Key Analytical Concepts (ASC 606)

- **Deferred revenue (contract liability):** cash collected for services not yet delivered; a leading indicator of bookings momentum
- **RPO (remaining performance obligation):** total contracted future revenue, billed and unbilled
- **Roll-forward reconstruction:** beginning DR + billings − revenue recognized = ending DR; reconstructed from public data, with unexplained gaps (M&A opening balances, breakage, FX) flagged as analytical signal
- **Deceleration score:** YoY deferred revenue growth vs. the same metric a year prior; negative and worsening = backlog not being replenished

## Data-Quality Fixes

Three correctness issues were found and fixed while validating the pipeline against real SEC filings. Each traces back to a quirk of how XBRL facts are reported — and each would have quietly corrupted the analysis if left in:

1. **Q4 revenue is never filed on its own.** 10-Qs report Q1–Q3 as discrete ~90-day periods, but there is no "Q4 10-Q" — the 10-K reports the *full fiscal year*. Filtering to quarterly durations therefore dropped every fourth quarter, leaving revenue growth and the roll-forward `NULL` each Q4. **Fix:** derive `Q4 = full-year − (Q1 + Q2 + Q3)` and flag it (`is_derived_q4`) so a reconstructed quarter stays visually distinct from a reported one on the dashboard. *(Validated: Chegg FY2024 Q1–Q4 sum back to the reported $617M annual revenue.)*

2. **YTD and quarterly facts collide on the same date.** Income-statement tags are filed at multiple durations that share an end date — e.g. Sep 30 carries both a 3-month (Q3) fact and a 9-month year-to-date fact. The original de-dup and the table's uniqueness key used the period *end* only, which could silently keep the YTD figure in place of the quarter. **Fix:** key on `(tag, period_start, period_end)` so both survive; the analytics layer then selects the quarter by duration.

3. **Deferred revenue double-counted in the ASC 606 transition year.** Filers may report the same balance under both the legacy (`DeferredRevenueCurrent`) and new (`ContractWithCustomerLiabilityCurrent`) tags during the changeover year — e.g. Chegg, 2018-12-31: $17.4M under *each*. Summing the two doubled that quarter to $34.8M. **Fix:** prefer the ASC 606 tag and fall back to the legacy tag, rather than summing the pair.

## Dashboard

[Tableau Public link] <!-- add published URL -->

<!-- Add 2-3 dashboard screenshots here -->

## Findings

<!-- Fill in after analysis: 3-5 bullet findings, one per company plus cross-cutting insight -->

## Repo Structure

```
/extraction   Python scripts (SEC API pull, PostgreSQL load)
/sql          Schema + analytical views
/tableau      Dashboard screenshots + published link
```
