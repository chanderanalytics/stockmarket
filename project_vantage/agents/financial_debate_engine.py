"""
Financial Debate Engine – core reasoning module for Project VANTAGE.
Three agents (LongAnalyst, ShortAnalyst, Moderator) analyze structured financials
and produce a JSON debate summary.

Relies on a local LLM via Ollama (or any configured backend).
"""

import json
import os
import re
import yaml
import pandas as pd
from typing import Dict, Any
from langchain_community.llms import Ollama


# ---------------------------------------------------------------------
# LLM CONFIGURATION LOADER
# ---------------------------------------------------------------------
def load_llm():
    """Load model config and initialize LLM."""
    try:
        with open("config/model_config.yaml", "r") as f:
            cfg = yaml.safe_load(f)["llm"]

        return Ollama(
            model=cfg.get("model", "llama3"),
            temperature=cfg.get("temperature", 0.4),
            num_predict=cfg.get("max_tokens", 1200)
        )
    except Exception as e:
        print(f"⚠️ Error loading LLM config: {e}")
        print("Falling back to default Ollama model (llama3)")
        return Ollama(model="llama3", temperature=0.4)


# ---------------------------------------------------------------------
# DATA SUMMARIZATION
# ---------------------------------------------------------------------
def format_company_data(df: pd.DataFrame) -> str:
    """Summarize essential company metrics into a readable digest."""
    selected_cols = [
        "sales", "sales_growth_3years", "profit_after_tax", "profit_growth_3years",
        "operating_profit", "opm", "return_on_capital_employed", "return_on_equity",
        "asset_turnover_ratio", "debt_to_equity", "free_cash_flow_3years",
        "operating_cash_flow_3years", "price_to_earning", "price_to_book_value",
        "peg_ratio", "dividend_yield", "promoter_holding", "change_in_promoter_holding_3years",
        "fii_holding", "dii_holding"
    ]

    summary = []
    for col in selected_cols:
        match = [c for c in df.columns if col.lower() in c.lower()]
        if not match:
            continue
        val = df[match[0]].dropna().iloc[-1]
        if isinstance(val, (int, float)) and not pd.isna(val):
            summary.append(f"{col.replace('_', ' ').title()}: {val:,.2f}")

    return "\n".join(summary)


# ---------------------------------------------------------------------
# DEBATE PROMPT BUILDER
# ---------------------------------------------------------------------
def generate_debate_prompt(company_name: str, data_summary: str) -> str:
    """Builds a clear and structured prompt for the multi-analyst debate."""
    return f"""
You are hosting a professional financial debate about **{company_name}**.

Below are key company data points:
{data_summary}

Participants:
1️⃣ **LongAnalyst** – bullish; focuses on growth drivers, efficiency, and execution.
2️⃣ **ShortAnalyst** – bearish; highlights risks, overvaluation, or structural weaknesses.
3️⃣ **Moderator** – neutral; summarizes both sides and gives a balanced verdict.

Base reasoning *only* on provided metrics.
Do NOT assume missing data.
Be concise and avoid repetition.

Output must strictly be in this JSON format:

{{
  "growth_and_demand": {{
    "bullish_points": [],
    "bearish_points": [],
    "summary": "",
    "confidence_score": 0.xx
  }},
  "profitability_and_margins": {{
    "bullish_points": [],
    "bearish_points": [],
    "summary": "",
    "confidence_score": 0.xx
  }},
  "capital_efficiency_and_cashflow": {{
    "bullish_points": [],
    "bearish_points": [],
    "summary": "",
    "confidence_score": 0.xx
  }},
  "balance_sheet_and_leverage": {{
    "bullish_points": [],
    "bearish_points": [],
    "summary": "",
    "confidence_score": 0.xx
  }},
  "valuation_and_market_sentiment": {{
    "bullish_points": [],
    "bearish_points": [],
    "summary": "",
    "confidence_score": 0.xx
  }},
  "governance_and_shareholding": {{
    "bullish_points": [],
    "bearish_points": [],
    "summary": "",
    "confidence_score": 0.xx
  }}
}}
    """


# ---------------------------------------------------------------------
# RESPONSE PARSER
# ---------------------------------------------------------------------
def parse_llm_response(response_text: str) -> Dict[str, Any]:
    """Extract the structured JSON from the LLM response."""
    try:
        json_objects = re.findall(r"\{(?:[^{}]|(?:\{[^{}]*\}))*\}", response_text, re.DOTALL)
        for obj in json_objects:
            try:
                parsed = json.loads(obj)
                if "growth_and_demand" in parsed:
                    return {"moderator": parsed}
            except json.JSONDecodeError:
                continue
    except Exception as e:
        print(f"⚠️ Error parsing LLM response: {e}")
    return {}


# ---------------------------------------------------------------------
# MAIN DEBATE RUNNER
# ---------------------------------------------------------------------
def run_financial_debate(company_name: str, company_data: pd.DataFrame) -> Dict[str, Any]:
    """Run the financial debate using the configured LLM and return parsed results."""
    llm = load_llm()
    summary = format_company_data(company_data)
    prompt = generate_debate_prompt(company_name, summary)

    print(f"\n🧠 Running Financial Debate for {company_name}...")
    print("This may take a few moments...\n")

    response = None
    try:
        response = llm(prompt)
        os.makedirs("outputs/insights", exist_ok=True)

        safe_name = "".join(c if c.isalnum() else "_" for c in company_name)
        raw_path = f"outputs/insights/{safe_name}_debate_raw.txt"
        with open(raw_path, "w", encoding="utf-8") as f:
            f.write(f"Prompt:\n{prompt}\n\nResponse:\n{response}")

        parsed = parse_llm_response(response)
        if not parsed:
            raise ValueError("No valid structured JSON found in LLM response.")

        output_path = f"outputs/insights/{safe_name}_debate.json"
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(parsed, f, indent=2, ensure_ascii=False)

        print(f"✅ Debate completed successfully → {output_path}")
        return parsed

    except Exception as e:
        error_msg = f"❌ Debate processing failed: {e}"
        print(error_msg)

        error_log = {
            "error": str(e),
            "company": company_name,
            "timestamp": pd.Timestamp.now().isoformat(),
        }
        if response:
            error_log["response_sample"] = response[:1000] + "..." if len(response) > 1000 else response

        error_path = f"outputs/insights/error_{pd.Timestamp.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(error_path, "w", encoding="utf-8") as f:
            json.dump(error_log, f, indent=2)
        print(f"⚠️ Error details saved → {error_path}")

        return error_log

