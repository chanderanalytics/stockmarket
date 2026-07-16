"""
XBRL Financial Statement Pipeline Orchestrator
Complete workflow: Download XBRL → Parse with Arelle → Map to Statements → Export CSV
"""

import logging
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
import pandas as pd
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime, timedelta
import sys

# Import pipeline modules
try:
    from .xbrl_downloader import XBRLDownloader, load_companies
    from .arelle_parser import ArelleXBRLParser, parse_all_xbrl_files
    from .statement_builder import FinancialStatementBuilder
except ImportError:
    from xbrl_downloader import XBRLDownloader, load_companies
    from arelle_parser import ArelleXBRLParser, parse_all_xbrl_files
    from statement_builder import FinancialStatementBuilder

logger = logging.getLogger(__name__)

# Configure logging
log_file = Path('xbrl_pipeline/pipeline.log')
log_file.parent.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, mode='a'),
        logging.StreamHandler(sys.stdout)
    ],
    force=True
)


class XBRLPipeline:
    """Orchestrate complete XBRL pipeline."""
    
    def __init__(self):
        self.downloader = XBRLDownloader()
        self.parser = ArelleXBRLParser() if self._arelle_available() else None
        self.statement_builder = FinancialStatementBuilder()
        self.pipeline_results = []
    
    @staticmethod
    def _arelle_available() -> bool:
        """Check if Arelle is installed."""
        try:
            import arelle
            return True
        except ImportError:
            logger.warning("Arelle not available. Install with: pip install arelle-release")
            return False

    @staticmethod
    def _download_one_company(
        bse_code: str,
        company_name: str,
        annual_limit: Optional[int],
        quarterly_limit: Optional[int],
    ) -> List[Dict]:
        """Download XBRL files for a single company.

        Creates its own XBRLDownloader so threads never share session/throttle state.
        Returns temp files; metadata extraction happens during parsing phase.
        """
        downloader = XBRLDownloader()
        company_results: List[Dict] = []
        try:
            bse_files = downloader.download_bse_xbrl(
                bse_code,
                company_name,
                annual_limit=annual_limit,
                quarterly_limit=quarterly_limit,
            )
            for temp_file_path, xbrl_url, filing_datetime in bse_files:
                company_results.append({
                    "company_code": bse_code,
                    "company_name": company_name,
                    "exchange": "BSE",
                    "xbrl_file": temp_file_path,
                    "xbrl_url": xbrl_url,
                    "filing_datetime": filing_datetime,
                })
        except Exception as e:
            logger.error(f"BSE download failed for {company_name} ({bse_code}): {e}")
        return company_results

    def run_download_phase(
        self,
        sample_size: int = None,
        annual_limit: int = None,
        quarterly_limit: int = None,
        workers: int = 4,
        start_index: int = None,
        end_index: int = None,
    ) -> List[Dict]:
        """
        Phase 1: Download XBRL files from NSE and BSE.
        workers > 1 processes that many companies in parallel (each gets its own
        XBRLDownloader instance so sessions and throttle state are never shared).
        """
        logger.info("="*60)
        logger.info("PHASE 1: DOWNLOADING XBRL FILES")
        logger.info("="*60)

        companies = load_companies()
        
        # Apply batch slicing if indices provided
        if start_index is not None or end_index is not None:
            start = start_index if start_index is not None else 0
            end = end_index if end_index is not None else len(companies)
            companies = companies.iloc[start:end]
            logger.info(f"Processing batch: companies {start} to {end-1}")
        
        if sample_size:
            companies = companies.head(sample_size)

        total = len(companies)
        logger.info(f"Processing {total} companies  |  workers={workers}")

        download_results: List[Dict] = []
        company_rows = [
            (row["bse_code"], row["company_name"])
            for _, row in companies.iterrows()
        ]

        start_time = datetime.now()

        if workers <= 1:
            # ── Sequential (original) path ─────────────────────────────────
            for i, (bse_code, company_name) in enumerate(company_rows, 1):
                progress_pct = (i / total) * 100
                elapsed = datetime.now() - start_time
                if i > 1:
                    avg_time_per_company = elapsed.total_seconds() / i
                    remaining = (total - i) * avg_time_per_company
                    eta = timedelta(seconds=int(remaining))
                    logger.info(f"\n[{i}/{total}] {progress_pct:.2f}% | ETA {eta} | {company_name} ({bse_code})")
                else:
                    logger.info(f"\n[{i}/{total}] {progress_pct:.2f}% | {company_name} ({bse_code})")
                
                results = self._download_one_company(
                    bse_code, company_name, annual_limit, quarterly_limit
                )
                download_results.extend(results)
                logger.info(f"  BSE: {len(results)} files")
        else:
            # ── Parallel path ──────────────────────────────────────────────
            # results list is extended only inside the as_completed loop
            # (single thread at that point), so no extra lock needed.
            completed = 0
            count_lock = threading.Lock()

            with ThreadPoolExecutor(max_workers=workers) as executor:
                future_to_meta = {
                    executor.submit(
                        self._download_one_company,
                        bse_code, company_name, annual_limit, quarterly_limit,
                    ): (i + 1, bse_code, company_name)
                    for i, (bse_code, company_name) in enumerate(company_rows)
                }

                for future in as_completed(future_to_meta):
                    i, bse_code, company_name = future_to_meta[future]
                    try:
                        results = future.result()
                        download_results.extend(results)
                        with count_lock:
                            completed += 1
                            done = completed
                        progress_pct = (done / total) * 100
                        elapsed = datetime.now() - start_time
                        if done > 1:
                            avg_time_per_company = elapsed.total_seconds() / done
                            remaining = (total - done) * avg_time_per_company
                            eta = timedelta(seconds=int(remaining))
                            logger.info(
                                f"[{done}/{total}] {progress_pct:.2f}% | ETA {eta} | {company_name} ({bse_code}): {len(results)} files"
                            )
                        else:
                            logger.info(
                                f"[{done}/{total}] {progress_pct:.2f}% | {company_name} ({bse_code}): {len(results)} files"
                            )
                    except Exception as e:
                        with count_lock:
                            completed += 1
                            done = completed
                        progress_pct = (done / total) * 100
                        elapsed = datetime.now() - start_time
                        if done > 1:
                            avg_time_per_company = elapsed.total_seconds() / done
                            remaining = (total - done) * avg_time_per_company
                            eta = timedelta(seconds=int(remaining))
                            logger.error(
                                f"[{done}/{total}] {progress_pct:.2f}% | ETA {eta} | {company_name} ({bse_code}) failed: {e}"
                            )
                        else:
                            logger.error(
                                f"[{done}/{total}] {progress_pct:.2f}% | {company_name} ({bse_code}) failed: {e}"
                            )

        logger.info(f"\n✓ Downloaded {len(download_results)} XBRL files total")
        return download_results
    
    def run_parsing_phase(self, download_results: List[Dict] = None) -> List[Dict]:
        """
        Phase 2: Parse XBRL files with Arelle, extract metadata, and rename files.
        If download_results is None, discovers all existing XBRL files.
        """
        logger.info("\n" + "="*60)
        logger.info("PHASE 2: PARSING XBRL FILES WITH ARELLE")
        logger.info("="*60)
        
        if not self.parser:
            logger.error("Arelle not available. Skipping parsing phase.")
            return []
        
        # If no download results provided, discover existing XBRL files
        if download_results is None:
            try:
                from .xbrl_downloader import XBRL_OUTPUT_DIR
            except ImportError:
                from xbrl_downloader import XBRL_OUTPUT_DIR
            xbrl_files = list(XBRL_OUTPUT_DIR.rglob("*.xbrl"))
            download_results = []
            for xbrl_file in xbrl_files:
                # Extract company_code and exchange from path
                parts = xbrl_file.relative_to(XBRL_OUTPUT_DIR).parts
                if len(parts) >= 2:
                    exchange = parts[0]
                    company_code = parts[1]
                    download_results.append({
                        'xbrl_file': str(xbrl_file),
                        'company_code': company_code,
                        'exchange': exchange,
                        'company_name': '',  # Not available from path
                    })
            logger.info(f"Discovered {len(download_results)} existing XBRL files")
        
        parsing_results = []
        total = len(download_results)
        start_time = datetime.now()
        
        for i, result in enumerate(download_results, 1):
            xbrl_file = result['xbrl_file']
            progress_pct = (i / total) * 100
            elapsed = datetime.now() - start_time
            if i > 1:
                avg_time_per_file = elapsed.total_seconds() / i
                remaining = (total - i) * avg_time_per_file
                eta = timedelta(seconds=int(remaining))
                logger.info(f"\n[{i}/{total}] {progress_pct:.2f}% | ETA {eta} | Parsing: {Path(xbrl_file).name}")
            else:
                logger.info(f"\n[{i}/{total}] {progress_pct:.2f}% | Parsing: {Path(xbrl_file).name}")
            
            try:
                parsed = self.parser.parse_xbrl(xbrl_file)
                
                if parsed and parsed.get('fact_count', 0) > 0:
                    # Extract metadata
                    metadata = parsed.get('metadata', {})
                    
                    # Rename temp file to proper name based on metadata
                    company_code = result.get('company_code', 'unknown')
                    exchange = result.get('exchange', 'unknown')
                    renamed_file = self.parser.rename_xbrl_file(xbrl_file, metadata, company_code, exchange)
                    
                    # Save facts to CSV using metadata
                    period = metadata.get('reporting_period', 'unknown')
                    variant = metadata.get('variant', 'unknown')
                    stmt_type = metadata.get('statement_type', 'unknown')
                    
                    csv_path = self.parser.save_facts_csv(
                        parsed,
                        company_code,
                        period,
                        exchange,
                        variant=variant,
                        filing_type=stmt_type,
                        audited_status=metadata.get('audited_status'),
                    )
                    
                    parsing_results.append({
                        'company_code': company_code,
                        'company_name': result.get('company_name', ''),
                        'exchange': exchange,
                        'period': period,
                        'statement_type': stmt_type,
                        'variant': variant,
                        'audited_status': metadata.get('audited_status', 'unknown'),
                        'xbrl_file': renamed_file,
                        'facts_csv': csv_path,
                        'fact_count': parsed['fact_count'],
                    })
                    
                    logger.info(f"  ✓ Extracted {parsed['fact_count']} facts")
                else:
                    logger.warning(f"  ⚠ No facts found in XBRL (empty file or test data)")
            
            except Exception as e:
                logger.error(f"  ✗ Parsing error: {e}")
        
        logger.info(f"\n✓ Parsed {len(parsing_results)} files successfully")
        return parsing_results
    
    def discover_parsed_fact_files(self) -> List[Dict]:
        """Discover existing parsed fact CSV files."""
        try:
            from .arelle_parser import FACTS_OUTPUT_DIR
        except ImportError:
            from arelle_parser import FACTS_OUTPUT_DIR
        
        fact_files = list(FACTS_OUTPUT_DIR.rglob("*_facts.csv"))
        parsing_results = []
        
        for fact_file in fact_files:
            # Extract metadata from filename
            # Format: {period}_{variant}_{filing_type}_{audited_status}_facts.csv
            filename = fact_file.stem
            parts = filename.split('_')
            
            if len(parts) >= 3:
                # Extract company_code and exchange from path
                path_parts = fact_file.relative_to(FACTS_OUTPUT_DIR).parts
                if len(path_parts) >= 2:
                    exchange = path_parts[0]
                    company_code = path_parts[1]
                    
                    # Parse filename components
                    period = parts[0]
                    variant = parts[1] if len(parts) > 1 else 'unknown'
                    filing_type = parts[2] if len(parts) > 2 else 'unknown'
                    audited_status = parts[3] if len(parts) > 3 else 'unknown'
                    
                    parsing_results.append({
                        'company_code': company_code,
                        'company_name': '',  # Not available from path
                        'exchange': exchange,
                        'period': period,
                        'statement_type': filing_type,
                        'variant': variant,
                        'audited_status': audited_status,
                        'facts_csv': str(fact_file),
                    })
        
        logger.info(f"Discovered {len(parsing_results)} existing fact files")
        return parsing_results
    
    def run_mapping_phase(self, parsing_results: List[Dict] = None) -> List[Dict]:
        """
        Phase 3: Map raw facts to standardized financial statements
        If parsing_results is None, discovers existing parsed fact files.
        """
        logger.info("\n" + "="*60)
        logger.info("PHASE 3: MAPPING TO FINANCIAL STATEMENTS")
        logger.info("="*60)
        
        # If no parsing results provided, discover existing fact files
        if parsing_results is None:
            parsing_results = self.discover_parsed_fact_files()
        
        mapping_results = []
        total = len(parsing_results)
        start_time = datetime.now()
        
        for i, result in enumerate(parsing_results, 1):
            progress_pct = (i / total) * 100
            elapsed = datetime.now() - start_time
            if i > 1:
                avg_time_per_file = elapsed.total_seconds() / i
                remaining = (total - i) * avg_time_per_file
                eta = timedelta(seconds=int(remaining))
                logger.info(f"\n[{i}/{total}] {progress_pct:.2f}% | ETA {eta} | Mapping: {result['company_code']} ({result['period']})")
            else:
                logger.info(f"\n[{i}/{total}] {progress_pct:.2f}% | Mapping: {result['company_code']} ({result['period']})")
            
            try:
                # Process facts file
                income_stmts, balance_stmts, cash_flow_stmts = self.statement_builder.process_facts_file(
                    result['facts_csv'],
                    result['company_code'],
                    result['exchange'],
                    result['period'],
                    result.get('statement_type'),
                    result.get('audited_status'),
                )
                
                # Save statements
                income_file, balance_file, cash_flow_file = self.statement_builder.save_statements(
                    result['company_code'],
                    result['exchange'],
                    income_stmts,
                    balance_stmts,
                    cash_flow_stmts
                )
                
                mapping_results.append({
                    'company_code': result['company_code'],
                    'company_name': result['company_name'],
                    'exchange': result['exchange'],
                    'period': result['period'],
                    'statement_type': result.get('statement_type'),
                    'variant': result.get('variant'),
                    'audited_status': result.get('audited_status', 'unknown'),
                    'facts_csv': result['facts_csv'],
                    'income_statement_csv': income_file,
                    'balance_sheet_csv': balance_file,
                    'cash_flow_csv': cash_flow_file,
                    'income_stmt_count': len(income_stmts),
                    'balance_stmt_count': len(balance_stmts),
                    'cash_flow_stmt_count': len(cash_flow_stmts),
                })
                
                logger.info(f"  ✓ Income: {len(income_stmts)}, Balance: {len(balance_stmts)}, Cash Flow: {len(cash_flow_stmts)}")
            
            except Exception as e:
                logger.error(f"  ✗ Mapping error: {e}")
        
        logger.info(f"\n✓ Mapped {len(mapping_results)} files to statements")
        return mapping_results
    
    def run_pipeline(
        self,
        sample_size: int = None,
        annual_limit: int = None,
        quarterly_limit: int = None,
        workers: int = 4,
        start_index: int = None,
        end_index: int = None,
    ):
        """Run complete pipeline."""
        logger.info("\n")
        logger.info("╔════════════════════════════════════════════════════════════╗")
        logger.info("║         XBRL FINANCIAL STATEMENT PIPELINE                  ║")
        logger.info("║     Download → Parse → Map → Export (to CSV)               ║")
        logger.info("╚════════════════════════════════════════════════════════════╝")

        start_time = datetime.now()

        # Phase 1: Download
        download_results = self.run_download_phase(
            sample_size=sample_size,
            annual_limit=annual_limit,
            quarterly_limit=quarterly_limit,
            workers=workers,
            start_index=start_index,
            end_index=end_index,
        )
        
        if not download_results:
            logger.warning("No XBRL files downloaded. Exiting.")
            return
        
        # Phase 2: Parse with Arelle
        parsing_results = self.run_parsing_phase(download_results)
        
        if not parsing_results:
            logger.warning("No files parsed. Exiting.")
            return
        
        # Phase 3: Map to statements
        mapping_results = self.run_mapping_phase(parsing_results)
        
        # Summary
        elapsed = datetime.now() - start_time
        
        logger.info("\n" + "="*60)
        logger.info("PIPELINE COMPLETE - SUMMARY")
        logger.info("="*60)
        logger.info(f"Total time: {elapsed}")
        logger.info(f"Files downloaded: {len(download_results)}")
        logger.info(f"Files parsed: {len(parsing_results)}")
        logger.info(f"Statements mapped: {len(mapping_results)}")
        logger.info(f"\nOutput directory: xbrl_pipeline/financial_statements/")
        
        # Save pipeline report
        if mapping_results:
            report_df = pd.DataFrame(mapping_results)
            report_file = Path("xbrl_pipeline") / f"pipeline_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
            report_df.to_csv(report_file, index=False)
            logger.info(f"Pipeline report saved: {report_file}")

    def run_retry_failed_downloads(self):
        """Retry failed downloads from the manifest only."""
        logger.info("\n")
        logger.info("╔════════════════════════════════════════════════════════════╗")
        logger.info("║         XBRL FAILED DOWNLOAD RETRY                         ║")
        logger.info("╚════════════════════════════════════════════════════════════╝")
        start_time = datetime.now()
        restored = self.downloader.retry_failed_downloads()
        elapsed = datetime.now() - start_time
        logger.info("\n" + "="*60)
        logger.info("RETRY COMPLETE - SUMMARY")
        logger.info("="*60)
        logger.info(f"Total time: {elapsed}")
        logger.info(f"Files restored: {len(restored)}")


