"""
Script to import NEW companies from Screener CSV - DAILY VERSION.

This script checks for NEW companies in the CSV and only imports those.
It does NOT re-process all existing companies.
Optimized for daily runs with daily logging.
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

# Set up logging for daily runs
log_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
logging.basicConfig(
    filename=f'log/import_companies_daily_{log_datetime}.log',
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

def normalize_value(val):
    if val is None:
        return None
    if isinstance(val, float) and math.isnan(val):
        return None
    sval = str(val).strip().lower()
    if sval in ('', 'nan', 'none'):
        return None
    return sval

def compare_and_update_company(db_company, csv_company_dict):
    changed = False
    updated_fields = []
    field_changes = []
    for field, new_value in csv_company_dict.items():
        if hasattr(db_company, field):
            old_value = getattr(db_company, field)
            if normalize_value(old_value) != normalize_value(new_value):
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
                'name': row.get('Company Name', row.get('company_name', '')),
                'nse_code': nse_code,
                'bse_code': bse_code,
                'industry': row.get('Industry', row.get('industry', '')),
                'last_modified': file_date
            }
            
            valid_companies.append(company_data)
        
        print(f"Valid companies to import: {len(valid_companies)}")
        logger.info(f"Valid companies to import: {len(valid_companies)}")
        
        # Import companies
        for i, company_data in enumerate(valid_companies, 1):
            try:
                # Check if company exists by unified codes
                existing_company = None
                if company_data['nse_code']:
                    existing_company = session.query(Company).filter(
                        Company.nse_code == company_data['nse_code']
                    ).first()
                
                if not existing_company and company_data['bse_code']:
                    existing_company = session.query(Company).filter(
                        Company.bse_code == company_data['bse_code']
                    ).first()
                
                if existing_company:
                    # Smart comparison and update
                    changed, updated_fields, field_changes = compare_and_update_company(existing_company, company_data)
                    
                    if changed:
                        session.add(existing_company)
                        quality_metrics['companies_updated'] += 1
                        logger.info(f"Updated existing company: {company_data['name']} - changed fields: {', '.join(updated_fields)}")
                        for field, old, new in field_changes:
                            logger.info(f"    {field}: '{old}' -> '{new}'")
                        print(f"{i}/{len(valid_companies)}: Updated {company_data['name']} - fields changed: {', '.join(updated_fields)}")
                        for field, old, new in field_changes:
                            print(f"    {field}: '{old}' -> '{new}'")
                    else:
                        quality_metrics['companies_no_changes'] += 1
                        logger.info(f"No changes for existing company: {company_data['name']} - data is current")
                else:
                    # Create new company
                    new_company = Company(**company_data)
                    session.add(new_company)
                    quality_metrics['companies_imported'] += 1
                    logger.info(f"Imported new company: {company_data['name']}")
                
                if i % 100 == 0:
                    session.commit()
                    print(f"Processed {i}/{len(valid_companies)} companies...")
                
            except Exception as e:
                quality_metrics['companies_errors'] += 1
                logger.error(f"Error processing {company_data['name']}: {e}")
                continue
        
        # Final commit
        session.commit()
        
        # Calculate final metrics
        quality_metrics['end_time'] = datetime.now()
        quality_metrics['duration'] = quality_metrics['end_time'] - quality_metrics['start_time']
        
        # Remove DQ summary print/logging
        # logger.info("=== COMPANIES IMPORT DATA QUALITY SUMMARY ===")
        # logger.info(f"Mode: daily update")
        # logger.info(f"CSV total rows: {quality_metrics['csv_total_rows']}")
        # logger.info(f"CSV valid rows: {quality_metrics['csv_valid_rows']}")
        # logger.info(f"CSV invalid rows: {quality_metrics['csv_invalid_rows']}")
        # logger.info(f"Companies imported: {quality_metrics['companies_imported']}")
        # logger.info(f"Companies updated: {quality_metrics['companies_updated']}")
        # logger.info(f"Companies with no changes: {quality_metrics['companies_no_changes']}")
        # logger.info(f"Companies errors: {quality_metrics['companies_errors']}")
        # logger.info(f"Database errors: {quality_metrics['database_errors']}")
        # logger.info(f"Processing duration: {quality_metrics['duration']}")
        # logger.info(f"Success rate: {(quality_metrics['companies_imported'] + quality_metrics['companies_updated']) / quality_metrics['csv_valid_rows'] * 100:.2f}%")
        
        print(f"\nImport Summary:")
        print(f"- Mode: daily update")
        print(f"- Total companies in CSV: {quality_metrics['csv_total_rows']}")
        print(f"- Valid companies: {quality_metrics['csv_valid_rows']}")
        print(f"- New companies imported: {quality_metrics['companies_imported']}")
        print(f"- Existing companies updated: {quality_metrics['companies_updated']}")
        print(f"- No changes needed: {quality_metrics['companies_no_changes']}")
        print(f"- Errors: {quality_metrics['companies_errors']}")
        print(f"- Success rate: {(quality_metrics['companies_imported'] + quality_metrics['companies_updated']) / quality_metrics['csv_valid_rows'] * 100:.2f}%")
        
        # Remove DQ analysis and reporting from import_companies_from_csv
        # (skip calls to analyze_companies_data_quality and related print/logging)
        
        logger.info(f"Import completed: {quality_metrics['companies_imported']} imported, {quality_metrics['companies_updated']} updated, {quality_metrics['companies_no_changes']} no changes, {quality_metrics['companies_errors']} errors")
        
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
    import_companies_from_csv(csv_file) 