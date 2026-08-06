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

Four data problems were found and fixed while testing the pipeline against real SEC filings. Each comes from how companies actually report their numbers — and each would have silently skewed the analysis if left in:

1. **Companies never report Q4 revenue by itself.** They file three quarterly reports (Q1–Q3), but the year-end report only shows the *full year* — there is no separate Q4 filing. As a result, every fourth quarter had no revenue number, breaking the growth and billings calculations each Q4. **Fix:** calculate it as `Q4 = full year − (Q1 + Q2 + Q3)` and mark it with an `is_derived_q4` flag, so calculated quarters can be shown differently from reported ones on the dashboard. *(Checked: Chegg's four 2024 quarters add back up to the reported $617M annual revenue.)*

2. **Two different numbers can share the same date.** A Sep 30 filing contains both a 3-month number (just Q3) and a 9-month number (the year so far). The original code kept only one number per date, so it could accidentally keep the 9-month total and throw away the actual quarter. **Fix:** track each number by its start *and* end date so both are kept; the analysis then picks the right one by how many days it covers.

3. **The same balance counted twice in 2018.** When accounting rules changed (ASC 606), some companies reported the same deferred revenue balance under both the old and the new label during the transition year — e.g. Chegg reported $17.4M under *each* on 2018-12-31. Adding them together doubled that quarter to $34.8M. **Fix:** use the new label when available, fall back to the old one, and never add the two.

4. **"Start of year" balances looked like extra quarters.** Companies must also disclose what the balance was at the *start* of the year, and those show up dated Jan 1 (Coursera had four of these). But a Jan 1 balance is just the previous Dec 31 balance repeated one day later — not a new quarter. These duplicate rows pushed every growth comparison off by one quarter. **Fix:** keep only balances dated on a real month-end (Mar 31, Jun 30, Sep 30, Dec 31).

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
