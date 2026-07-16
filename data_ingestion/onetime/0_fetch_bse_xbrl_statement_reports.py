import argparse
import calendar
import csv
import io
import random
import re
import time
import xml.etree.ElementTree as ET
from datetime import datetime, date
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pandas as pd
import requests

BSE_API_BASE = "https://api.bseindia.com/BseIndiaAPI/api"
BSE_ARCHIVE_URL = f"{BSE_API_BASE}/Result_Arch_Download/w"
BSE_INPUT_FILE = Path("data/Equity.csv")
BSE_RESULTS_OUTPUT_DIR = Path("data/bse_xbrl_statement_reports")

HEADERS = {
    "User-Agent": "Mozilla/5.0",
    "Referer": "https://www.bseindia.com/",
    "Origin": "https://www.bseindia.com",
}


class BSEApiClient:
    def __init__(
        self,
        headers: dict,
        timeout: int = 30,
        min_interval_sec: float = 0.45,
        max_retries: int = 5,
        backoff_base_sec: float = 1.6,
        cooldown_every: int = 250,
        cooldown_sec: float = 20.0,
    ):
        self.headers = headers
        self.timeout = timeout
        self.min_interval_sec = max(0.0, min_interval_sec)
        self.max_retries = max(0, max_retries)
        self.backoff_base_sec = max(0.1, backoff_base_sec)
        self.cooldown_every = max(0, cooldown_every)
        self.cooldown_sec = max(0.0, cooldown_sec)
        self.session = requests.Session()
        self.last_request_ts = 0.0
        self.request_count = 0

    def _throttle(self):
        now = time.time()
        elapsed = now - self.last_request_ts
        if elapsed < self.min_interval_sec:
            time.sleep(self.min_interval_sec - elapsed)

        if self.cooldown_every and self.request_count > 0 and self.request_count % self.cooldown_every == 0:
            print(f"Cooling down for {self.cooldown_sec:.1f}s after {self.request_count} requests...")
            time.sleep(self.cooldown_sec)

    def get_response(self, url: str, params: Optional[dict] = None) -> Optional[requests.Response]:
        for attempt in range(self.max_retries + 1):
            self._throttle()
            try:
                response = self.session.get(url, params=params, headers=self.headers, timeout=self.timeout)
                self.last_request_ts = time.time()
                self.request_count += 1

                if response.status_code == 200:
                    return response

                if response.status_code in {403, 429, 500, 502, 503, 504} and attempt < self.max_retries:
                    delay = (self.backoff_base_sec ** (attempt + 1)) + random.uniform(0.1, 0.9)
                    print(f"Retryable HTTP {response.status_code}; sleeping {delay:.1f}s (attempt {attempt + 1}/{self.max_retries})")
                    time.sleep(delay)
                    continue
                return None
            except (requests.Timeout, requests.ConnectionError):
                if attempt < self.max_retries:
                    delay = (self.backoff_base_sec ** (attempt + 1)) + random.uniform(0.1, 0.9)
                    print(f"Network retry; sleeping {delay:.1f}s (attempt {attempt + 1}/{self.max_retries})")
                    time.sleep(delay)
                    continue
                return None
        return None

    def get_text(self, url: str, params: Optional[dict] = None) -> str:
        response = self.get_response(url, params=params)
        return response.text if response is not None else ""

    def get_bytes(self, url: str, params: Optional[dict] = None) -> bytes:
        response = self.get_response(url, params=params)
        return response.content if response is not None else b""


def clean_code(value):
    if value is None:
        return None
    text = str(value).strip()
    if text == "" or text.lower() == "nan":
        return None
    return text


