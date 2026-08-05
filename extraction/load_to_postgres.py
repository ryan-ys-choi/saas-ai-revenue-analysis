"""
Load sec_facts_raw.csv (from pull_sec_data.py) into PostgreSQL.

Usage:
    createdb saas_rev_analysis
    psql -d saas_rev_analysis -f ../sql/01_schema.sql
    python load_to_postgres.py
    psql -d saas_rev_analysis -f ../sql/02_analytics.sql
"""

import pandas as pd
from sqlalchemy import create_engine, text

DB_URL = "postgresql://localhost:5432/saas_rev_analysis"  # adjust user/password as needed


def fiscal_period(fp: str) -> str:
    """Normalize SEC 'fp' field (FY, Q1..Q3) -- Q4 usually arrives as FY."""
    return fp if fp else "UNKNOWN"


def main() -> None:
    engine = create_engine(DB_URL)
    raw = pd.read_csv("sec_facts_raw.csv")

    with engine.begin() as conn:
        company_ids = dict(
            conn.execute(text("SELECT name, company_id FROM companies")).fetchall()
        )

    facts = pd.DataFrame({
        "company_id":    raw["company"].map(company_ids),
        "tag":           raw["tag"],
        "period_start":  pd.to_datetime(raw.get("start"), errors="coerce").dt.date,
        "period_end":    pd.to_datetime(raw["end"]).dt.date,
        "value":         raw["val"],
        "fiscal_year":   raw["fy"],
        "fiscal_period": raw["fp"].map(fiscal_period),
        "form_type":     raw["form"],
        "filed_date":    pd.to_datetime(raw["filed"]).dt.date,
    })

    facts = facts.dropna(subset=["company_id", "value"])
    facts.to_sql("financial_facts", engine, if_exists="append", index=False)
    print(f"Loaded {len(facts)} facts into financial_facts")


if __name__ == "__main__":
    main()
