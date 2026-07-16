# XBRL Financial Statement Pipeline

Fresh implementation to extract financial statements from NSE and BSE XBRL filings for Indian companies.

## Architecture

```
Downloader (NSE + BSE)
    ↓
Raw XBRL Files
    ↓
Arelle Parser
    ↓
Raw Facts (CSV)
    ↓
Financial Statement Mapper
    ↓
Income Statement | Balance Sheet | Cash Flow
    ↓
CSV Exports (Consolidated + Standalone)
```

## Coverage

- **Last 10 years**: Annual financial statements
- **Last 20 quarters**: Quarterly financial statements
- **Variants**: Consolidated + Standalone for each period
- **Exchanges**: NSE and BSE
- **Output**: CSV files (no database dependency)

## Directory Structure

```
xbrl_pipeline/
├── xbrl_files/           # Downloaded XBRL files (exchange/bse_code/period_type.xbrl)
├── raw_facts/            # Parsed facts from Arelle (exchange/bse_code/period_facts.csv)
├── financial_statements/ # Mapped statements (exchange/bse_code/{income,balance,cash_flow}.csv)
├── xbrl_downloader.py    # Phase 1: Download XBRL from NSE/BSE
├── arelle_parser.py      # Phase 2: Parse XBRL with Arelle → Extract facts
├── statement_mapper.py   # Phase 3: Map facts to standardized statements
├── pipeline.py           # Orchestrator: Runs all phases
└── README.md
```

## Modules

### 1. `xbrl_downloader.py`
Download XBRL filings from NSE and BSE exchanges.

**Key class**: `XBRLDownloader`
- `download_bse_xbrl(bse_code, company_name)` - Fetch XBRL from BSE
- `download_nse_xbrl(nse_code, company_name)` - Fetch XBRL from NSE (pending implementation)
- `save_xbrl_file(...)` - Save to disk

### 2. `arelle_parser.py`
Parse XBRL files using Arelle library and extract raw facts.

**Key class**: `ArelleXBRLParser`
- `parse_xbrl(xbrl_file_path)` - Parse and extract facts, contexts, units
- `facts_to_dataframe(parsed_xbrl)` - Convert to pandas DataFrame
- `save_facts_csv(...)` - Export facts to CSV

**Requires**: `pip install arelle-release`

### 3. `statement_mapper.py`
Map raw XBRL facts to standardized financial statements using IFRS-Full mappings.

**Key class**: `FinancialStatementMapper`
- `map_income_statement(facts_df, period_end_date)` - Extract income statement
- `map_balance_sheet(facts_df, period_end_date)` - Extract balance sheet
- `map_cash_flow(facts_df, period_end_date)` - Extract cash flow
- `process_facts_file(...)` - Full processing pipeline
- `save_statements(...)` - Export to CSV

**Handles**: Consolidated + Standalone variants

### 4. `pipeline.py`
Orchestrator that runs all phases sequentially.

**Key class**: `XBRLPipeline`
- `run_download_phase(sample_size)` - Phase 1
- `run_parsing_phase(download_results)` - Phase 2
- `run_mapping_phase(parsing_results)` - Phase 3
- `run_pipeline(sample_size)` - Full pipeline

## Usage

### Install Dependencies

```bash
pip install pandas requests arelle-release
```

### Run Full Pipeline

```bash
cd /Users/chanderbhushan/stockmkt
python xbrl_pipeline/pipeline.py
```

### Run on Sample (First 10 Companies)

```bash
python xbrl_pipeline/pipeline.py --sample 10
```

## Output Files

After running the pipeline, you'll find:

```
xbrl_pipeline/financial_statements/
├── BSE/
│   └── 500008/  # Amara Raja (example)
│       ├── income_statement.csv
│       ├── balance_sheet.csv
│       └── cash_flow.csv
├── NSE/
│   └── AMRAJP/
│       ├── income_statement.csv
│       ├── balance_sheet.csv
│       └── cash_flow.csv
└── ...
```

**CSV Structure**: Each statement CSV has:
- `period_end_date` - Date of the financial statement
- `bse_code` / `nse_code` - Company code
- `exchange` - NSE or BSE
- `period` - Period identifier (e.g., "FY2025", "Q1FY2026")
- `variant` - "consolidated" or "standalone"
- Line items (revenue, assets, etc.) with numeric values

## Example: Reading Output

```python
import pandas as pd

# Read Amara Raja's consolidated income statement
df = pd.read_csv("xbrl_pipeline/financial_statements/BSE/500008/income_statement.csv")
print(df[['period', 'variant', 'revenue_from_operations', 'net_profit']])
```

## Current Status

✅ Completed:
- [x] Downloader framework (BSE API integration pending)
- [x] Arelle parser module with facts extraction
- [x] Financial statement mapper with IFRS-Full mappings
- [x] Pipeline orchestrator with logging
- [x] CSV export infrastructure

⏳ In Progress:
- [ ] BSE XBRL URL discovery and download
- [ ] NSE XBRL download implementation
- [ ] Test with real XBRL files
- [ ] Refine tag mappings based on actual filings

## Notes

- BSE and NSE use IFRS-Full XML namespace for concepts
- Consolidated and standalone statements are both extracted when available
- Context filtering handles multiple period types (instant vs duration)
- All values are stored as-is; unit conversion happens at application layer
- Arelle handles XBRL validation and consistency checks

## Future Enhancements

- [ ] Load to PostgreSQL for querying
- [ ] Calculate financial ratios (P/E, D/E, ROE, etc.)
- [ ] Time-series analysis and trend detection
- [ ] Data quality metrics and validation
- [ ] Historical reconciliation across periods
