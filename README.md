# Deferred Revenue as an Early Warning System: Three SaaS Responses to AI

**Author:** Ryan Choi, CPA | [LinkedIn](https://www.linkedin.com/in/ryan-yunseok-choi/) | [Tableau Public](https://public.tableau.com/app/profile/ryan.ys.choi)

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
- **Storage & analytics** (`/sql`): normalized schema; analytical views using window functions (`LAG`) for QoQ/YoY growth, growth acceleration/deceleration, and a **deferred revenue roll-forward** producing **calculated billings** (revenue + ΔDR, the standard SaaS bookings proxy) and a **billings-to-revenue ratio**
- **Delivery**: PostgreSQL views exported to CSV for Tableau Public (which does not support live database connections)

## Key Analytical Concepts (ASC 606)

- **Deferred revenue (contract liability):** cash collected for services not yet delivered; a leading indicator of bookings momentum
- **RPO (remaining performance obligation):** total contracted future revenue, billed and unbilled
- **Roll-forward reconstruction:** beginning DR + billings − revenue recognized = ending DR; reconstructed from public data, with unexplained gaps (M&A opening balances, breakage, FX) flagged as analytical signal
- **Calculated billings:** revenue + change in deferred revenue — the standard SaaS proxy for bookings
- **Billings-to-revenue ratio:** calculated billings ÷ revenue; above 1.0 means deferred revenue is growing (billing faster than recognizing)
- **DR–revenue growth gap:** YoY deferred revenue growth minus YoY revenue growth, in percentage points — the metric charted in the deceleration heatmap. Positive = the backlog is growing faster than the income statement, i.e. momentum is building ahead of reported revenue. Negative = revenue is outrunning the backlog, i.e. bookings are not keeping pace with what is being recognized. This is the leading-vs-lagging comparison the dashboard is built around.
- **Growth deceleration (`dr_yoy_growth_delta`):** change in YoY deferred revenue growth versus the same quarter a year earlier, in percentage points. Negative and worsening = the *rate* of backlog growth is itself slowing. Computed in SQL and used in the analytical views as a second-derivative check on the gap metric above.

## Data-Quality Fixes

Four data problems were found and fixed while testing the pipeline against real SEC filings. Each comes from how companies actually report their numbers — and each would have silently skewed the analysis if left in:

1. **Companies never report Q4 revenue by itself.** They file three quarterly reports (Q1–Q3), but the year-end report only shows the *full year* — there is no separate Q4 filing. As a result, every fourth quarter had no revenue number, breaking the growth and billings calculations each Q4. **Fix:** calculate it as `Q4 = full year − (Q1 + Q2 + Q3)` and mark it with an `is_derived_q4` flag, so calculated quarters can be shown differently from reported ones on the dashboard. *(Checked: Chegg's four 2024 quarters add back up to the reported $617M annual revenue.)*

2. **Two different numbers can share the same date.** A Sep 30 filing contains both a 3-month number (just Q3) and a 9-month number (the year so far). The original code kept only one number per date, so it could accidentally keep the 9-month total and throw away the actual quarter. **Fix:** track each number by its start *and* end date so both are kept; the analysis then picks the right one by how many days it covers.

3. **The same balance counted twice in 2018.** When accounting rules changed (ASC 606), some companies reported the same deferred revenue balance under both the old and the new label during the transition year — e.g. Chegg reported $17.4M under *each* on 2018-12-31. Adding them together doubled that quarter to $34.8M. **Fix:** use the new label when available, fall back to the old one, and never add the two.

4. **"Start of year" balances looked like extra quarters.** Companies must also disclose what the balance was at the *start* of the year, and those show up dated Jan 1 (Coursera had four of these). But a Jan 1 balance is just the previous Dec 31 balance repeated one day later — not a new quarter. These duplicate rows pushed every growth comparison off by one quarter. **Fix:** keep only balances dated on a real month-end (Mar 31, Jun 30, Sep 30, Dec 31).

## Dashboard

**[View the interactive dashboard on Tableau Public →](https://public.tableau.com/app/profile/ryan.ys.choi/viz/saas-ai-revenue-analysis/Dashboard1)**

## Findings

*All figures computed from SEC XBRL data via the pipeline above (through Q1 FY2026).*

- **Chegg — the warning light worked, twice.** Deferred revenue growth turned negative in Q3 2021 (−3.8% YoY) while revenue was still growing +11.6% — three quarters before revenue itself went negative. It flashed again in Q1 2023, one quarter after ChatGPT launched, and never recovered; revenue decline then deepened every year, from −7% (early 2023) to −48% (early 2026). Both times, the backlog stopped refilling before the income statement showed it.

- **Chegg — but the same signal also gave a false "recovery."** During 2022, DR growth looked strongly positive (+24% to +60% YoY) even as revenue shrank. The cause wasn't a rebound: the Busuu acquisition closed in Q1 2022 and its deferred revenue landed on Chegg's balance sheet — visible in the data as a one-quarter jump from $35M to $60M. An acquisition can make a dying backlog look like a growing one for a full year of YoY comparisons.

- **Duolingo — the same warning, chosen on purpose.** Through mid-2025, DR grew ~48–51% YoY, comfortably ahead of revenue (~38–41%). Then three straight quarters of sharp slowdown: 42% → 33% → 24% by Q1 2026, with DR growth falling *below* revenue growth for the first time. On paper this is the Chegg pattern — but management pre-announced it, giving up $50M+ in bookings to expand free AI features and grow daily active users. Identical signal, opposite meaning.

- **Coursera — sleepy headline, improving engine.** Revenue growth looks stuck in the single digits (6–10%), but DR growth ran well ahead of it — peaking at +24% YoY in early 2025 — as the business shifted toward subscriptions (now >85% of revenue). The backlog was being built, not burned. By Q1 2026 DR growth had eased to ~8%, roughly in line with revenue: worth watching, not yet a warning.

- **Cross-cutting: the number tells you *where* to look, not *what* it means.** Three companies produced near-identical deceleration signals. One was existential distress (Chegg), one was a deliberate strategic trade (Duolingo), one was a mix-shift underneath a flat headline (Coursera) — and M&A injected a false positive on top. A bookings-deceleration screen is a good tripwire and a bad verdict: every signal here required the earnings-call context layer to interpret correctly.

## Repo Structure

```
/extraction   Python scripts (SEC API pull, PostgreSQL load)
/sql          Schema + analytical views
/tableau      Dashboard screenshots + published link
```
