import argparse
import csv
import random
import re
import time
from datetime import date
from pathlib import Path
from typing import Optional, Union

import pandas as pd
import requests

BSE_API_BASE = "https://api.bseindia.com/BseIndiaAPI/api"
BSE_RESULTS_LIST_URL = f"{BSE_API_BASE}/Corp_FinanceResult_ng_new/w"
BSE_CONSOLIDATED_RESULT_URL = f"{BSE_API_BASE}/Corp_BSEDnBResults_SEBI_Consolidated_Res_ng/w"
BSE_RESULTS_OUTPUT_DIR = Path("data/bse_consolidated_results")
BSE_INPUT_FILE = Path("data/Equity.csv")

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
        min_interval_sec: float = 0.4,
        max_retries: int = 5,
        backoff_base_sec: float = 1.5,
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

    def get_json(self, url: str, params: dict) -> Union[dict, list]:
        for attempt in range(self.max_retries + 1):
            self._throttle()
            try:
                response = self.session.get(url, params=params, headers=self.headers, timeout=self.timeout)
                self.last_request_ts = time.time()
                self.request_count += 1

                if response.status_code == 200:
                    return response.json()

                if response.status_code in {403, 429, 500, 502, 503, 504}:
                    if attempt < self.max_retries:
                        delay = (self.backoff_base_sec ** (attempt + 1)) + random.uniform(0.1, 0.9)
                        print(f"Retryable HTTP {response.status_code}; sleeping {delay:.1f}s (attempt {attempt + 1}/{self.max_retries})")
                        time.sleep(delay)
                        continue

                return {}
            except (requests.Timeout, requests.ConnectionError):
                if attempt < self.max_retries:
                    delay = (self.backoff_base_sec ** (attempt + 1)) + random.uniform(0.1, 0.9)
                    print(f"Network retry; sleeping {delay:.1f}s (attempt {attempt + 1}/{self.max_retries})")
                    time.sleep(delay)
                    continue
                return {}
            except ValueError:
                return {}

        return {}


def clean_code(value):
    if value is None:
        return None
    text = str(value).strip()
    if text == "" or text.lower() == "nan":
        return None
    return text


def clean_isin(value):
    if value is None:
        return None
    text = str(value).strip().upper()
    if text == "" or text.lower() == "nan" or text == "-":
        return None
    return text


def parse_bse_number(value):
    if value is None:
        return None
    text = str(value).strip().replace(",", "")
    if text in {"", "-", "--"} or text.lower() == "nan":
        return None
    try:
        return float(text)
    except ValueError:
        return None


def format_metric(value):
    if value is None:
        return None
    if isinstance(value, str):
        return clean_code(value)
    if abs(value) < 0.005:
        value = 0
    return f"{value:.2f}".rstrip("0").rstrip(".")


def amount_to_crore(value):
    number = parse_bse_number(value)
    if number is None:
        return None
    # BSE consolidated result details report statement amounts in Rs. million.
    return number / 10


def growth_percent(latest, old, years=3):
    latest = parse_bse_number(latest)
    old = parse_bse_number(old)
    if latest is None or old in (None, 0) or years <= 0:
        return None
    if latest <= 0 or old <= 0:
        return None
    return ((latest / old) ** (1 / years) - 1) * 100


def normalize_label(value):
    text = re.sub(r"[^a-z0-9]+", " ", str(value or "").lower())
    return re.sub(r"\s+", " ", text).strip()


def get_metric(metrics, labels, as_crore=True):
    for label in labels:
        value = metrics.get(normalize_label(label))
        if value is not None:
            return amount_to_crore(value) if as_crore else parse_bse_number(value)
    return None


def join_broken_bse_lines(raw_text):
    lines = raw_text.splitlines()
    if not lines:
        return []

    header_lines = []
    data_lines = []
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
    header = next(reader)
    header = [h.strip() for h in header]

    records = []
    for row in reader:
        if len(row) < 8:
            continue
        records.append({
            "Security Code": clean_code(row[0]),
            "Issuer Name": row[1].strip() if len(row) > 1 else None,
            "Security Id": clean_code(row[2]) if len(row) > 2 else None,
            "Security Name": row[3].strip() if len(row) > 3 else None,
            "Status": row[4].strip() if len(row) > 4 else None,
            "Group": row[5].strip() if len(row) > 5 else None,
            "Face Value": row[6].strip() if len(row) > 6 else None,
            "ISIN No": clean_isin(row[7]) if len(row) > 7 else None,
        })

    return pd.DataFrame(records)


