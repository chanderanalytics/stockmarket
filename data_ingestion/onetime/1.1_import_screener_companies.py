"""
Script to import companies from Screener CSV using unified codes - ONETIME/FULL VERSION.

This script imports companies from a Screener CSV file and handles
the mapping between unified codes and database IDs properly.
Optimized for one-time/full runs with onetime logging.
"""

import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import pandas as pd
from sqlalchemy import create_engine, or_, and_
from sqlalchemy.orm import sessionmaker
from backend.models import Base, Company
from datetime import datetime
import math
import logging
import re
from sqlalchemy.dialects.postgresql import insert

# Set up logging for one-time/full runs
log_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
logging.basicConfig(
    filename=f'log/import_companies_onetime_{log_datetime}.log',
    filemode='a',
    format='%(asctime)s %(levelname)s: %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

DATABASE_URL = 'postgresql://stockuser:stockpass@localhost:5432/stockdb'
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)

def is_valid_code(code):
    if code is None:
        return False
    if isinstance(code, float) and math.isnan(code):
        return False
    if str(code).strip().lower() == 'nan':
        return False
    if str(code).strip() == '':
        return False
    return True

def clean_code(code):
    """Clean and standardize a code"""
    if not is_valid_code(code):
        return None
    
    code_str = str(code).strip()
    if code_str.lower() == 'nan':
        return None
    
    return code_str

def clean_numeric_value(value):
    """Clean and convert numeric values from CSV"""
    if value is None or str(value).strip() == '' or str(value).lower() == 'nan':
        return None
    
    try:
        # Remove any currency symbols, commas, etc.
        cleaned = str(value).replace(',', '').replace('₹', '').replace('$', '').strip()
        if cleaned == '' or cleaned.lower() == 'nan':
            return None
        return float(cleaned)
    except (ValueError, TypeError):
        return None

# Remove DQ analysis functions
def analyze_csv_data_quality(df):
    pass

def analyze_database_table_quality(session):
    pass

def analyze_companies_data_quality(session):
    pass

def compare_and_update_company(db_company, csv_company_dict):
    changed = False
    updated_fields = []
    field_changes = []
    for field, new_value in csv_company_dict.items():
        if hasattr(db_company, field):
            old_value = getattr(db_company, field)
            if old_value != new_value:
                setattr(db_company, field, new_value)
                changed = True
                updated_fields.append(field)
                field_changes.append((field, old_value, new_value))
    return changed, updated_fields, field_changes

