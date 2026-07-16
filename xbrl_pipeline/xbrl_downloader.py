"""
XBRL Downloader for NSE and BSE financial statements.
By default downloads full available history from exchange archives.
"""

import os
import time
import logging
import csv
import io
import re
import threading
from pathlib import Path
from typing import List, Optional, Tuple
from datetime import datetime, timedelta
import requests
import pandas as pd

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Constants
XBRL_OUTPUT_DIR = Path("xbrl_pipeline/xbrl_files")
XBRL_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
FAILED_DOWNLOADS_MANIFEST = Path("xbrl_pipeline/failed_downloads.csv")
# Serialises concurrent writes from parallel download workers
_MANIFEST_LOCK = threading.Lock()

BSE_API_BASE = "https://api.bseindia.com/BseIndiaAPI/api"
NSE_API_BASE = "https://www.nseindia.com"

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Referer": "https://www.bseindia.com/",
    "Origin": "https://www.bseindia.com",
}


class XBRLDownloader:
    """Download XBRL files from NSE and BSE."""
    
    def __init__(self, timeout: int = 30, min_interval_sec: float = 0.5):
        self.timeout = timeout
        self.min_interval_sec = min_interval_sec
        self.last_request_time = 0.0
        self.session = requests.Session()
        self.session.headers.update(HEADERS)
    
    def _throttle(self):
        """Rate limiting between requests."""
        elapsed = time.time() - self.last_request_time
        if elapsed < self.min_interval_sec:
            time.sleep(self.min_interval_sec - elapsed)
    
    def _fetch_url(self, url: str, params: Optional[dict] = None, max_retries: int = 3) -> Optional[bytes]:
        """Fetch URL with retry logic."""
        for attempt in range(max_retries):
            try:
                self._throttle()
                response = self.session.get(url, params=params, timeout=self.timeout)
                self.last_request_time = time.time()
                
                if response.status_code == 200:
                    return response.content
                elif response.status_code in {403, 429, 500, 502, 503}:
                    delay = 2 ** (attempt + 1)
                    logger.warning(f"HTTP {response.status_code} on {url}. Retry in {delay}s...")
                    time.sleep(delay)
                    continue
                else:
                    logger.error(f"HTTP {response.status_code} on {url}")
                    return None
            except (requests.Timeout, requests.ConnectionError) as e:
                if attempt < max_retries - 1:
                    delay = 2 ** (attempt + 1)
                    logger.warning(f"Network error: {e}. Retry in {delay}s...")
                    time.sleep(delay)
                else:
                    logger.error(f"Failed to fetch {url}: {e}")
                    return None
        return None

    @staticmethod
    def _temp_xbrl_file_path(bse_code: str, exchange: str) -> Path:
        """Build temp file path for downloaded XBRL before parsing."""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
        return XBRL_OUTPUT_DIR / exchange / bse_code / f"temp_{timestamp}.xbrl"

    @staticmethod
    def _failure_manifest_key(row: dict) -> tuple:
        return (
            row.get("exchange", ""),
            row.get("company_code", ""),
            row.get("xbrl_url", ""),
        )

    @staticmethod
    def _read_failure_manifest(manifest_path: Path = FAILED_DOWNLOADS_MANIFEST) -> List[dict]:
        if not manifest_path.exists() or manifest_path.stat().st_size == 0:
            return []
        try:
            with manifest_path.open("r", newline="") as handle:
                rows = list(csv.DictReader(handle))
                # Check if rows have old schema fields (period, statement_type, variant, audited_status)
                # If so, clear the manifest as it's incompatible with new schema
                if rows and any('period' in row for row in rows):
                    logger.warning(f"Old manifest schema detected, clearing {manifest_path}")
                    manifest_path.unlink()
                    return []
                return rows
        except Exception as e:
            logger.warning(f"Error reading manifest, clearing: {e}")
            if manifest_path.exists():
                manifest_path.unlink()
            return []

    @staticmethod
    def _write_failure_manifest(rows: List[dict], manifest_path: Path = FAILED_DOWNLOADS_MANIFEST) -> None:
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        fieldnames = [
            "failed_at",
            "company_code",
            "company_name",
            "exchange",
            "xbrl_url",
            "reason",
            "retry_count",
        ]
        if not rows:
            if manifest_path.exists():
                manifest_path.unlink()
            return
        with manifest_path.open("w", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)

    def _record_failed_download(
        self,
        company_code: str,
        company_name: str,
        exchange: str,
        xbrl_url: str,
        reason: str,
        manifest_path: Path = FAILED_DOWNLOADS_MANIFEST,
    ) -> None:
        with _MANIFEST_LOCK:
            rows = self._read_failure_manifest(manifest_path)
            key = (exchange, company_code, xbrl_url)
            updated_rows = [row for row in rows if self._failure_manifest_key(row) != key]
            retry_count = 0
            for row in rows:
                if self._failure_manifest_key(row) == key:
                    try:
                        retry_count = int(row.get("retry_count", "0"))
                    except Exception:
                        retry_count = 0
                    break
            updated_rows.append(
                {
                    "failed_at": datetime.now().isoformat(timespec="seconds"),
                    "company_code": company_code,
                    "company_name": company_name,
                    "exchange": exchange,
                    "xbrl_url": xbrl_url,
                    "reason": reason,
                    "retry_count": str(retry_count),
                }
            )
            self._write_failure_manifest(updated_rows, manifest_path)

    def retry_failed_downloads(self, manifest_path: Path = FAILED_DOWNLOADS_MANIFEST) -> List[dict]:
        """Retry failed downloads listed in the manifest and keep unresolved rows queued."""
        queued_rows = self._read_failure_manifest(manifest_path)
        if not queued_rows:
            logger.info(f"No failed downloads found in {manifest_path}")
            return []

        remaining_rows: List[dict] = []
        restored_results: List[dict] = []

        for row in queued_rows:
            company_code = row.get("company_code", "")
            company_name = row.get("company_name", "")
            exchange = row.get("exchange", "BSE")
            xbrl_url = row.get("xbrl_url", "")
            try:
                xbrl_content = self._fetch_url_bytes(xbrl_url)
                if xbrl_content:
                    saved_path = self.save_temp_xbrl_file(company_code, exchange, xbrl_content)
                    restored_results.append(
                        {
                            "company_code": company_code,
                            "company_name": company_name,
                            "exchange": exchange,
                            "xbrl_file": saved_path,
                            "status": "downloaded",
                        }
                    )
                    logger.info(f"  ✓ Retried XBRL: {xbrl_url}")
                else:
                    try:
                        retry_count = int(row.get("retry_count", "0") or 0) + 1
                    except Exception:
                        retry_count = 1
                    remaining_rows.append({**row, "retry_count": str(retry_count)})
                    logger.warning(f"  ✗ Retry failed: {xbrl_url}")
            except Exception as e:
                try:
                    retry_count = int(row.get("retry_count", "0") or 0) + 1
                except Exception:
                    retry_count = 1
                remaining_rows.append({**row, "retry_count": str(retry_count)})
                logger.error(f"  ✗ Error retrying {xbrl_url}: {e}")

        self._write_failure_manifest(remaining_rows, manifest_path)
        logger.info(f"Retry complete. Restored {len(restored_results)} files, {len(remaining_rows)} still queued.")
        return restored_results

    def download_bse_xbrl(
        self,
        bse_code: str,
        company_name: str,
        annual_limit: Optional[int] = None,
        quarterly_limit: Optional[int] = None,
    ) -> List[Tuple[str, str, str, str, bytes]]:
        """
        Download XBRL files from BSE for a company.
        Returns list of (temp_file_path, xbrl_url, filing_datetime) tuples.
        Fetches both standalone and consolidated annual/quarterly filings from BSE archive.
        Files are saved with temp names; metadata extraction happens later via Arelle parser.
        """
        logger.info(f"Downloading BSE XBRL for {company_name} ({bse_code})")
        results = []
        
        try:
            # Fetch consolidated archive rows from BSE API
            archive_url = f"{BSE_API_BASE}/Result_Arch_Download/w"
            text = self._fetch_url_text(archive_url, params={"scrip_cd": bse_code})
            
            if not text:
                logger.warning(f"  No archive data from BSE for {bse_code}")
                return results
            
            # Parse CSV response from BSE
            import io
            reader = csv.DictReader(io.StringIO(text))
            filings = []
            
            for row in reader:
                quarter_field = (row.get("Quarter") or "").strip()
                filing_type = (row.get("Type") or "").strip().title()

                # Only Annual or Quarterly
                if filing_type not in {"Quarter", "Year", "Annual"}:
                    continue

                # Capture both variants if present
                for variant_label, variant_column in (("consolidated", "Consolidate XBRL"), ("standalone", "Standalone XBRL")):
                    xbrl_url = (row.get(variant_column) or "").strip()
                    if not xbrl_url or xbrl_url == "-":
                        continue

                    # Normalize URL
                    xbrl_url = self._normalize_url(xbrl_url)
                    if not xbrl_url:
                        continue

                    # Extract period from quarter field, stripping variant prefix if present
                    period_source = quarter_field
                    if period_source.startswith("Consolidated-"):
                        period_source = period_source.replace("Consolidated-", "Standalone-") if variant_label == "standalone" else period_source
                    period_source = period_source.replace("Standalone-", "Consolidated-") if variant_label == "consolidated" and period_source.startswith("Standalone-") else period_source
                    period = self._parse_period_label(period_source.replace("Standalone-", "Consolidated-"))
                    if not period:
                        period = self._parse_period_label(quarter_field.replace("Standalone-", "Consolidated-"))
                    if not period:
                        continue

                    filings.append({
                        'quarter_field': quarter_field,
                        'period': period,
                        'type': filing_type,
                        'variant': variant_label,
                        'xbrl_url': xbrl_url,
                        'filing_datetime': row.get("Filing Date Time", ""),
                    })
            
            # Download unique filings (latest version by filing_datetime)
            seen_periods = {}
            for filing in filings:
                period_key = (filing['period'], filing['variant'], filing['type'])
                filing_dt = filing.get('filing_datetime', '')
                if period_key not in seen_periods:
                    seen_periods[period_key] = filing
                else:
                    # Keep the one with later filing datetime
                    existing_dt = seen_periods[period_key].get('filing_datetime', '')
                    if filing_dt > existing_dt:
                        seen_periods[period_key] = filing

            selected_filings = list(seen_periods.values())

            # Optional limits per type (most recent by period label), applied per variant
            if annual_limit is not None or quarterly_limit is not None:
                def period_sort_key(x: dict):
                    try:
                        return datetime.strptime(x['period'], "%b %Y")
                    except Exception:
                        return datetime.min

                limited_filings = []
                for variant_label in ('consolidated', 'standalone'):
                    variant_filings = [f for f in selected_filings if f['variant'] == variant_label]
                    annual = [f for f in variant_filings if f['type'].lower() in {'year', 'annual'}]
                    quarterly = [f for f in variant_filings if f['type'].lower() == 'quarter']

                    annual = sorted(annual, key=period_sort_key, reverse=True)
                    quarterly = sorted(quarterly, key=period_sort_key, reverse=True)

                    if annual_limit is not None:
                        annual = annual[:max(0, annual_limit)]
                    if quarterly_limit is not None:
                        quarterly = quarterly[:max(0, quarterly_limit)]

                    limited_filings.extend(annual + quarterly)

                selected_filings = limited_filings
            
            # Download XBRL content
            for filing in selected_filings:
                try:
                    # Check if file already exists (by constructing expected final filename)
                    # Final format: {YYYY-MM}_{variant}_{type}_{audited_status}.xbrl
                    # Convert period from "Jun 2018" to "2018-06" for filename matching
                    try:
                        period_dt = datetime.strptime(filing['period'], "%b %Y")
                        period_filename = period_dt.strftime("%Y-%m")
                    except:
                        period_filename = filing['period']
                    
                    expected_pattern = f"{period_filename}_{filing['variant']}_{'annual' if filing['type'].lower() in {'year', 'annual'} else 'quarterly'}"
                    output_dir = XBRL_OUTPUT_DIR / "BSE" / bse_code
                    existing_files = list(output_dir.glob(f"{expected_pattern}_*.xbrl"))
                    
                    if existing_files:
                        # File already exists, skip download
                        logger.info(f"  ✓ Skipping {filing['period']} ({filing['variant']}) - already exists")
                        continue
                    
                    xbrl_content = self._fetch_url_bytes(filing['xbrl_url'])
                    if not xbrl_content:
                        logger.warning(f"  ✗ Failed to download XBRL: {filing['xbrl_url']}")
                        self._record_failed_download(
                            bse_code,
                            company_name,
                            "BSE",
                            filing['xbrl_url'],
                            "download_failed",
                        )
                        continue
                    
                    # Save with temp filename
                    temp_path = self.save_temp_xbrl_file(bse_code, "BSE", xbrl_content)
                    results.append((temp_path, filing['xbrl_url'], filing.get('filing_datetime', '')))
                    logger.info(f"  ✓ Downloaded {filing['period']} ({filing['variant']})")
                    
                except Exception as e:
                    logger.error(f"  ✗ Error downloading {filing['period']}: {e}")
                    self._record_failed_download(
                        bse_code,
                        company_name,
                        "BSE",
                        filing['xbrl_url'],
                        str(e),
                    )
            
            logger.info(f"  Total XBRL files: {len(results)}")
            
        except Exception as e:
            logger.error(f"Error downloading BSE XBRL for {bse_code}: {e}")
        
        return results
    
    def _fetch_url_text(self, url: str, params: Optional[dict] = None) -> str:
        """Fetch URL and return text."""
        response = self._fetch_url(url, params=params)
        return response.decode('utf-8', errors='replace') if response else ""
    
    def _fetch_url_bytes(self, url: str, params: Optional[dict] = None) -> Optional[bytes]:
        """Fetch URL and return bytes."""
        return self._fetch_url(url, params=params)
    
    @staticmethod
    def _normalize_url(path_or_url: str) -> Optional[str]:
        """Normalize BSE XBRL path to full URL."""
        if not path_or_url or path_or_url == "-":
            return None
        value = path_or_url.strip()
        if value.startswith("http://") or value.startswith("https://"):
            return value
        if value.startswith("/"):
            return "https://www.bseindia.com" + value
        return "https://www.bseindia.com/" + value.lstrip("/")
    
    @staticmethod
    def _parse_period_label(quarter_field: str) -> Optional[str]:
        """Extract period label from BSE quarter field."""
        if not quarter_field:
            return None
        first = quarter_field.split(";")[0]
        import re
        m = re.search(r"Consolidated-([A-Za-z]{3})-(\d{2})$", first)
        if not m:
            return None
        mon = m.group(1).title()
        yy = int(m.group(2))
        year = 2000 + yy
        return f"{mon} {year}"
    
    def download_nse_xbrl(self, nse_code: str, company_name: str) -> List[Tuple[str, str, bytes]]:
        """
        Download XBRL files from NSE for a company.
        Returns list of (period, statement_type, content) tuples.
        """
        logger.info(f"Downloading NSE XBRL for {company_name} ({nse_code})")
        results = []
        
        try:
            # NSE XBRL download URL pattern
            # Would implement actual NSE API integration here
            pass
            
        except Exception as e:
            logger.error(f"Error downloading NSE XBRL for {nse_code}: {e}")
        
        return results
    
    def save_temp_xbrl_file(self, bse_code: str, exchange: str, content: bytes) -> str:
        """Save XBRL file to disk with temp filename."""
        file_path = self._temp_xbrl_file_path(bse_code, exchange)
        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_bytes(content)
        logger.debug(f"Saved temp XBRL file: {file_path}")
        return str(file_path)