def fetch_bse_consolidated_periods(bse_code: str, client: BSEApiClient) -> list:
    params = {
        "SCRIP_CD": bse_code,
        "FlagDur": "7",
        "HFQ": "",
        "ISUBGROUP_CODE": "",
        "segment": "C",
    }
    payload = client.get_json(BSE_RESULTS_LIST_URL, params=params)
    rows = payload.get("Table", []) if isinstance(payload, dict) else []
    periods = []
    seen = set()

    for row in rows:
        if not row.get("Consol_XMLName"):
            continue

        qtr = row.get("Qtr")
        qtr_number = parse_bse_number(qtr)
        if qtr_number is not None and qtr_number >= 300:
            continue
        qtr_text = str(qtr).strip() if qtr is not None else None
        if not qtr_text or qtr_text in seen:
            continue

        quarter_code = clean_code(row.get("quarter_code")) or ""
        period_prefix = quarter_code[:2].upper()

        periods.append({
            "qtr": qtr_text,
            "quarter_code": quarter_code,
            "period_prefix": period_prefix,
            "company_name": clean_code(row.get("scrip_name") or row.get("company_name")),
            "created_at": clean_code(row.get("Fld_CreateDate")),
        })
        seen.add(qtr_text)

    return periods


def fetch_bse_consolidated_result(bse_code: str, company_name: str, qtr: str, client: BSEApiClient) -> dict:
    params = {
        "usp1": "usp_BSEINDIA_CONSILDATERESULT_UAT",
        "usp2": "USP_GetResult_Type_consolidated",
        "usp3": "usp_GET_BSEDnBResults_SplitUP_consoldated",
        "type1": "c",
        "strtype": qtr,
        "strscripcd": bse_code,
        "strscripname": company_name or "",
        "strresultType": "",
        "action": "show",
    }
    payload = client.get_json(BSE_CONSOLIDATED_RESULT_URL, params=params)

    if not isinstance(payload, list):
        return {}

    headers_by_name = {}
    metrics = {}
    for row in payload:
        if not isinstance(row, dict):
            continue
        description = clean_code(row.get("Description"))
        amount = clean_code(row.get("Amount"))
        if not description:
            continue
        if row.get("RowType") == "Header":
            headers_by_name[description] = amount
        elif row.get("RowType") in {"Data", "Detail"}:
            metrics[normalize_label(description)] = amount

    if not metrics:
        return {}

    return {
        "qtr": qtr,
        "date_begin": headers_by_name.get("Date Begin"),
        "date_end": headers_by_name.get("Date End"),
        "metrics": metrics,
    }


def fetch_bse_consolidated_result_rows(bse_code: str, company_name: str, period: dict, client: BSEApiClient) -> list:
    qtr = period["qtr"]
    params = {
        "usp1": "usp_BSEINDIA_CONSILDATERESULT_UAT",
        "usp2": "USP_GetResult_Type_consolidated",
        "usp3": "usp_GET_BSEDnBResults_SplitUP_consoldated",
        "type1": "c",
        "strtype": qtr,
        "strscripcd": bse_code,
        "strscripname": company_name or period.get("company_name") or "",
        "strresultType": "",
        "action": "show",
    }
    payload = client.get_json(BSE_CONSOLIDATED_RESULT_URL, params=params)

    if not isinstance(payload, list):
        return []

    header_values = {}
    raw_rows = []
    for row in payload:
        if not isinstance(row, dict):
            continue
        if row.get("RowType") == "Header":
            header_values[clean_code(row.get("Description"))] = clean_code(row.get("Amount"))

        raw_rows.append({
            "BSE Code": bse_code,
            "Company Name": company_name or period.get("company_name"),
            "Result Type": "Consolidated",
            "Quarter Code": period.get("quarter_code"),
            "Qtr": qtr,
            "Period Prefix": period.get("period_prefix"),
            "Created At": period.get("created_at"),
            "Date Begin": None,
            "Date End": None,
            "Description": row.get("Description"),
            "Amount": row.get("Amount"),
            "RowType": row.get("RowType"),
            "CssClass": row.get("CssClass"),
            "IsBold": row.get("IsBold"),
        })

    for row in raw_rows:
        row["Date Begin"] = header_values.get("Date Begin")
        row["Date End"] = header_values.get("Date End")

    return raw_rows


