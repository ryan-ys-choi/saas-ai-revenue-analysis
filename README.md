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
