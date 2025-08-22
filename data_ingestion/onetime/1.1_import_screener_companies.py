"""
Script to import companies from Screener CSV using unified codes - MINIMAL FIX VERSION.

This script imports companies from a Screener CSV file and handles
the mapping between unified codes and database IDs properly.
Minimal changes to fix transaction and duplicate key issues.
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
    filename=f'log/import_companies_onetime_minimal_{log_datetime}.log',
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

def import_companies_from_csv(csv_file_path):
    """Import companies from CSV file using unified codes with minimal fixes"""
    session = Session()
    
    # Initialize quality metrics
    quality_metrics = {
        'csv_total_rows': 0,
        'csv_valid_rows': 0,
        'csv_invalid_rows': 0,
        'companies_imported': 0,
        'companies_updated': 0,
        'companies_no_changes': 0,
        'companies_errors': 0,
        'database_errors': 0,
        'start_time': datetime.now(),
        'end_time': None,
        'duration': None
    }
    
    try:
        # Read CSV file
        logger.info(f"Reading CSV file: {csv_file_path}")
        df = pd.read_csv(csv_file_path)
        quality_metrics['csv_total_rows'] = len(df)
        
        # Extract date from filename
        match = re.search(r'(\d{8})', csv_file_path)
        if match:
            file_date = datetime.strptime(match.group(1), '%Y%m%d').date()
        else:
            raise ValueError("No date found in CSV filename!")
        
        logger.info(f"Processing {len(df)} companies from CSV dated {file_date}")
        
        # Clean and validate data
        valid_companies = []
        for _, row in df.iterrows():
            nse_code = clean_code(row.get('NSE Code', row.get('nse_code')))
            bse_code = clean_code(row.get('BSE Code', row.get('bse_code')))
            
            # Skip if no valid codes
            if not nse_code and not bse_code:
                quality_metrics['csv_invalid_rows'] += 1
                logger.warning(f"Skipping company with no valid codes: {row.get('Name', 'Unknown')}")
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
        
        # Import companies with minimal fixes
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
                # MINIMAL FIX: Check if company exists before trying to insert
                existing_company = None
                if company_data['nse_code']:
                    existing_company = session.query(Company).filter(Company.nse_code == company_data['nse_code']).first()
                if not existing_company and company_data['bse_code']:
                    # Convert BSE code to string for proper comparison
                    bse_code_str = str(company_data['bse_code'])
                    existing_company = session.query(Company).filter(Company.bse_code == bse_code_str).first()
                
                if existing_company:
                    # Update existing company
                    for key, value in company_data.items():
                        if key != 'id':
                            setattr(existing_company, key, value)
                    session.merge(existing_company)
                    session.commit()
                    quality_metrics['companies_updated'] += 1
                    logger.info(f"Updated existing company: {company_data['name']}")
                else:
                    # Insert new company - use original upsert logic
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
                    
                    session.execute(stmt)
                    quality_metrics['companies_imported'] += 1
                    logger.info(f"Imported new company: {company_data['name']} ({company_data['nse_code'] or company_data['bse_code']})")
                
                # MINIMAL FIX: Commit each company individually to avoid transaction issues
                if i % 50 == 0:
                    session.commit()
                    logger.info(f"Progress: {i}/{len(valid_companies)} processed. Imported: {quality_metrics['companies_imported']}, Updated: {quality_metrics['companies_updated']}, Errors: {quality_metrics['companies_errors']}")
                    print(f"Processed {i}/{len(valid_companies)} companies...")
            except Exception as e:
                quality_metrics['companies_errors'] += 1
                logger.error(f"Error processing {company_data['name']}: {e}")
                # MINIMAL FIX: Rollback and continue instead of breaking
                try:
                    session.rollback()
                except:
                    pass
                continue
        
        session.commit()
        
        # Calculate final metrics
        quality_metrics['end_time'] = datetime.now()
        quality_metrics['duration'] = quality_metrics['end_time'] - quality_metrics['start_time']
        
        # Prepare summary text
        summary_lines = [
            "="*40,
            f"\nImport Summary:",
            f"- Mode: minimal fix",
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
        summary_filename = f'log/import_companies_onetime_minimal_summary_{log_datetime}.txt'
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

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python3 1.1_import_screener_companies_minimal_fix.py <csv_file_path>")
        sys.exit(1)
    
    csv_file_path = sys.argv[1]
    import_companies_from_csv(csv_file_path) 