def fetch_bse_consolidated_results_table(
    bse_code: str,
    company_name: str,
    client: BSEApiClient,
    max_periods: int = None,
) -> list:
    try:
        periods = fetch_bse_consolidated_periods(bse_code, client)
    except Exception:
        return []

    periods = [
        period for period in periods
        if period["period_prefix"] in {"JQ", "SQ", "DQ", "MQ", "MC"}
    ]
    if max_periods:
        periods = periods[:max_periods]

    rows = []
    for period in periods:
        rows.extend(fetch_bse_consolidated_result_rows(
            bse_code,
            company_name or period.get("company_name"),
            period,
            client,
        ))
    return rows


def build_bse_only_consolidated_results_output(
    bse_df: pd.DataFrame,
    client: BSEApiClient,
    limit_companies: int = 5,
    annual_years: int = 10,
    quarterly_periods: int = 0,
) -> pd.DataFrame:
    bse_df = bse_df.dropna(subset=["Security Code"]).copy()

    companies = []
    seen_codes = set()
    for _, row in bse_df.iterrows():
        bse_code = clean_code(row.get("Security Code"))
        if not bse_code or bse_code in seen_codes:
            continue

        company_name = clean_code(row.get("Security Name")) or clean_code(row.get("Issuer Name"))
        companies.append((bse_code, company_name))
        seen_codes.add(bse_code)

    rows = []
    successful_companies = 0
    attempted_companies = 0

    for bse_code, company_name in companies:
        attempted_companies += 1
        if limit_companies and successful_companies >= limit_companies:
            break
        try:
            periods = fetch_bse_consolidated_periods(bse_code, client)
        except Exception:
            continue

        annual = [p for p in periods if p.get("period_prefix") == "MC"]
        annual.sort(key=lambda p: parse_bse_number(p.get("qtr")) or -1, reverse=True)
        selected = annual[:annual_years]

        if quarterly_periods and quarterly_periods > 0:
            quarterlies = [
                p for p in periods
                if p.get("period_prefix") in {"JQ", "SQ", "DQ", "MQ"}
            ]
            quarterlies.sort(key=lambda p: parse_bse_number(p.get("qtr")) or -1, reverse=True)
            selected.extend(quarterlies[:quarterly_periods])

        if not selected:
            continue

        company_rows = []
        for period in selected:
            company_rows.extend(fetch_bse_consolidated_result_rows(
                bse_code,
                company_name or period.get("company_name"),
                period,
                client,
            ))

        if company_rows:
            rows.extend(company_rows)
            successful_companies += 1

    print(f"Companies attempted: {attempted_companies:,}; successful with data: {successful_companies:,}")

    columns = [
        "BSE Code",
        "Company Name",
        "Result Type",
        "Quarter Code",
        "Qtr",
        "Period Prefix",
        "Created At",
        "Date Begin",
        "Date End",
        "Description",
        "Amount",
        "RowType",
        "CssClass",
        "IsBold",
    ]
    return pd.DataFrame(rows, columns=columns)


def _period_label_from_row(row: pd.Series) -> Optional[str]:
    date_end = clean_code(row.get("Date End"))
    if date_end:
        dt = pd.to_datetime(date_end, errors="coerce", dayfirst=True)
        if pd.notna(dt):
            return dt.strftime("%b %Y")

    qtr = clean_code(row.get("Qtr"))
    if qtr:
        return qtr

    return None