def import_companies_from_csv(csv_file_path):
    """Import companies from CSV file using unified codes with smart comparison"""
    session = Session()
    
    # Initialize quality metrics
    quality_metrics = {
        'start_time': datetime.now(),
        'csv_total_rows': 0,
        'csv_valid_rows': 0,
        'csv_invalid_rows': 0,
        'companies_imported': 0,
        'companies_updated': 0,
        'companies_no_changes': 0,
        'companies_errors': 0,
        'database_errors': 0
    }
    
    try:
        # Log start of import
        logger.info(f"Starting import from {csv_file_path} at {quality_metrics['start_time']}")
        # Read CSV file
        df = pd.read_csv(csv_file_path)
        quality_metrics['csv_total_rows'] = len(df)
        print(f"Loaded {len(df)} companies from CSV")
        logger.info(f"Loaded {len(df)} companies from CSV")
        
        # Clean and validate data
        valid_companies = []
        match = re.search(r'(\d{8})', csv_file_path)
        if match:
            file_date = datetime.strptime(match.group(1), '%Y%m%d').date()
        else:
            raise ValueError("No date found in CSV filename!")
        
        for _, row in df.iterrows():
            nse_code = clean_code(row.get('NSE Code', row.get('nse_code')))
            bse_code = clean_code(row.get('BSE Code', row.get('bse_code')))
            
            # Skip if no valid codes
            if not nse_code and not bse_code:
                quality_metrics['csv_invalid_rows'] += 1
                logger.warning(f"Skipping company with no valid codes: {row.get('Company Name', 'Unknown')}")
                continue
            
            quality_metrics['csv_valid_rows'] += 1
            company_data = {
                'name': row.get('Name', ''),
                'bse_code': row.get('BSE Code', ''),
                'nse_code': row.get('NSE Code', ''),
                'industry': row.get('Industry', ''),
                'current_price': row.get('Current Price', ''),
                'market_capitalization': row.get('Market Capitalization', ''),
                'sales': row.get('Sales', ''),
                'sales_growth_3years': row.get('Sales growth 3Years', ''),
                'profit_after_tax': row.get('Profit after tax', ''),
                'profit_growth_3years': row.get('Profit growth 3Years', ''),
                'profit_growth_5years': row.get('Profit growth 5Years', ''),
                'operating_profit': row.get('Operating profit', ''),
                'opm': row.get('OPM', ''),
                'eps_growth_3years': row.get('EPS growth 3Years', ''),
                'eps': row.get('EPS', ''),
                'return_on_capital_employed': row.get('Return on capital employed', ''),
                'other_income': row.get('Other income', ''),
                'change_in_promoter_holding_3years': row.get('Change in promoter holding 3Years', ''),
                'expected_quarterly_sales': row.get('Expected quarterly sales', ''),
                'expected_quarterly_eps': row.get('Expected quarterly EPS', ''),
                'expected_quarterly_net_profit': row.get('Expected quarterly net profit', ''),
                'debt': row.get('Debt', ''),
                'equity_capital': row.get('Equity capital', ''),
                'preference_capital': row.get('Preference capital', ''),
                'reserves': row.get('Reserves', ''),
                'contingent_liabilities': row.get('Contingent liabilities', ''),
                'free_cash_flow_3years': row.get('Free cash flow 3years', ''),
                'operating_cash_flow_3years': row.get('Operating cash flow 3years', ''),
                'price_to_earning': row.get('Price to Earning', ''),
                'dividend_yield': row.get('Dividend yield', ''),
                'price_to_book_value': row.get('Price to book value', ''),
                'return_on_assets': row.get('Return on assets', ''),
                'debt_to_equity': row.get('Debt to equity', ''),
                'return_on_equity': row.get('Return on equity', ''),
                'promoter_holding': row.get('Promoter holding', ''),
                'earnings_yield': row.get('Earnings yield', ''),
                'pledged_percentage': row.get('Pledged percentage', ''),
                'number_of_equity_shares': row.get('Number of equity shares', ''),
                'book_value': row.get('Book value', ''),
                'inventory_turnover_ratio': row.get('Inventory turnover ratio', ''),
                'exports_percentage': row.get('Exports percentage', ''),
                'asset_turnover_ratio': row.get('Asset Turnover Ratio', ''),
                'financial_leverage': row.get('Financial leverage', ''),
                'number_of_shareholders': row.get('Number of Shareholders', ''),
                'working_capital_days': row.get('Working Capital Days', ''),
                'public_holding': row.get('Public holding', ''),
                'fii_holding': row.get('FII holding', ''),
                'change_in_fii_holding': row.get('Change in FII holding', ''),
                'dii_holding': row.get('DII holding', ''),
                'change_in_dii_holding': row.get('Change in DII holding', ''),
                'cash_conversion_cycle': row.get('Cash Conversion Cycle', ''),
                'volume': row.get('Volume', ''),
                'volume_1week_average': row.get('Volume 1week average', ''),
                'volume_1month_average': row.get('Volume 1month average', ''),
                'high_price_all_time': row.get('High price all time', ''),
                'low_price_all_time': row.get('Low price all time', ''),
                'volume_1year_average': row.get('Volume 1year average', ''),
                'return_over_1year': row.get('Return over 1year', ''),
                'return_over_3months': row.get('Return over 3months', ''),
                'return_over_6months': row.get('Return over 6months', ''),
                'last_modified': file_date
            }
            
            valid_companies.append(company_data)
        
        print(f"Valid companies to import: {len(valid_companies)}")
        logger.info(f"Valid companies to import: {len(valid_companies)}")
        
        # Import companies
        for i, company_data in enumerate(valid_companies, 1):
            nse_code_val = company_data['nse_code']
            bse_code_val = company_data['bse_code']
            if (not nse_code_val or str(nse_code_val).lower() == 'nan') and (not bse_code_val or str(bse_code_val).lower() == 'nan'):
                logger.warning(f"Skipped company (no valid code): {company_data['name']}")
                continue
            if str(nse_code_val).lower() == 'nan':
                company_data['nse_code'] = None
            if str(bse_code_val).lower() == 'nan':
                company_data['bse_code'] = None
            try:
                # True upsert logic for nse_code or bse_code
                if company_data['nse_code']:
                    stmt = insert(Company).values(**company_data).on_conflict_do_update(
                        index_elements=['nse_code'],
                        set_={k: v for k, v in company_data.items() if k != 'nse_code'}
                    )
                    logger.info(f"Upsert by NSE code: {company_data['name']} ({company_data['nse_code']})")
                elif company_data['bse_code']:
                    stmt = insert(Company).values(**company_data).on_conflict_do_update(
                        index_elements=['bse_code'],
                        set_={k: v for k, v in company_data.items() if k != 'bse_code'}
                    )
                    logger.info(f"Upsert by BSE code: {company_data['name']} ({company_data['bse_code']})")
                else:
                    logger.warning(f"Skipped company (no valid code after cleaning): {company_data['name']}")
                    continue
                # Field-level change logging (simulate update detection)
                # (In this upsert, we don't know if it was an insert or update, but we can log the data)
                # If you want to compare with existing DB, you could fetch and compare here (optional, not implemented for speed)
                session.execute(stmt)
                quality_metrics['companies_imported'] += 1
                logger.info(f"Imported/Updated: {company_data['name']} ({company_data['nse_code'] or company_data['bse_code']})")
                # Optionally, log all fields at DEBUG level
                for k, v in company_data.items():
                    logger.debug(f"  {k}: {v}")
                if i % 100 == 0:
                    session.commit()
                    logger.info(f"Progress: {i}/{len(valid_companies)} processed. Imported: {quality_metrics['companies_imported']}, Errors: {quality_metrics['companies_errors']}")
                    print(f"Processed {i}/{len(valid_companies)} companies...")
            except Exception as e:
                quality_metrics['companies_errors'] += 1
                logger.error(f"Error processing {company_data['name']}: {e}")
                continue
        session.commit()
        
        # Calculate final metrics
        quality_metrics['end_time'] = datetime.now()
        quality_metrics['duration'] = quality_metrics['end_time'] - quality_metrics['start_time']
        
        # Prepare summary text
        summary_lines = [
            "="*40,
            f"\nImport Summary:",
            f"- Mode: smart comparison",
            f"- Total companies in CSV: {quality_metrics['csv_total_rows']}",
            f"- Valid companies: {quality_metrics['csv_valid_rows']}",
            f"- New companies imported: {quality_metrics['companies_imported']}",
            f"- Existing companies updated: {quality_metrics['companies_updated']}",
            f"- No changes needed: {quality_metrics['companies_no_changes']}",
            f"- Errors: {quality_metrics['companies_errors']}",
            f"- Success rate: {(quality_metrics['companies_imported'] + quality_metrics['companies_updated']) / quality_metrics['csv_valid_rows'] * 100 if quality_metrics['csv_valid_rows'] else 0:.2f}%",
            f"- Processing duration: {quality_metrics['duration']}",
            "="*40
        ]
        summary_text = "\n".join(summary_lines)
        
        # Print to console
        print(summary_text)
        
        # Write to summary file
        summary_filename = f'log/import_companies_onetime_summary_{log_datetime}.txt'
        with open(summary_filename, 'w') as f:
            f.write(summary_text + '\n')
        
        # Log to log file
        for line in summary_lines:
            logger.info(line)
        
        logger.info(f"Import completed: {quality_metrics['companies_imported']} imported, {quality_metrics['companies_updated']} updated, {quality_metrics['companies_no_changes']} no changes, {quality_metrics['companies_errors']} errors")
        logger.info(f"Import finished at {quality_metrics['end_time']}")
        
    except Exception as e:
        quality_metrics['database_errors'] += 1
        logger.error(f"Import failed: {e}")
        session.rollback()
        raise
    finally:
        session.close()

def get_today_csv_file():
    today_str = datetime.now().strftime('%Y%m%d')
    expected_file = f'data/screener_export_{today_str}.csv'
    if os.path.exists(expected_file):
        return expected_file
    else:
        raise FileNotFoundError(f"No screener_export_{today_str}.csv file found in data folder.")

csv_file = get_today_csv_file()

if __name__ == '__main__':
    import sys
    
    if len(sys.argv) != 2:
        print("Usage: python3 1.1_import_screener_companies.py <csv_file_path>")
        print("Example: python3 1.1_import_screener_companies.py data_ingestion/screener_export_20250704.csv")
        sys.exit(1)
    
    csv_file_path = sys.argv[1]
    import_companies_from_csv(csv_file_path) 