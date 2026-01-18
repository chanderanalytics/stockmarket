"""
Combines quantitative DB data with qualitative text context
to produce a unified company summary.
"""

import pandas as pd
import json
from data_sources.database_connector import get_company_financials

def build_company_context(company_name: str) -> dict:
    df = get_company_financials(company_name)

    summary = {
        "company": company_name,
        "financial_summary": {
            "avg_roe": round(df["roe"].mean(), 2),
            "rev_cagr": round(((df["revenue"].iloc[0] / df["revenue"].iloc[-1]) ** (1 / (len(df) - 1)) - 1) * 100, 2),
            "debt_trend": "Decreasing" if df["debt_equity"].iloc[0] < df["debt_equity"].iloc[-1] else "Stable/Increasing",
        },
        "data_points": df.to_dict(orient="records"),
        "text_context": (
            f"{company_name} has shown revenue CAGR of {round(((df['revenue'].iloc[0] / df['revenue'].iloc[-1]) ** (1 / (len(df) - 1)) - 1) * 100, 2)}%, "
            f"average ROE of {round(df['roe'].mean(), 2)}%, and a debt-equity ratio trend that is {('declining' if df['debt_equity'].iloc[0] < df['debt_equity'].iloc[-1] else 'rising')}."
        ),
    }

    with open(f"outputs/{company_name}_context.json", "w") as f:
        json.dump(summary, f, indent=4)

    print(f"✅ Context generated: outputs/{company_name}_context.json")
    return summary