def load_companies(csv_path: str = "data/Equity.csv") -> pd.DataFrame:
    """Load companies from Equity.csv using manual parsing."""
    try:
        companies = []
        with open(csv_path, 'r') as f:
            lines = f.readlines()
            for line in lines[1:]:  # Skip header
                # Extract first 2 CSV fields
                parts = line.split(',', 2)
                if len(parts) >= 2:
                    code = parts[0].strip()
                    name = parts[1].strip()
                    # Check if code is numeric
                    if code.isdigit():
                        companies.append({'bse_code': code, 'company_name': name})
        
        df = pd.DataFrame(companies)
        logger.info(f"Loaded {len(df)} companies from {csv_path}")
        return df
    except Exception as e:
        logger.error(f"Error loading companies: {e}")
        import traceback
        traceback.print_exc()
        return pd.DataFrame()


def main():
    """Main downloader workflow."""
    logger.info("Starting XBRL downloader...")
    
    # Load companies
    companies = load_companies()
    logger.info(f"Loaded {len(companies)} companies")
    
    # Initialize downloader
    downloader = XBRLDownloader()
    
    # Example: Download for first few companies
    for idx, row in companies.head(5).iterrows():
        bse_code = row['bse_code']
        company_name = row['company_name']
        
        # Download BSE XBRL
        bse_files = downloader.download_bse_xbrl(bse_code, company_name)
        logger.info(f"Found {len(bse_files)} BSE XBRL files for {company_name}")
        
        # Download NSE XBRL
        # nse_files = downloader.download_nse_xbrl(nse_code, company_name)
        # logger.info(f"Found {len(nse_files)} NSE XBRL files for {company_name}")


if __name__ == "__main__":
    main()
