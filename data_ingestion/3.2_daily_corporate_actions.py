"""
Script to fetch and store latest corporate actions (last 3 days) for daily updates.

- Uses yfinance to fetch recent corporate actions (splits, dividends) for all companies.
- Updates the 'corporate_actions' table in the database.
- Only fetches last 3 days of data for daily runs.
- Uses unified company codes (NSE or BSE) for data operations.
"""

import sys
import os
import argparse
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

def fetch_and_store_latest_corporate_actions(limit=None, batch_size=100):
    """
    Fetch latest corporate actions (splits and dividends) for all companies.
    Uses smart comparison to only insert new actions.
    """
    session = Session()
    
    # Initialize quality metrics
    quality_metrics = {
        'start_time': datetime.now(),
        'total_companies': 0,
        'companies_with_valid_codes': 0,
        'companies_processed': 0,
        'companies_no_changes': 0,
        'companies_no_yf_data': 0,
        'companies_api_errors': 0,
        'total_splits': 0,
        'total_dividends': 0,
        'new_splits': 0,
        'new_dividends': 0,
        'duplicate_splits': 0,
        'duplicate_dividends': 0,
        'invalid_splits': 0,
        'invalid_dividends': 0,
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
    
    # Get date range for last 3 days
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=3)
    
    print(f"Fetching corporate actions for {total} companies (smart comparison)" + (f" (limited to {limit})" if limit else "") + f" from {start_date} to {end_date}...")
    logger.info(f"Fetching corporate actions for {total} companies (smart comparison)" + (f" (limited to {limit})" if limit else "") + f" from {start_date} to {end_date}")
    
    count = 0
    new_actions = 0
    
    for company in companies:
        ticker, exchange = get_yfinance_ticker(company)
        if not ticker:
            continue
        
        quality_metrics['companies_with_valid_codes'] += 1
        
        try:
            quality_metrics['api_calls'] += 1
            yf_ticker = yf.Ticker(ticker)
            splits = yf_ticker.splits
            dividends = yf_ticker.dividends
        except Exception as e:
            quality_metrics['api_errors'] += 1
            quality_metrics['companies_api_errors'] += 1
            logger.warning(f"Failed to fetch actions for {ticker}: {e}")
            continue
        
        company_code = company.nse_code if company.nse_code else company.bse_code
        action_objects = []
        all_keys = set()
        company_splits = 0
        company_dividends = 0
        company_invalid_splits = 0
        company_invalid_dividends = 0
        
        # Store splits (filter for last 3 days)
        if splits is not None and not splits.empty:
            for date, ratio in splits.items():
                if ratio is not None and ratio != 0:
                    # Data quality check: Validate split ratio
                    if ratio <= 0 or ratio > 1000:  # Reasonable range for splits
                        company_invalid_splits += 1
                        logger.warning(f"Invalid split ratio for {company.name} on {date}: {ratio}")
                        continue
                    
                    action_date = date.date() if hasattr(date, 'date') else date
                    if start_date <= action_date <= end_date:
                        key = (company_code, action_date, 'split')
                        all_keys.add(key)
                        company_splits += 1
                        action = CorporateAction(
                            company_code=company_code,
                            company_name=company.name,
                            date=action_date, 
                            type='split', 
                            details=f"{ratio}:1 split"
                        )
                        action_objects.append(action)
        
        # Store dividends (filter for last 3 days)
        if dividends is not None and not dividends.empty:
            for date, amount in dividends.items():
                if amount is not None and amount != 0:
                    # Data quality check: Validate dividend amount
                    if amount < 0 or amount > 10000:  # Reasonable range for dividends
                        company_invalid_dividends += 1
                        logger.warning(f"Invalid dividend amount for {company.name} on {date}: {amount}")
                        continue
                    
                    action_date = date.date() if hasattr(date, 'date') else date
                    if start_date <= action_date <= end_date:
                        key = (company_code, action_date, 'dividend')
                        all_keys.add(key)
                        company_dividends += 1
                        action = CorporateAction(
                            company_code=company_code,
                            company_name=company.name,
                            date=action_date, 
                            type='dividend', 
                            details=f"{amount} dividend"
                        )
                        action_objects.append(action)
        
        quality_metrics['total_splits'] += company_splits
        quality_metrics['total_dividends'] += company_dividends
        quality_metrics['invalid_splits'] += company_invalid_splits
        quality_metrics['invalid_dividends'] += company_invalid_dividends
        
        if not action_objects:
            quality_metrics['companies_no_yf_data'] += 1
        
        if all_keys:
            existing_keys = set(
                session.query(CorporateAction.company_code, CorporateAction.date, CorporateAction.type)
                .filter(tuple_(CorporateAction.company_code, CorporateAction.date, CorporateAction.type).in_(list(all_keys)))
                .all()
            )
        else:
            existing_keys = set()
        
        new_actions_batch = [a for a in action_objects if (a.company_code, a.date, a.type) not in existing_keys]
        duplicate_actions = len(action_objects) - len(new_actions_batch)
        
        # Count by type
        new_splits_count = len([a for a in new_actions_batch if a.type == 'split'])
        new_dividends_count = len([a for a in new_actions_batch if a.type == 'dividend'])
        quality_metrics['new_splits'] += new_splits_count
        quality_metrics['new_dividends'] += new_dividends_count
        quality_metrics['duplicate_splits'] += len([a for a in action_objects if a.type == 'split']) - new_splits_count
        quality_metrics['duplicate_dividends'] += len([a for a in action_objects if a.type == 'dividend']) - new_dividends_count
        
        if new_actions_batch:
            try:
                session.bulk_save_objects(new_actions_batch)
                session.commit()
                new_actions += len(new_actions_batch)
                logger.info(f"Updated {company.name} ({ticker}) - added {len(new_actions_batch)} new actions")
            except Exception as e:
                quality_metrics['database_errors'] += 1
                logger.error(f"Database error for {company.name}: {e}")
                session.rollback()
        else:
            quality_metrics['companies_no_changes'] += 1
            logger.info(f"No changes for {company.name} ({ticker}) - all actions already exist")
        
        count += 1
        quality_metrics['companies_processed'] += 1
        if count % 100 == 0:
            print(f"Processed {count}/{total} companies...")
        logger.info(f"Processed {count}/{total} companies. Added {len(new_actions_batch)} new actions.")
    
    # Calculate final metrics
    quality_metrics['end_time'] = datetime.now()
    quality_metrics['duration'] = quality_metrics['end_time'] - quality_metrics['start_time']
    
    # Log comprehensive data quality summary
    logger.info("=== DAILY CORPORATE ACTIONS DATA QUALITY SUMMARY ===")
    logger.info(f"Mode: smart comparison")
    logger.info(f"Date range: {start_date} to {end_date}")
    logger.info(f"Total companies: {quality_metrics['total_companies']}")
    logger.info(f"Companies with valid codes: {quality_metrics['companies_with_valid_codes']}")
    logger.info(f"Companies processed: {quality_metrics['companies_processed']}")
    logger.info(f"Companies with no changes: {quality_metrics['companies_no_changes']}")
    logger.info(f"Companies with no yfinance data: {quality_metrics['companies_no_yf_data']}")
    logger.info(f"Companies with API errors: {quality_metrics['companies_api_errors']}")
    logger.info(f"Total splits found: {quality_metrics['total_splits']}")
    logger.info(f"Total dividends found: {quality_metrics['total_dividends']}")
    logger.info(f"New splits inserted: {quality_metrics['new_splits']}")
    logger.info(f"New dividends inserted: {quality_metrics['new_dividends']}")
    logger.info(f"Duplicate splits (skipped): {quality_metrics['duplicate_splits']}")
    logger.info(f"Duplicate dividends (skipped): {quality_metrics['duplicate_dividends']}")
    logger.info(f"Invalid splits: {quality_metrics['invalid_splits']}")
    logger.info(f"Invalid dividends: {quality_metrics['invalid_dividends']}")
    logger.info(f"API calls made: {quality_metrics['api_calls']}")
    logger.info(f"API errors: {quality_metrics['api_errors']}")
    logger.info(f"Database errors: {quality_metrics['database_errors']}")
    logger.info(f"Processing duration: {quality_metrics['duration']}")
    logger.info(f"Success rate: {quality_metrics['companies_processed'] / quality_metrics['companies_with_valid_codes'] * 100:.2f}%")
    
    print(f"\nDaily Corporate Actions Summary:")
    print(f"- Mode: smart comparison")
    print(f"- Date range: {start_date} to {end_date}")
    print(f"- Total companies: {quality_metrics['total_companies']}")
    print(f"- Companies processed: {quality_metrics['companies_processed']}")
    print(f"- No changes needed: {quality_metrics['companies_no_changes']}")
    print(f"- New actions added: {new_actions}")
    print(f"- Success rate: {quality_metrics['companies_processed'] / quality_metrics['companies_with_valid_codes'] * 100:.2f}%")
    
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
    
    logger.info(f"Daily corporate actions completed: {quality_metrics['companies_processed']} processed, {new_actions} new actions, {quality_metrics['companies_no_changes']} no changes, {quality_metrics['companies_api_errors']} errors")
    
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