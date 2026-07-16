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
BSE_RESULTS_OUTPUT_DIR = Path("data/bse_consolidated_results")

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
                resp = self.session.get(url, params=params, headers=self.headers, timeout=self.timeout)
                self.last_request_ts = time.time()
                self.request_count += 1

                if resp.status_code == 200:
                    return resp

                if resp.status_code in {403, 429, 500, 502, 503, 504} and attempt < self.max_retries:
                    delay = (self.backoff_base_sec ** (attempt + 1)) + random.uniform(0.1, 0.9)
                    print(f"Retryable HTTP {resp.status_code}; sleeping {delay:.1f}s (attempt {attempt + 1}/{self.max_retries})")
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
        resp = self.get_response(url, params=params)
        return resp.text if resp is not None else ""

    def get_bytes(self, url: str, params: Optional[dict] = None) -> bytes:
        resp = self.get_response(url, params=params)
        return resp.content if resp is not None else b""


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
    # Example: Consolidated-Mar-26;MQ2025-2026;129.00;c
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

        selected.append({
            "Type": filing_type,
            "Period Label": label,
            "Quarter Field": quarter_field,
            "Filing Date Time": parse_filing_datetime(row.get("Filing Date Time", "")),
            "Consolidate XBRL URL": url,
        })

    # Keep latest filing per (Type, Period Label)
    latest = {}
    for r in selected:
        key = (r["Type"], r["Period Label"])
        prev = latest.get(key)
        if prev is None or (r["Filing Date Time"] or datetime.min) > (prev["Filing Date Time"] or datetime.min):
            latest[key] = r

    return list(latest.values())


def local_name(tag: str) -> str:
    return tag.split("}")[-1] if "}" in tag else tag


def parse_numeric(text: Optional[str]) -> Optional[str]:
    if text is None:
        return None
    t = text.strip().replace(",", "")
    if not t or t in {"-", "--"}:
        return None
    # accounting negative style
    if t.startswith("(") and t.endswith(")"):
        t = "-" + t[1:-1]
    if re.match(r"^-?\d+(\.\d+)?$", t):
        return t
    return None


def camel_to_title(name: str) -> str:
    s1 = re.sub("(.)([A-Z][a-z]+)", r"\1 \2", name)
    s2 = re.sub("([a-z0-9])([A-Z])", r"\1 \2", s1)
    return s2.replace("_", " ").strip()


def extract_xbrl_facts_for_period(xml_bytes: bytes, period_type: str, period_label: str) -> Dict[str, str]:
    facts = {}
    if not xml_bytes:
        return facts

    try:
        root = ET.fromstring(xml_bytes)
    except Exception:
        return facts

    target_dt = period_label_to_date(period_label)
    if target_dt is None:
        return facts

    # context id -> (start_date, end_or_instant_date)
    contexts: Dict[str, Tuple[Optional[date], Optional[date]]] = {}
    for elem in root.iter():
        if local_name(elem.tag).lower() != "context":
            continue
        ctx_id = elem.attrib.get("id")
        if not ctx_id:
            continue

        start_dt = None
        end_dt = None
        instant_dt = None

        for c in elem.iter():
            lname = local_name(c.tag).lower()
            txt = (c.text or "").strip()
            if not txt:
                continue
            try:
                dval = datetime.strptime(txt, "%Y-%m-%d").date()
            except Exception:
                continue

            if lname == "startdate":
                start_dt = dval
            elif lname == "enddate":
                end_dt = dval
            elif lname == "instant":
                instant_dt = dval

        contexts[ctx_id] = (start_dt, end_dt or instant_dt)

    valid_contexts = set()
    for ctx_id, (start_dt, end_dt) in contexts.items():
        if end_dt is None:
            continue
        if end_dt.month != target_dt.month or end_dt.year != target_dt.year:
            continue

        if start_dt is None:
            valid_contexts.add(ctx_id)
            continue

        duration = (end_dt - start_dt).days
        if period_type == "Quarter" and 70 <= duration <= 130:
            valid_contexts.add(ctx_id)
        elif period_type == "Year" and 250 <= duration <= 400:
            valid_contexts.add(ctx_id)

    for elem in root.iter():
        if len(list(elem)) > 0:
            continue
        ctx = elem.attrib.get("contextRef")
        if not ctx or ctx not in valid_contexts:
            continue

        value = parse_numeric(elem.text)
        if value is None:
            continue

        metric = camel_to_title(local_name(elem.tag))
        if metric not in facts:
            facts[metric] = value

    return facts


def build_wide_table_for_type(
    company_infos: List[dict],
    period_type: str,
    target_count: int,
    xml_cache: Dict[str, bytes],
    fact_cache: Dict[Tuple[str, str, str], Dict[str, str]],
) -> pd.DataFrame:
    # Global period list for this file type
    all_labels = set()
    for c in company_infos:
        for item in c["filings"]:
            if item["Type"] == period_type:
                all_labels.add(item["Period Label"])

    ordered = sorted([l for l in all_labels if period_label_to_date(l) is not None], key=period_label_to_date)
    ordered = ordered[-target_count:]

    rows = []
    for c in company_infos:
        filing_by_label = {}
        for item in c["filings"]:
            if item["Type"] != period_type:
                continue
            filing_by_label[item["Period Label"]] = item

        metric_values: Dict[str, Dict[str, str]] = {}

        for label in ordered:
            item = filing_by_label.get(label)
            if not item:
                continue
            url = item["Consolidate XBRL URL"]
            cache_key = (url, period_type, label)
            if cache_key in fact_cache:
                facts = fact_cache[cache_key]
            else:
                if url not in xml_cache:
                    xml_cache[url] = c["client"].get_bytes(url)
                facts = extract_xbrl_facts_for_period(xml_cache[url], period_type, label)
                fact_cache[cache_key] = facts

            for metric, value in facts.items():
                metric_values.setdefault(metric, {})[label] = value

        sorted_metrics = sorted(metric_values.keys())
        for i, metric in enumerate(sorted_metrics, start=1):
            row = {
                "BSE Code": c["bse_code"],
                "Company Name": c["company_name"],
                "Data Point #": i,
                "Metric": metric,
            }
            for label in ordered:
                row[label] = metric_values.get(metric, {}).get(label, "")
            rows.append(row)

    columns = ["BSE Code", "Company Name", "Data Point #", "Metric"] + ordered
    return pd.DataFrame(rows, columns=columns)


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
    parser = argparse.ArgumentParser(description="Fetch consolidated figures from BSE XBRL and export wide annual/quarterly CSVs")
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
        base = BSE_RESULTS_OUTPUT_DIR / f"bse_xbrl_consolidated_{args.date}"

    xml_cache: Dict[str, bytes] = {}
    fact_cache: Dict[Tuple[str, str, str], Dict[str, str]] = {}

    quarterly_df = build_wide_table_for_type(companies, "Quarter", args.quarterly_count, xml_cache, fact_cache)
    annual_df = build_wide_table_for_type(companies, "Year", args.annual_count, xml_cache, fact_cache)

    quarterly_out = Path(f"{base}_quarterly.csv")
    annual_out = Path(f"{base}_annual.csv")

    quarterly_df.to_csv(quarterly_out, index=False)
    annual_df.to_csv(annual_out, index=False)

    print(f"Saved quarterly consolidated XBRL table: {quarterly_out} ({len(quarterly_df):,} rows)")
    print(f"Saved annual consolidated XBRL table: {annual_out} ({len(annual_df):,} rows)")


if __name__ == "__main__":
    main()
