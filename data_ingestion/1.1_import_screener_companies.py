"""
Script to import companies from Screener CSV using unified codes.

This script imports companies from a Screener CSV file and handles
the mapping between unified codes and database IDs properly.
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

# Set up logging
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

def import_companies_from_csv(csv_file_path):
    """Import companies from CSV file using unified codes"""
    session = Session()
    
    try:
        # Read CSV file
        df = pd.read_csv(csv_file_path)
        print(f"Loaded {len(df)} companies from CSV")
        logger.info(f"Loaded {len(df)} companies from CSV")
        
        # Clean and validate data
        valid_companies = []
        for _, row in df.iterrows():
            nse_code = clean_code(row.get('NSE Code', row.get('nse_code')))
            bse_code = clean_code(row.get('BSE Code', row.get('bse_code')))
            
            # Skip if no valid codes
            if not nse_code and not bse_code:
                logger.warning(f"Skipping company with no valid codes: {row.get('Company Name', 'Unknown')}")
                continue
            
            company_data = {
                'name': row.get('Company Name', row.get('company_name', '')),
                'nse_code': nse_code,
                'bse_code': bse_code,
                'industry': row.get('Industry', row.get('industry', ''))
            }
            
            valid_companies.append(company_data)
        
        print(f"Valid companies to import: {len(valid_companies)}")
        logger.info(f"Valid companies to import: {len(valid_companies)}")
        
        # Import companies
        imported_count = 0
        updated_count = 0
        error_count = 0
        
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
                    # Update existing company
                    for key, value in company_data.items():
                        if value is not None:
                            setattr(existing_company, key, value)
                    session.merge(existing_company)
                    updated_count += 1
                    logger.info(f"Updated existing company: {company_data['name']}")
                else:
                    # Create new company
                    new_company = Company(**company_data)
                    session.add(new_company)
                    imported_count += 1
                    logger.info(f"Imported new company: {company_data['name']}")
                
                if i % 100 == 0:
                    session.commit()
                    print(f"Processed {i}/{len(valid_companies)} companies...")
                
            except Exception as e:
                error_count += 1
                logger.error(f"Error processing {company_data['name']}: {e}")
                continue
        
        # Final commit
        session.commit()
        
        print(f"\nImport Summary:")
        print(f"- Total companies in CSV: {len(df)}")
        print(f"- Valid companies: {len(valid_companies)}")
        print(f"- New companies imported: {imported_count}")
        print(f"- Existing companies updated: {updated_count}")
        print(f"- Errors: {error_count}")
        
        logger.info(f"Import completed: {imported_count} imported, {updated_count} updated, {error_count} errors")
        
    except Exception as e:
        session.rollback()
        logger.error(f"Import failed: {e}")
        raise
    finally:
        session.close()

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python3 1.1_import_screener_companies.py <csv_file_path>")
        print("Example: python3 1.1_import_screener_companies.py data_ingestion/screener_export_20250704.csv")
        sys.exit(1)
    
    csv_file_path = sys.argv[1]
    import_companies_from_csv(csv_file_path) 