def join_broken_bse_lines(raw_text):
    lines = raw_text.splitlines()
    if not lines:
        return []

    header_lines = []
    first_data_index = None

    for i, line in enumerate(lines):
        if not line.strip():
            continue
        if re.match(r"^\d+\s*,", line):
            first_data_index = i
            break
        header_lines.append(line)

    if first_data_index is None:
        raise ValueError("Could not find BSE data rows in Equity.csv")

    header = " ".join(header_lines).replace("Fac e Value", "Face Value")
    data_rows = []
    current = None

    for line in lines[first_data_index:]:
        if not line.strip():
            continue
        if re.match(r"^\d+\s*,", line):
            if current is not None:
                data_rows.append(current)
            current = line.strip()
        else:
            if current is None:
                current = line.strip()
            else:
                current += " " + line.strip()

    if current is not None:
        data_rows.append(current)

    return [header] + data_rows


def read_bse_equity_file(path: Path) -> pd.DataFrame:
    raw = path.read_text(errors="replace")
    rows = join_broken_bse_lines(raw)
    reader = csv.reader(rows)
    _ = next(reader)

    records = []
    for row in reader:
        if len(row) < 4:
            continue
        records.append({
            "Security Code": clean_code(row[0]),
            "Issuer Name": row[1].strip() if len(row) > 1 else None,
            "Security Name": row[3].strip() if len(row) > 3 else None,
        })

    return pd.DataFrame(records)


def parse_filing_datetime(value: str) -> Optional[datetime]:
    if not value or value == "-":
        return None
    try:
        return datetime.strptime(value.strip(), "%d-%m-%Y %H:%M:%S")
    except Exception:
        return None


def parse_period_label(quarter_field: str) -> Optional[str]:
    if not quarter_field:
        return None
    first = quarter_field.split(";")[0]
    m = re.search(r"Consolidated-([A-Za-z]{3})-(\d{2})$", first)
    if not m:
        return None
    mon = m.group(1).title()
    yy = int(m.group(2))
    year = 2000 + yy
    return f"{mon} {year}"


def period_label_to_date(label: str) -> Optional[date]:
    try:
        dt = datetime.strptime(label, "%b %Y")
        last_day = calendar.monthrange(dt.year, dt.month)[1]
        return date(dt.year, dt.month, last_day)
    except Exception:
        return None


def normalize_xbrl_url(path_or_url: str) -> Optional[str]:
    if not path_or_url or path_or_url == "-":
        return None
    value = path_or_url.strip()
    if value.startswith("http://") or value.startswith("https://"):
        return value
    if value.startswith("/"):
        return "https://www.bseindia.com" + value
    return "https://www.bseindia.com/" + value.lstrip("/")


def fetch_consolidated_archive_rows(scrip_code: str, client: BSEApiClient) -> List[dict]:
    text = client.get_text(BSE_ARCHIVE_URL, params={"scrip_cd": scrip_code})
    if not text:
        return []

    reader = csv.DictReader(io.StringIO(text))
    selected = []
    for row in reader:
        quarter_field = (row.get("Quarter") or "").strip()
        filing_type = (row.get("Type") or "").strip().title()
        xbrl_path = (row.get("Consolidate XBRL") or "").strip()
        if not quarter_field.startswith("Consolidated-"):
            continue
        if filing_type not in {"Quarter", "Year"}:
            continue
        url = normalize_xbrl_url(xbrl_path)
        if not url:
            continue

        label = parse_period_label(quarter_field)
        if not label:
            continue

        code_match = re.search(r";([A-Z]+)", quarter_field)
        period_code = code_match.group(1) if code_match else ""
        if period_code == "MC":
            category = "Annual"
        else:
            category = "Quarterly"

        selected.append({
            "Type": filing_type,
            "Period Code": period_code,
            "Category": category,
            "Period Label": label,
            "Quarter Field": quarter_field,
            "Filing Date Time": parse_filing_datetime(row.get("Filing Date Time", "")),
            "Consolidate XBRL URL": url,
        })

    latest = {}
    for r in selected:
        key = (r["Category"], r["Period Label"])
        prev = latest.get(key)
        if prev is None or (r["Filing Date Time"] or datetime.min) > (prev["Filing Date Time"] or datetime.min):
            latest[key] = r

    return list(latest.values())