def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description="XBRL Financial Statement Pipeline")
    parser.add_argument("--sample", type=int, default=None, help="Process only N companies (for testing)")
    parser.add_argument("--annual-limit", type=int, default=None,
                        help="Max annual filings per company (default: all available)")
    parser.add_argument("--quarterly-limit", type=int, default=None,
                        help="Max quarterly filings per company (default: all available)")
    parser.add_argument("--phase", choices=['download', 'parse', 'map', 'all', 'retry-failures'], default='all',
                       help="Run specific pipeline phase")
    parser.add_argument("--workers", type=int, default=4,
                        help="Parallel download workers per company (default: 4). "
                             "Use 1 for sequential. Raise to 8 if BSE does not rate-limit you.")
    parser.add_argument("--start-index", type=int, default=None,
                        help="Start index for batch processing (0-based)")
    parser.add_argument("--end-index", type=int, default=None,
                        help="End index for batch processing (exclusive)")

    args = parser.parse_args()

    pipeline = XBRLPipeline()
    
    if args.phase == 'retry-failures':
        pipeline.run_retry_failed_downloads()
    elif args.phase == 'download':
        download_results = pipeline.run_download_phase(
            sample_size=args.sample,
            annual_limit=args.annual_limit,
            quarterly_limit=args.quarterly_limit,
            workers=args.workers,
            start_index=args.start_index,
            end_index=args.end_index,
        )
        logger.info(f"Download complete: {len(download_results)} files")
    elif args.phase == 'parse':
        # Parse all existing XBRL files
        parsing_results = pipeline.run_parsing_phase()
        logger.info(f"Parsing complete: {len(parsing_results)} files")
    elif args.phase == 'map':
        # Map all existing parsed facts
        mapping_results = pipeline.run_mapping_phase()
        logger.info(f"Mapping complete: {len(mapping_results)} files")
    else:  # 'all' or default
        pipeline.run_pipeline(
            sample_size=args.sample,
            annual_limit=args.annual_limit,
            quarterly_limit=args.quarterly_limit,
            workers=args.workers,
            start_index=args.start_index,
            end_index=args.end_index,
        )


if __name__ == "__main__":
    main()
