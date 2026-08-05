"""
Pull XBRL revenue recognition data from SEC EDGAR companyconcept API
for Chegg, Duolingo, and Coursera.

Usage:
    pip install requests pandas psycopg2-binary sqlalchemy
    python pull_sec_data.py
"""

import time
import requests
import pandas as pd

# SEC requires a User-Agent identifying you
HEADERS = {"User-Agent": "Ryan Choi ryan.yunseok.choi@gmail.com"}

COMPANIES = {
    "Chegg":    {"cik": "0001364954", "ticker": "CHGG", "narrative": "AI disruption"},
    "Duolingo": {"cik": "0001562088", "ticker": "DUOL", "narrative": "Strategic AI pivot"},
    "Coursera": {"cik": "0001651562", "ticker": "COUR", "narrative": "Platform adaptation"},
}

# Tags to attempt per company. Not all companies use all tags --
# the script records what it finds and reports gaps.
TAGS = [
    # Deferred revenue (contract liability)
    "ContractWithCustomerLiabilityCurrent",
    "ContractWithCustomerLiabilityNoncurrent",
    "ContractWithCustomerLiability",              # some filers report combined only
    # Legacy deferred revenue tags (pre-ASC 606 or filer preference)
    "DeferredRevenueCurrent",
    "DeferredRevenueNoncurrent",
    # Recognized revenue
    "RevenueFromContractWithCustomerExcludingAssessedTax",
    "Revenues",
    # RPO (backlog)
    "RevenueRemainingPerformanceObligation",
    # Contract assets (unbilled receivables)
    "ContractWithCustomerAssetNetCurrent",
]


def get_concept(cik: str, tag: str) -> pd.DataFrame:
    """Pull full history for one company + one tag. Returns empty df if tag unused."""
    url = f"https://data.sec.gov/api/xbrl/companyconcept/CIK{cik}/us-gaap/{tag}.json"
    r = requests.get(url, headers=HEADERS)
    if r.status_code != 200:
        return pd.DataFrame()
    payload = r.json()
    units = payload.get("units", {})
    if "USD" not in units:
        return pd.DataFrame()
    df = pd.DataFrame(units["USD"])
    df["tag"] = tag
    return df


def main() -> None:
    frames = []
    coverage = []

    for name, meta in COMPANIES.items():
        for tag in TAGS:
            df = get_concept(meta["cik"], tag)
            found = not df.empty
            coverage.append({"company": name, "tag": tag, "found": found,
                             "n_facts": len(df)})
            if found:
                df["company"] = name
                df["ticker"] = meta["ticker"]
                frames.append(df)
            time.sleep(0.15)  # stay well under SEC's 10 req/sec limit

    combined = pd.concat(frames, ignore_index=True)

    # Keep only 10-K / 10-Q facts; drop amended-filing duplicates by keeping
    # the earliest filed fact per company/tag/period. The period key includes
    # BOTH start and end: income-statement tags report several durations ending
    # on the same date (a 3-month quarter and a 9-month YTD fact both end on the
    # same day), and deduping on "end" alone would discard one of them --
    # potentially keeping the YTD figure instead of the discrete quarter.
    combined = combined[combined["form"].isin(["10-K", "10-Q"])]
    combined = (
        combined.sort_values("filed")
        .drop_duplicates(subset=["company", "tag", "start", "end"], keep="first")
        .reset_index(drop=True)
    )

    combined.to_csv("sec_facts_raw.csv", index=False)
    pd.DataFrame(coverage).to_csv("tag_coverage.csv", index=False)

    print(f"Saved {len(combined)} facts -> sec_facts_raw.csv")
    print("\nTag coverage by company (check gaps before building):")
    print(pd.DataFrame(coverage).pivot(index="tag", columns="company", values="n_facts"))


if __name__ == "__main__":
    main()
