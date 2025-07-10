"""
Script to fetch and store corporate actions for the specific date from CSV file.

- Uses yfinance to fetch corporate actions (splits, dividends) for the CSV date only.
- Compares with existing table data and only inserts if there are changes.
- Uses batch processing and bulk commits for efficiency.
- Only processes companies that have changes.
"""

import sys
import os
import argparse
import re
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import yfinance as yf
from sqlalchemy import create_engine, tuple_
from sqlalchemy.orm import sessionmaker
from backend.models import Base, Company, CorporateAction
from datetime import datetime, timedelta
import math
import logging
from sqlalchemy import or_, and_

# Set up logging
log_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
logging.basicConfig(
    filename=f'log/daily_corporate_actions_{log_datetime}.log',
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

def get_yfinance_ticker(company):
    """Get yfinance ticker for a company"""
    if is_valid_code(company.nse_code):
        return f"{company.nse_code}.NS", 'NSE'
    elif is_valid_code(company.bse_code):
        bse_code_str = str(company.bse_code)
        if "." in bse_code_str:
            bse_code_str = bse_code_str.split(".")[0]
        return f"{bse_code_str}.BO", 'BSE'
    return None, None

def get_today_csv_file():
    today_str = datetime.now().strftime('%Y%m%d')
    expected_file = f'data_ingestion/screener_export_{today_str}.csv'
    if os.path.exists(expected_file):
        return expected_file
    else:
        raise FileNotFoundError(f"No screener_export_{today_str}.csv file found in data_ingestion folder.")

csv_file = get_today_csv_file()

def fetch_and_store_latest_corporate_actions(limit=None, batch_size=100):
    """
    Fetch corporate actions for the CSV date only and compare with existing data.
    Uses smart comparison to only insert new actions.
    """
    session = Session()
    
    # Extract file_date from csv_file
    match = re.search(r'(\d{8})', csv_file)
    if match:
        file_date = datetime.strptime(match.group(1), '%Y%m%d').date()
    else:
        raise ValueError("No date found in CSV filename!")
    
    # Initialize quality metrics
    quality_metrics = {
        'start_time': datetime.now(),
        'total_companies': 0,
        'companies_with_valid_codes': 0,
        'companies_processed': 0,
        'companies_no_changes': 0,
        'companies_with_changes': 0,
        'companies_api_errors': 0,
        'new_splits': 0,
        'new_dividends': 0,
        'api_calls': 0,
        'api_errors': 0,
        'database_errors': 0
    }
    
    # Get companies with valid codes
    query = session.query(Company).filter(
        or_(
            and_(Company.nse_code != None, Company.nse_code != ""),
            and_(Company.bse_code != None, Company.bse_code != "")
        )
    )
    if limit is not None:
        companies = query.limit(limit).all()
    else:
        companies = query.all()
    
    quality_metrics['total_companies'] = len(companies)
    total = len(companies)
    
    print(f"Fetching corporate actions for {total} companies (smart comparison) for date {file_date}...")
    logger.info(f"Fetching corporate actions for {total} companies (smart comparison) for date {file_date}")
    
    # Get existing corporate actions for the previous day to compare against
    previous_date = file_date - timedelta(days=1)
    existing_actions = {}
    existing_query = session.query(CorporateAction).filter(
        CorporateAction.date == previous_date
    ).all()
    
    for action in existing_query:
        key = (action.company_code, action.type)  # Compare by company_code and type, not date
        existing_actions[key] = action
    
    print(f"Found {len(existing_actions)} existing corporate actions for {previous_date} (comparison baseline)")
    print(f"Will fetch new corporate actions for {file_date} and compare with {previous_date} baseline")
    
    # Batch processing
    all_actions_to_add = []
    all_actions_to_update = []
    processed_count = 0
    
    for company in companies:
        ticker, exchange = get_yfinance_ticker(company)
        if not ticker:
            continue
        
        quality_metrics['companies_with_valid_codes'] += 1
        
        try:
            quality_metrics['api_calls'] += 1
            yf_ticker = yf.Ticker(ticker)
            
            # Fetch data specifically for the CSV date only
            # Use start and end dates to get only the data we need
            start_date = file_date
            end_date = file_date + timedelta(days=1)
            
            # Fetch splits and dividends for the specific date range
            # This is much more efficient than fetching all historical data
            splits = yf_ticker.splits
            dividends = yf_ticker.dividends
            
            # Filter to only the file_date
            file_date_splits = {}
            file_date_dividends = {}
            
            if splits is not None and not splits.empty:
                # Check if there are any splits on the exact CSV date
                for date, ratio in splits.items():
                    if date.date() == file_date and ratio is not None and ratio != 0:
                        if ratio <= 0 or ratio > 1000:
                            logger.warning(f"Invalid split ratio for {company.name} on {date}: {ratio}")
                            continue
                        file_date_splits[date] = ratio
            
            if dividends is not None and not dividends.empty:
                # Check if there are any dividends on the exact CSV date
                for date, amount in dividends.items():
                    if date.date() == file_date and amount is not None and amount != 0:
                        if amount < 0 or amount > 10000:
                            logger.warning(f"Invalid dividend amount for {company.name} on {date}: {amount}")
                            continue
                        file_date_dividends[date] = amount
                        
        except Exception as e:
            quality_metrics['api_errors'] += 1
            quality_metrics['companies_api_errors'] += 1
            logger.warning(f"Failed to fetch actions for {ticker}: {e}")
            continue
        
        company_code = company.nse_code if company.nse_code else company.bse_code
        company_has_changes = False
        
        # Process splits for the file_date only
        for date, ratio in file_date_splits.items():
            action_date = date.date() if hasattr(date, 'date') else date
            details = f"{ratio}:1 split"
            key = (company_code, 'split')  # Compare by company_code and type
            
            # Check if this company already had a split action on the previous day
            if key in existing_actions:
                # Company already had a split action on previous day, check if it's different
                existing = existing_actions[key]
                if existing.details != details:
                    # Different split details, add new action for current date
                    new_action = CorporateAction(
                        company_code=company_code,
                        company_name=company.name,
                        date=action_date,
                        type='split',
                        details=details,
                        last_modified=file_date
                    )
                    all_actions_to_add.append(new_action)
                    quality_metrics['new_splits'] += 1
                    company_has_changes = True
                    logger.info(f"New split for {company_code} on {action_date}: {details} (different from {previous_date})")
            else:
                # Company didn't have a split action on previous day, this is new
                new_action = CorporateAction(
                    company_code=company_code,
                    company_name=company.name,
                    date=action_date,
                    type='split',
                    details=details,
                    last_modified=file_date
                )
                all_actions_to_add.append(new_action)
                quality_metrics['new_splits'] += 1
                company_has_changes = True
                logger.info(f"New split for {company_code} on {action_date}: {details} (new action)")
        
        # Process dividends for the file_date only
        for date, amount in file_date_dividends.items():
            action_date = date.date() if hasattr(date, 'date') else date
            details = f"{amount} dividend"
            key = (company_code, 'dividend')  # Compare by company_code and type
            
            # Check if this company already had a dividend action on the previous day
            if key in existing_actions:
                # Company already had a dividend action on previous day, check if it's different
                existing = existing_actions[key]
                if existing.details != details:
                    # Different dividend details, add new action for current date
                    new_action = CorporateAction(
                        company_code=company_code,
                        company_name=company.name,
                        date=action_date,
                        type='dividend',
                        details=details,
                        last_modified=file_date
                    )
                    all_actions_to_add.append(new_action)
                    quality_metrics['new_dividends'] += 1
                    company_has_changes = True
                    logger.info(f"New dividend for {company_code} on {action_date}: {details} (different from {previous_date})")
            else:
                # Company didn't have a dividend action on previous day, this is new
                new_action = CorporateAction(
                    company_code=company_code,
                    company_name=company.name,
                    date=action_date,
                    type='dividend',
                    details=details,
                    last_modified=file_date
                )
                all_actions_to_add.append(new_action)
                quality_metrics['new_dividends'] += 1
                company_has_changes = True
                logger.info(f"New dividend for {company_code} on {action_date}: {details} (new action)")
        
        processed_count += 1
        quality_metrics['companies_processed'] += 1
        
        if company_has_changes:
            quality_metrics['companies_with_changes'] += 1
        else:
            quality_metrics['companies_no_changes'] += 1
        
        # Progress logging every 100 companies
        if processed_count % 100 == 0:
            print(f"Processed {processed_count}/{total} companies...")
            logger.info(f"Processed {processed_count}/{total} companies. Added {len(all_actions_to_add)} new actions, updated {len(all_actions_to_update)} actions.")
    
    # Bulk operations - commit all changes at once
    print(f"\nPerforming bulk operations...")
    print(f"New actions to add: {len(all_actions_to_add)}")
    
    try:
        # Bulk insert new actions
        if all_actions_to_add:
            session.bulk_save_objects(all_actions_to_add)
            print(f"Bulk inserted {len(all_actions_to_add)} new corporate actions")
        
        # Commit all changes at once
        if all_actions_to_add:
            session.commit()
            print(f"Committed all changes successfully")
        else:
            print("No changes to commit")
            
    except Exception as e:
        session.rollback()
        quality_metrics['database_errors'] += 1
        logger.error(f"Database error during bulk operations: {e}")
        print(f"Database error: {e}")
        raise
    
    # Calculate final metrics
    quality_metrics['end_time'] = datetime.now()
    quality_metrics['duration'] = quality_metrics['end_time'] - quality_metrics['start_time']
    
    # Log comprehensive data quality summary
    logger.info("=== DAILY CORPORATE ACTIONS DATA QUALITY SUMMARY ===")
    logger.info(f"Mode: smart comparison for date {file_date}")
    logger.info(f"Total companies: {quality_metrics['total_companies']}")
    logger.info(f"Companies with valid codes: {quality_metrics['companies_with_valid_codes']}")
    logger.info(f"Companies processed: {quality_metrics['companies_processed']}")
    logger.info(f"Companies with changes: {quality_metrics['companies_with_changes']}")
    logger.info(f"Companies with no changes: {quality_metrics['companies_no_changes']}")
    logger.info(f"Companies with API errors: {quality_metrics['companies_api_errors']}")
    logger.info(f"New splits inserted: {quality_metrics['new_splits']}")
    logger.info(f"New dividends inserted: {quality_metrics['new_dividends']}")
    logger.info(f"API calls made: {quality_metrics['api_calls']}")
    logger.info(f"API errors: {quality_metrics['api_errors']}")
    logger.info(f"Database errors: {quality_metrics['database_errors']}")
    logger.info(f"Processing duration: {quality_metrics['duration']}")
    logger.info(f"Success rate: {quality_metrics['companies_processed'] / quality_metrics['companies_with_valid_codes'] * 100:.2f}%")
    
    # Update summary print/log
    print(f"\nDaily Corporate Actions Summary:")
    print(f"- Mode: compare {file_date} yfinance data with {previous_date} database baseline")
    print(f"- Total companies: {quality_metrics['total_companies']}")
    print(f"- Companies processed: {quality_metrics['companies_processed']}")
    print(f"- Companies with new actions: {quality_metrics['companies_with_changes']}")
    print(f"- Companies with no changes: {quality_metrics['companies_no_changes']}")
    print(f"- New actions added: {quality_metrics['new_splits'] + quality_metrics['new_dividends']}")
    print(f"- Success rate: {quality_metrics['companies_processed'] / quality_metrics['companies_with_valid_codes'] * 100:.2f}%")
    print(f"- Processing time: {quality_metrics['duration']}")
    print("(See log for details on new actions and companies with no changes)")
    
    # Analyze corporate actions data quality
    print("Analyzing corporate actions data quality...")
    logger.info("=== CORPORATE ACTIONS DATA QUALITY ANALYSIS ===")
    ca_quality = analyze_corporate_actions_data_quality(session)
    
    # Log corporate actions data quality report
    logger.info(f"Total corporate actions in database: {ca_quality['total_actions']}")
    logger.info("Corporate actions column-level data quality:")
    for column, stats in ca_quality['columns'].items():
        logger.info(f"  {column}:")
        logger.info(f"    - Data type: {stats['data_type']}")
        logger.info(f"    - Non-null values: {stats['non_null_values']}/{stats['total_values']} ({stats['non_null_percentage']:.2f}%)")
        logger.info(f"    - Null values: {stats['null_values']}/{stats['total_values']} ({stats['null_percentage']:.2f}%)")
        logger.info(f"    - Unique values: {stats['unique_values']}")
    
    # Print summary to console
    print(f"\nCorporate Actions Data Quality Summary:")
    print(f"Total corporate actions: {ca_quality['total_actions']}")
    print(f"Total columns: {len(ca_quality['columns'])}")
    print(f"\nCorporate actions column completion rates:")
    for column, stats in ca_quality['columns'].items():
        print(f"  {column}: {stats['non_null_percentage']:.1f}% complete ({stats['non_null_values']}/{stats['total_values']})")
    
    logger.info(f"Daily corporate actions completed: {quality_metrics['companies_processed']} processed, {quality_metrics['companies_with_changes']} with changes, {quality_metrics['companies_no_changes']} no changes, {quality_metrics['companies_api_errors']} errors")
    
    session.close()

def clean_numeric_value(value):
    """Clean and convert numeric values"""
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

def analyze_corporate_actions_data_quality(session):
    """Analyze data quality for all columns in the corporate_actions table"""
    quality_report = {
        'total_actions': 0,
        'columns': {}
    }
    
    # Get total count
    total_actions = session.query(CorporateAction).count()
    quality_report['total_actions'] = total_actions
    
    # Get column information from the model
    columns = CorporateAction.__table__.columns
    
    for column in columns:
        column_name = column.name
        
        # Count non-null values
        non_null_count = session.query(CorporateAction).filter(getattr(CorporateAction, column_name) != None).count()
        null_count = total_actions - non_null_count
        null_percentage = (null_count / total_actions) * 100 if total_actions > 0 else 0
        non_null_percentage = (non_null_count / total_actions) * 100 if total_actions > 0 else 0
        
        # Count unique values
        unique_count = session.query(getattr(CorporateAction, column_name)).distinct().count()
        
        quality_report['columns'][column_name] = {
            'total_values': total_actions,
            'non_null_values': non_null_count,
            'null_values': null_count,
            'null_percentage': null_percentage,
            'non_null_percentage': non_null_percentage,
            'unique_values': unique_count,
            'data_type': str(column.type)
        }
    
    return quality_report

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Fetch and store latest corporate actions for companies.')
    parser.add_argument('--limit', type=int, default=None, help='Limit number of companies to process')
    args = parser.parse_args()
    fetch_and_store_latest_corporate_actions(limit=args.limit) 