def local_name(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def parse_numeric(text: Optional[str]) -> Optional[float]:
    if text is None:
        return None
    t = text.strip().replace(",", "")
    if not t or t in {"-", "--"}:
        return None
    if t.startswith("(") and t.endswith(")"):
        t = "-" + t[1:-1]
    try:
        return float(t)
    except Exception:
        return None


def format_amount(value: Optional[float]) -> str:
    if value is None:
        return ""
    if abs(value) < 0.00005:
        value = 0.0
    if abs(value - round(value)) < 0.005:
        return f"{round(value):,}"
    return f"{value:,.2f}".rstrip("0").rstrip(".")


def format_percent(value: Optional[float]) -> str:
    if value is None:
        return ""
    if abs(value) < 0.00005:
        value = 0.0
    if abs(value - round(value)) < 0.05:
        return f"{round(value)}%"
    return f"{value:.2f}%".rstrip("0").rstrip(".")


def rupees_to_crore(value: Optional[float]) -> Optional[float]:
    if value is None:
        return None
    return value / 10_000_000.0


def safe_div(numerator: Optional[float], denominator: Optional[float]) -> Optional[float]:
    if numerator is None or denominator in (None, 0):
        return None
    return numerator / denominator


def extract_xbrl_fact_map(xml_bytes: bytes) -> Dict[str, float]:
    facts: Dict[str, float] = {}
    if not xml_bytes:
        return facts

    try:
        root = ET.fromstring(xml_bytes)
    except Exception:
        return facts

    # Prefer first occurrence of each local tag among leaf facts.
    for elem in root.iter():
        if len(list(elem)) > 0:
            continue
        value = parse_numeric(elem.text)
        if value is None:
            continue
        tag = local_name(elem.tag)
        if tag not in facts:
            facts[tag] = value
    return facts


P_AND_L_ROWS = [
    (1, "Sales", ["RevenueFromOperations", "Revenue", "Sales"]),
    (2, "Expenses", ["Expenses"]),
    (3, "Operating Profit", ["__COMPUTE__OP"]),
    (4, "OPM %", ["__COMPUTE__OPM"]),
    (5, "Other Income", ["OtherIncome"]),
    (6, "Interest", ["FinanceCosts", "FinanceCost", "InterestExpense", "Interest"]),
    (7, "Depreciation", ["DepreciationDepletionAndAmortisationExpense", "DepreciationAmortisationAndImpairmentExpense", "Depreciation"]),
    (8, "Profit before tax", ["ProfitBeforeTax", "ProfitBeforeExceptionalItemsAndTax"]),
    (9, "Tax %", ["__COMPUTE__TAXPCT"]),
    (10, "Net Profit", ["ProfitLossForPeriod", "ProfitLossForPeriodFromContinuingOperations", "ProfitOrLossAttributableToOwnersOfParent", "NetProfit"]),
    (11, "EPS in Rs", ["BasicEarningsLossPerShareFromContinuingAndDiscontinuedOperations", "BasicEarningsLossPerShareFromContinuingOperations", "BasicEarningsLossPerShare"]),
    (12, "Dividend Payout %", ["DividendPayoutRatio", "DividendPayoutPercentage"]),
]

BALANCE_SHEET_ROWS = [
    (1, "Equity Capital", ["PaidUpValueOfEquityShareCapital", "EquityShareCapital"]),
    (2, "Reserves", ["OtherEquity", "ReservesAndSurplus", "ReserveAndSurplus"]),
    (3, "Borrowings", ["Borrowings", "LongTermBorrowings", "ShortTermBorrowings"]),
    (4, "Other Liabilities", ["OtherLiabilities", "OtherCurrentLiabilities", "OtherNoncurrentLiabilities"]),
    (5, "Total Liabilities", ["TotalLiabilities"]),
    (6, "Fixed Assets", ["FixedAssets", "PropertyPlantAndEquipment"]),
    (7, "CWIP", ["CapitalWorkInProgress"]),
    (8, "Investments", ["Investments", "NonCurrentInvestments", "CurrentInvestments"]),
    (9, "Other Assets", ["OtherAssets", "OtherCurrentAssets", "OtherNoncurrentAssets"]),
    (10, "Total Assets", ["TotalAssets"]),
]

CASH_FLOW_ROWS = [
    (1, "Cash from Operating Activity", ["NetCashFlowFromUsedInOperatingActivities", "NetCashFlowFromOperatingActivities", "CashFromOperatingActivities"]),
    (2, "Cash from Investing Activity", ["NetCashFlowFromUsedInInvestingActivities", "NetCashFlowsFromUsedInInvestingActivities"]),
    (3, "Cash from Financing Activity", ["NetCashFlowFromUsedInFinancingActivities", "NetCashFlowsFromUsedInFinancingActivities"]),
    (4, "Net Cash Flow", ["NetIncreaseDecreaseInCashAndCashEquivalents", "NetCashFlow"]),
    (5, "Free Cash Flow", ["__COMPUTE__FCF"]),
    (6, "CFO/OP", ["__COMPUTE__CFOOP"]),
]


def pick_fact(facts: Dict[str, float], aliases: List[str]) -> Optional[float]:
    for alias in aliases:
        if alias.startswith("__COMPUTE__"):
            continue
        if alias in facts:
            return facts[alias]
    return None


def sum_facts(facts: Dict[str, float], aliases: List[str]) -> Optional[float]:
    values = [facts[a] for a in aliases if a in facts]
    if not values:
        return None
    return sum(values)


def build_statement_row_values(statement: str, facts: Dict[str, float]) -> Dict[str, str]:
    values: Dict[str, str] = {}

    sales = rupees_to_crore(pick_fact(facts, ["RevenueFromOperations", "Revenue", "Sales"]))
    expenses = rupees_to_crore(pick_fact(facts, ["Expenses"]))
    other_income = rupees_to_crore(pick_fact(facts, ["OtherIncome"]))
    interest = rupees_to_crore(pick_fact(facts, ["FinanceCosts", "FinanceCost", "InterestExpense", "Interest"]))
    depreciation = rupees_to_crore(pick_fact(facts, ["DepreciationDepletionAndAmortisationExpense", "DepreciationAmortisationAndImpairmentExpense", "Depreciation"]))
    pbt = rupees_to_crore(pick_fact(facts, ["ProfitBeforeTax", "ProfitBeforeExceptionalItemsAndTax"]))
    tax_expense = rupees_to_crore(pick_fact(facts, ["TaxExpense", "CurrentTax", "DeferredTax"]))
    net_profit = rupees_to_crore(pick_fact(facts, ["ProfitLossForPeriod", "ProfitLossForPeriodFromContinuingOperations", "ProfitOrLossAttributableToOwnersOfParent", "NetProfit"]))
    eps = pick_fact(facts, ["BasicEarningsLossPerShareFromContinuingAndDiscontinuedOperations", "BasicEarningsLossPerShareFromContinuingOperations", "BasicEarningsLossPerShare"])

    if statement == "P&L":
        operating_profit = None if sales is None or expenses is None else sales - expenses
        opm = safe_div(operating_profit, sales)
        tax_pct = safe_div(tax_expense, pbt) if pbt not in (None, 0) else None

        values["Sales"] = format_amount(sales)
        values["Expenses"] = format_amount(expenses)
        values["Operating Profit"] = format_amount(operating_profit)
        values["OPM %"] = format_percent(opm * 100 if opm is not None else None)
        values["Other Income"] = format_amount(other_income)
        values["Interest"] = format_amount(interest)
        values["Depreciation"] = format_amount(depreciation)
        values["Profit before tax"] = format_amount(pbt)
        values["Tax %"] = format_percent(tax_pct * 100 if tax_pct is not None else None)
        values["Net Profit"] = format_amount(net_profit)
        values["EPS in Rs"] = format_amount(eps)
        values["Dividend Payout %"] = ""
        return values

    if statement == "BS":
        equity = rupees_to_crore(pick_fact(facts, ["PaidUpValueOfEquityShareCapital", "EquityShareCapital"]))
        reserves = rupees_to_crore(pick_fact(facts, ["OtherEquity", "ReservesAndSurplus", "ReserveAndSurplus"]))
        borrowings_raw = pick_fact(facts, ["Borrowings", "LongTermBorrowings", "ShortTermBorrowings"])
        if borrowings_raw is None:
            borrowings_raw = sum_facts(facts, ["BorrowingsCurrent", "BorrowingsNoncurrent"])
        borrowings = rupees_to_crore(borrowings_raw)

        other_liab_raw = pick_fact(facts, ["OtherLiabilities", "OtherCurrentLiabilities", "OtherNoncurrentLiabilities"])
        if other_liab_raw is None:
            other_liab_raw = sum_facts(facts, ["OtherCurrentLiabilities", "OtherNoncurrentLiabilities"])
        other_liab = rupees_to_crore(other_liab_raw)

        total_liab_raw = pick_fact(facts, ["TotalLiabilities", "EquityAndLiabilities", "Liabilities"])
        total_liab = rupees_to_crore(total_liab_raw)

        fixed_assets = rupees_to_crore(pick_fact(facts, ["FixedAssets", "PropertyPlantAndEquipment", "PropertyPlantAndEquipmentAndIntangibleAssets"]))
        cwip = rupees_to_crore(pick_fact(facts, ["CapitalWorkInProgress"]))
        investments_raw = pick_fact(facts, ["Investments", "NonCurrentInvestments", "CurrentInvestments"])
        if investments_raw is None:
            investments_raw = sum_facts(facts, ["CurrentInvestments", "NoncurrentInvestments"])
        investments = rupees_to_crore(investments_raw)

        other_assets_raw = pick_fact(facts, ["OtherAssets", "OtherCurrentAssets", "OtherNoncurrentAssets"])
        if other_assets_raw is None:
            other_assets_raw = sum_facts(facts, ["OtherCurrentAssets", "OtherNoncurrentAssets"])
        other_assets = rupees_to_crore(other_assets_raw)

        total_assets_raw = pick_fact(facts, ["TotalAssets", "Assets"])
        total_assets = rupees_to_crore(total_assets_raw)

        values["Equity Capital"] = format_amount(equity)
        values["Reserves"] = format_amount(reserves)
        values["Borrowings"] = format_amount(borrowings)
        values["Other Liabilities"] = format_amount(other_liab)
        values["Total Liabilities"] = format_amount(total_liab)
        values["Fixed Assets"] = format_amount(fixed_assets)
        values["CWIP"] = format_amount(cwip)
        values["Investments"] = format_amount(investments)
        values["Other Assets"] = format_amount(other_assets)
        values["Total Assets"] = format_amount(total_assets)
        return values

    if statement == "CF":
        cfo = rupees_to_crore(pick_fact(facts, [
            "NetCashFlowFromUsedInOperatingActivities",
            "NetCashFlowFromOperatingActivities",
            "NetCashFlowsFromUsedInOperatingActivities",
            "CashFlowsFromUsedInOperatingActivities",
            "CashFromOperatingActivities",
        ]))
        cfi = rupees_to_crore(pick_fact(facts, [
            "NetCashFlowFromUsedInInvestingActivities",
            "NetCashFlowsFromUsedInInvestingActivities",
            "CashFlowsFromUsedInInvestingActivities",
        ]))
        cff = rupees_to_crore(pick_fact(facts, [
            "NetCashFlowFromUsedInFinancingActivities",
            "NetCashFlowsFromUsedInFinancingActivities",
            "CashFlowsFromUsedInFinancingActivities",
        ]))
        net_cf = rupees_to_crore(pick_fact(facts, [
            "NetIncreaseDecreaseInCashAndCashEquivalents",
            "IncreaseDecreaseInCashAndCashEquivalents",
            "NetCashFlow",
        ]))
        capex = rupees_to_crore(
            pick_fact(
                facts,
                [
                    "PaymentsToAcquirePropertyPlantAndEquipment",
                    "PurchaseOfPropertyPlantAndEquipment",
                    "PurchaseOfPropertyPlantAndEquipmentAndIntangibleAssets",
                    "PurchaseOfIntangibleAssets",
                ],
            )
        )
        # Usually capex is shown as cash outflow; if only positive amount is present, treat as negative outflow for FCF computation.
        if capex is not None and capex > 0:
            capex = -capex
        fcf = None if cfo is None or capex is None else cfo + capex
        op_profit = None if sales is None or expenses is None else sales - expenses
        cfoop = safe_div(cfo, op_profit) if cfo is not None and op_profit not in (None, 0) else None

        values["Cash from Operating Activity"] = format_amount(cfo)
        values["Cash from Investing Activity"] = format_amount(cfi)
        values["Cash from Financing Activity"] = format_amount(cff)
        values["Net Cash Flow"] = format_amount(net_cf)
        values["Free Cash Flow"] = format_amount(fcf)
        values["CFO/OP"] = format_percent(cfoop * 100 if cfoop is not None else None)
        return values

    return values


def build_statement_template(statement: str):
    if statement == "P&L":
        return P_AND_L_ROWS
    if statement == "BS":
        return BALANCE_SHEET_ROWS
    if statement == "CF":
        return CASH_FLOW_ROWS
    raise ValueError(statement)


def build_period_columns(company_infos: List[dict], period_type: str, count: int) -> List[str]:
    labels = set()
    for c in company_infos:
        for filing in c["filings"]:
            if filing["Category"] == period_type:
                labels.add(filing["Period Label"])
    ordered = sorted([label for label in labels if period_label_to_date(label) is not None], key=period_label_to_date)
    if count > 0:
        ordered = ordered[-count:]
    return ordered


def build_wide_statement_table(
    company_infos: List[dict],
    statement: str,
    period_type: str,
    period_count: int,
    xml_cache: Dict[str, bytes],
) -> pd.DataFrame:
    columns = build_period_columns(company_infos, period_type, period_count)
    template = build_statement_template(statement)
    rows = []

    # Preload facts by company and period label.
    fact_cache: Dict[Tuple[str, str], Dict[str, float]] = {}
    for c in company_infos:
        filing_by_label = {f["Period Label"]: f for f in c["filings"] if f["Category"] == period_type}
        period_facts: Dict[str, Dict[str, float]] = {}
        for label in columns:
            filing = filing_by_label.get(label)
            if filing is None:
                continue
            url = filing["Consolidate XBRL URL"]
            cache_key = (url, label)
            if cache_key not in fact_cache:
                if url not in xml_cache:
                    xml_cache[url] = c["client"].get_bytes(url)
                fact_cache[cache_key] = extract_xbrl_fact_map(xml_cache[url])
            period_facts[label] = fact_cache[cache_key]

        statement_values_by_period = {
            label: build_statement_row_values(statement, period_facts.get(label, {}))
            for label in columns
        }

        for data_point_no, metric_name, _aliases in template:
            row = {
                "BSE Code": c["bse_code"],
                "Company Name": c["company_name"],
                "Data Point #": data_point_no,
                "Metric": metric_name,
            }
            for label in columns:
                row[label] = statement_values_by_period.get(label, {}).get(metric_name, "")
            rows.append(row)

    out_columns = ["BSE Code", "Company Name", "Data Point #", "Metric"] + columns
    return pd.DataFrame(rows, columns=out_columns)


def collect_successful_companies(bse_df: pd.DataFrame, client: BSEApiClient, limit: int) -> List[dict]:
    candidates = []
    seen = set()
    for _, row in bse_df.iterrows():
        code = clean_code(row.get("Security Code"))
        if not code or code in seen:
            continue
        seen.add(code)
        name = clean_code(row.get("Security Name")) or clean_code(row.get("Issuer Name")) or ""
        candidates.append((code, name))

    successful = []
    attempted = 0
    for code, name in candidates:
        if len(successful) >= limit:
            break
        attempted += 1
        filings = fetch_consolidated_archive_rows(code, client)
        if not filings:
            continue
        successful.append({
            "bse_code": code,
            "company_name": name,
            "filings": filings,
            "client": client,
        })

    print(f"Companies attempted: {attempted:,}; successful with archive/XBRL: {len(successful):,}")
    return successful


def main():
    parser = argparse.ArgumentParser(description="Fetch consolidated XBRL statement reports from BSE")
    parser.add_argument("--bse-file", default=str(BSE_INPUT_FILE), help="Path to local BSE Equity.csv")
    parser.add_argument("--limit", type=int, default=5, help="Number of companies to output")
    parser.add_argument("--quarterly-count", type=int, default=20, help="Number of latest quarterly periods")
    parser.add_argument("--annual-count", type=int, default=10, help="Number of latest annual periods")
    parser.add_argument("--output-prefix", default=None, help="Output file prefix (without suffix)")
    parser.add_argument("--date", default=date.today().strftime("%Y%m%d"), help="Date stamp for output")
    parser.add_argument("--min-interval-sec", type=float, default=0.45, help="Minimum delay between requests")
    parser.add_argument("--max-retries", type=int, default=5, help="Retries for transient errors")
    parser.add_argument("--backoff-base-sec", type=float, default=1.6, help="Exponential backoff base")
    parser.add_argument("--cooldown-every", type=int, default=250, help="Cooldown every N requests")
    parser.add_argument("--cooldown-sec", type=float, default=20.0, help="Cooldown duration")
    parser.add_argument("--timeout-sec", type=int, default=30, help="HTTP timeout")
    args = parser.parse_args()

    bse_df = read_bse_equity_file(Path(args.bse_file))
    print(f"Parsed {len(bse_df):,} BSE rows")

    client = BSEApiClient(
        headers=HEADERS.copy(),
        timeout=args.timeout_sec,
        min_interval_sec=args.min_interval_sec,
        max_retries=args.max_retries,
        backoff_base_sec=args.backoff_base_sec,
        cooldown_every=args.cooldown_every,
        cooldown_sec=args.cooldown_sec,
    )

    companies = collect_successful_companies(bse_df, client, args.limit)

    if args.output_prefix:
        base = Path(args.output_prefix)
        base.parent.mkdir(parents=True, exist_ok=True)
    else:
        BSE_RESULTS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        base = BSE_RESULTS_OUTPUT_DIR / f"bse_xbrl_statements_{args.date}"

    xml_cache: Dict[str, bytes] = {}

    report_specs = [
        ("profit_loss_quarterly", "P&L", "Quarterly", args.quarterly_count),
        ("profit_loss_annual", "P&L", "Annual", args.annual_count),
        ("balance_sheet_quarterly", "BS", "Quarterly", args.quarterly_count),
        ("balance_sheet_annual", "BS", "Annual", args.annual_count),
        ("cash_flow_quarterly", "CF", "Quarterly", args.quarterly_count),
        ("cash_flow_annual", "CF", "Annual", args.annual_count),
    ]

    for suffix, statement, period_type, period_count in report_specs:
        wide_df = build_wide_statement_table(
            company_infos=companies,
            statement=statement,
            period_type=period_type,
            period_count=period_count,
            xml_cache=xml_cache,
        )
        out_file = Path(f"{base}_{suffix}.csv")
        wide_df.to_csv(out_file, index=False)
        print(f"Saved {statement} {period_type.lower()} report: {out_file} ({len(wide_df):,} rows)")


if __name__ == "__main__":
    main()
