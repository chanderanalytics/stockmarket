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
import argparse

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

def import_new_companies_from_csv(csv_file_path, limit=None):
    """Import ONLY NEW companies from CSV file - daily update mode"""
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
        
        # Apply limit if specified (for testing)
        if limit:
            df = df.head(limit)
            print(f"TEST MODE: Limited to first {limit} companies from CSV")
            logger.info(f"TEST MODE: Limited to first {limit} companies from CSV")
        
        quality_metrics['csv_total_rows'] = len(df)
        print(f"Loaded {len(df)} companies from CSV")
        logger.info(f"Loaded {len(df)} companies from CSV")
        
        # Get existing company codes from database
        existing_companies = session.query(Company).all()
        existing_nse_codes = {c.nse_code for c in existing_companies if c.nse_code}
        existing_bse_codes = {c.bse_code for c in existing_companies if c.bse_code}
        
        print(f"Found {len(existing_companies)} existing companies in database")
        logger.info(f"Found {len(existing_companies)} existing companies in database")
        
        # Clean and validate data, identify new companies
        new_companies = []
        updated_companies = []
        
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
                'industry': row.get('Industry', row.get('industry', ''))
            }
            
            # Check if this is a new company
            is_new = True
            if nse_code and nse_code in existing_nse_codes:
                is_new = False
            elif bse_code and bse_code in existing_bse_codes:
                is_new = False
            
            if is_new:
                new_companies.append(company_data)
            else:
                # Check for updates to existing companies
                existing_company = None
                if nse_code:
                    existing_company = session.query(Company).filter(
                        Company.nse_code == nse_code
                    ).first()
                
                if not existing_company and bse_code:
                    existing_company = session.query(Company).filter(
                        Company.bse_code == bse_code
                    ).first()
                
                if existing_company:
                    changed, updated_fields, field_changes = compare_and_update_company(existing_company, company_data)
                    if changed:
                        updated_companies.append((existing_company, updated_fields, field_changes))
        
        print(f"New companies to import: {len(new_companies)}")
        print(f"Existing companies with updates: {len(updated_companies)}")
        logger.info(f"New companies to import: {len(new_companies)}")
        logger.info(f"Existing companies with updates: {len(updated_companies)}")
        
        if len(new_companies) == 0 and len(updated_companies) == 0:
            print("No new companies or updates found. Daily import complete!")
            logger.info("No new companies or updates found. Daily import complete!")
            return
        
        # Import new companies
        for i, company_data in enumerate(new_companies, 1):
            try:
                new_company = Company(**company_data)
                session.add(new_company)
                quality_metrics['companies_imported'] += 1
                logger.info(f"Imported new company: {company_data['name']}")
                print(f"New {i}/{len(new_companies)}: Imported {company_data['name']}")
                
                if i % 50 == 0:
                    session.commit()
                    print(f"Imported {i}/{len(new_companies)} new companies...")
                
            except Exception as e:
                quality_metrics['companies_errors'] += 1
                logger.error(f"Error importing {company_data['name']}: {e}")
                continue
        
        # Update existing companies
        for i, (existing_company, updated_fields, field_changes) in enumerate(updated_companies, 1):
            try:
                session.add(existing_company)
                quality_metrics['companies_updated'] += 1
                logger.info(f"Updated existing company: {existing_company.name} - changed fields: {', '.join(updated_fields)}")
                print(f"Update {i}/{len(updated_companies)}: Updated {existing_company.name} - fields: {', '.join(updated_fields)}")
                
                if i % 50 == 0:
                    session.commit()
                    print(f"Updated {i}/{len(updated_companies)} existing companies...")
                
            except Exception as e:
                quality_metrics['companies_errors'] += 1
                logger.error(f"Error updating {existing_company.name}: {e}")
                continue
        
        # Final commit
        session.commit()
        
        # Calculate final metrics
        quality_metrics['end_time'] = datetime.now()
        quality_metrics['duration'] = quality_metrics['end_time'] - quality_metrics['start_time']
        
        # Log comprehensive data quality summary
        logger.info("=== DAILY COMPANIES IMPORT SUMMARY ===")
        logger.info(f"Mode: daily update (new companies only)")
        logger.info(f"CSV total rows: {quality_metrics['csv_total_rows']}")
        logger.info(f"CSV valid rows: {quality_metrics['csv_valid_rows']}")
        logger.info(f"CSV invalid rows: {quality_metrics['csv_invalid_rows']}")
        logger.info(f"New companies imported: {quality_metrics['companies_imported']}")
        logger.info(f"Existing companies updated: {quality_metrics['companies_updated']}")
        logger.info(f"Companies errors: {quality_metrics['companies_errors']}")
        logger.info(f"Processing duration: {quality_metrics['duration']}")
        
        print(f"\nDaily Import Summary:")
        print(f"- Mode: daily update (new companies only)")
        print(f"- Total companies in CSV: {quality_metrics['csv_total_rows']}")
        print(f"- Valid companies: {quality_metrics['csv_valid_rows']}")
        print(f"- New companies imported: {quality_metrics['companies_imported']}")
        print(f"- Existing companies updated: {quality_metrics['companies_updated']}")
        print(f"- Errors: {quality_metrics['companies_errors']}")
        print(f"- Duration: {quality_metrics['duration']}")
        
        logger.info(f"Daily import completed: {quality_metrics['companies_imported']} new, {quality_metrics['companies_updated']} updated, {quality_metrics['companies_errors']} errors")
        
    except Exception as e:
        quality_metrics['database_errors'] += 1
        logger.error(f"Import failed: {e}")
        session.rollback()
        raise
    finally:
        session.close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Import NEW companies from Screener CSV (daily version).')
    parser.add_argument('csv_file_path', help='Path to the Screener CSV file')
    parser.add_argument('--limit', type=int, help='Limit number of companies to process (for testing)')
    args = parser.parse_args()

    import_new_companies_from_csv(args.csv_file_path, limit=args.limit) 