def _build_wide_period_table(raw_df: pd.DataFrame, statement_prefixes: set[str]) -> pd.DataFrame:
    if raw_df.empty:
        return pd.DataFrame()

    df = raw_df.copy()
    df = df[df["Period Prefix"].isin(statement_prefixes)]
    df = df[df["RowType"].isin(["Data", "Detail"])]

    df["Metric"] = df["Description"].apply(clean_code)
    df = df[df["Metric"].notna()]
    df = df[~df["Metric"].isin(["Standalone", "Consolidated", "--"])]

    df["Period"] = df.apply(_period_label_from_row, axis=1)
    df = df[df["Period"].notna()]

    if df.empty:
        return pd.DataFrame()

    period_order = (
        df[["Period", "Date End"]]
        .drop_duplicates()
        .assign(_sort_dt=lambda x: pd.to_datetime(x["Date End"], errors="coerce", dayfirst=True))
        .sort_values(["_sort_dt", "Period"], ascending=True)
    )
    ordered_periods = period_order["Period"].tolist()

    wide = (
        df.pivot_table(
            index=["BSE Code", "Company Name", "Metric"],
            columns="Period",
            values="Amount",
            aggfunc="first",
        )
        .reset_index()
    )

    ordered_periods = [p for p in ordered_periods if p in wide.columns]
    base_cols = ["BSE Code", "Company Name", "Metric"]
    wide = wide[base_cols + ordered_periods]

    metric_priority = {
        "Sales": 1,
        "Expenses": 2,
        "Operating Profit": 3,
    }
    wide["_metric_sort"] = wide["Metric"].map(lambda m: metric_priority.get(m, 999))
    wide = wide.sort_values(["BSE Code", "Company Name", "_metric_sort", "Metric"]).drop(columns=["_metric_sort"])

    return wide


def build_annual_quarterly_exports(raw_df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    annual_df = _build_wide_period_table(raw_df, {"MC"})
    quarterly_df = _build_wide_period_table(raw_df, {"JQ", "SQ", "DQ", "MQ"})
    return annual_df, quarterly_df


def main():
    parser = argparse.ArgumentParser(description="Fetch BSE consolidated results (BSE-only mode)")
    parser.add_argument("--output-file", default=None, help="Base output CSV file path (annual/quarterly suffixes are added)")
    parser.add_argument("--bse-file", default=str(BSE_INPUT_FILE), help="Local BSE equity file path")
    parser.add_argument("--annual-years", type=int, default=10, help="Number of annual consolidated periods (MC) per company")
    parser.add_argument("--quarterly-periods", type=int, default=0, help="Optional number of quarterly consolidated periods per company")
    parser.add_argument("--date", default=date.today().strftime("%Y%m%d"), help="Date stamp for output file")
    parser.add_argument("--limit", type=int, default=5, help="Number of BSE companies to process")
    parser.add_argument("--min-interval-sec", type=float, default=0.45, help="Minimum delay between API requests")
    parser.add_argument("--max-retries", type=int, default=5, help="Retries for transient HTTP/network failures")
    parser.add_argument("--backoff-base-sec", type=float, default=1.6, help="Exponential backoff base")
    parser.add_argument("--cooldown-every", type=int, default=250, help="Pause after every N requests")
    parser.add_argument("--cooldown-sec", type=float, default=20.0, help="Cooldown duration in seconds")
    parser.add_argument("--timeout-sec", type=int, default=30, help="HTTP timeout in seconds")
    args = parser.parse_args()

    output_file = args.output_file
    if not output_file:
        BSE_RESULTS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        base_output = BSE_RESULTS_OUTPUT_DIR / f"bse_consolidated_10y_{args.date}"
    else:
        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        if output_path.suffix.lower() == ".csv":
            base_output = output_path.with_suffix("")
        else:
            base_output = output_path

    print("Reading BSE equity file...")
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

    print("Fetching BSE-only consolidated results...")
    bse_results_df = build_bse_only_consolidated_results_output(
        bse_df=bse_df,
        client=client,
        limit_companies=args.limit,
        annual_years=args.annual_years,
        quarterly_periods=args.quarterly_periods,
    )
    annual_df, quarterly_df = build_annual_quarterly_exports(bse_results_df)

    raw_output = Path(f"{base_output}_raw.csv")
    annual_output = Path(f"{base_output}_annual.csv")
    quarterly_output = Path(f"{base_output}_quarterly.csv")

    bse_results_df.to_csv(raw_output, index=False)
    annual_df.to_csv(annual_output, index=False)
    quarterly_df.to_csv(quarterly_output, index=False)

    print(f"Saved raw BSE consolidated table: {raw_output}")
    print(f"Saved annual period-wise table: {annual_output}")
    print(f"Saved quarterly period-wise table: {quarterly_output}")
    print(f"Raw rows: {len(bse_results_df):,}, Annual rows: {len(annual_df):,}, Quarterly rows: {len(quarterly_df):,}")


if __name__ == "__main__":
    main()
