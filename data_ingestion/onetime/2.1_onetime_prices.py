""" 
Script to fetch and store historical stock prices using unified codes.

- Uses yfinance to fetch price data for NSE/BSE companies.
- Updates the 'prices' table in the database using unified codes.
- Can check for missing yfinance data, fetch all prices, or fetch only the latest prices.
"""

import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import pandas as pd
import yfinance as yf
from sqlalchemy import create_engine, select, or_, and_, tuple_
from sqlalchemy.orm import sessionmaker
from backend.models import Base, Company, Price
from datetime import datetime
import time
import math
import logging
import re
import glob

DATABASE_URL = 'postgresql://stockuser:stockpass@localhost:5432/stockdb'
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)

# Set up logging
log_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
logging.basicConfig(
    filename=f'log/price_import_onetime_{log_datetime}.log',
    filemode='a',
    format='%(asctime)s %(levelname)s: %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

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

def fetch_and_store_prices(limit=None, batch_size=25):
    """
    Fetches historical daily prices for all companies using unified codes.
    """
    session = Session()
    
    # Data quality tracking
    quality_metrics = {
        'total_companies': 0,
        'companies_with_valid_codes': 0,
        'companies_skipped_already_have_data': 0,
        'companies_processed': 0,
        'companies_no_yf_data': 0,
        'companies_api_errors': 0,
        'total_price_records': 0,
        'new_price_records': 0,
        'duplicate_price_records': 0,
        'invalid_price_records': 0,
        'start_time': datetime.now(),
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
    print(f"Fetching prices for {total} companies in batches of {batch_size}...")
    count = 0
    skipped = 0
    
    # Prepare ticker-to-company mapping
    company_ticker_map = []
    for company in companies:
        # Get the preferred company code
        company_code = company.nse_code if company.nse_code else company.bse_code
        
        # Check if company already has price data
        if session.query(Price).filter_by(company_code=company_code).first():
            logger.info(f"Skipping {company.name} ({company_code}) - already has price data.")
            skipped += 1
            quality_metrics['companies_skipped_already_have_data'] += 1
            print(f"{count + skipped}/{total}: {company.name} skipped (already has price data).")
            continue
        
        ticker, exchange = get_yfinance_ticker(company)
        if ticker:
            company_ticker_map.append((company, ticker, exchange, company_code))
            quality_metrics['companies_with_valid_codes'] += 1
    
    # Batch processing
    for i in range(0, len(company_ticker_map), batch_size):
        batch = company_ticker_map[i:i+batch_size]
        tickers = [t[1] for t in batch]
        ticker_to_company = {t[1]: (t[0], t[2], t[3]) for t in batch}
        
        # Retry logic for the batch
        for attempt in range(3):
            try:
                quality_metrics['api_calls'] += 1
                df = yf.download(tickers, period="10y", interval="1d", group_by='ticker', progress=False, auto_adjust=False)
                break
            except Exception as e:
                quality_metrics['api_errors'] += 1
                print(f"Failed to fetch batch {tickers} (attempt {attempt+1}): {e}")
                logger.error(f"API error for batch {tickers} (attempt {attempt+1}): {e}")
                if attempt == 2:  # Last attempt
                    quality_metrics['companies_api_errors'] += len(batch)
                time.sleep(10)
        time.sleep(1.5)
        
        for ticker in tickers:
            company, exchange, company_code = ticker_to_company[ticker]
            
            # Get company data from yfinance
            if len(tickers) == 1:
                company_df = df
            else:
                if ticker in df.columns.get_level_values(0):
                    company_df = df[ticker]
                else:
                    company_df = pd.DataFrame()
            
            if company_df is None or company_df.empty:
                logger.warning(f"No data for {company.name} ({ticker})")
                company.yf_not_found = 1
                session.merge(company)
                quality_metrics['companies_no_yf_data'] += 1
                continue
            else:
                company.yf_not_found = 0
                company.exchange = exchange
                session.merge(company)
            
            price_objects = []
            all_keys = set()
            company_price_count = 0
            company_invalid_prices = 0
            
            # Assume csv_file is passed or set at the top
            match = re.search(r'(\d{8})', csv_file)
            if match:
                file_date = datetime.strptime(match.group(1), '%Y%m%d').date()
            else:
                raise ValueError("No date found in CSV filename!")
            
            for date, row in company_df.iterrows():
                key = (company_code, date.date())
                all_keys.add(key)
                company_price_count += 1
                
                def get_scalar(val):
                    if hasattr(val, 'item'):
                        try:
                            v = val.item()
                        except Exception:
                            v = float(val.values[0]) if hasattr(val, 'values') else float(val)
                    elif hasattr(val, '__float__'):
                        v = float(val)
                    else:
                        v = val
                    if v is not None and isinstance(v, float) and math.isnan(v):
                        return None
                    return v
                
                price = Price(company_code=company_code, date=date.date())
                price.company_name = company.name
                price.company_id = company.id  # Keep the foreign key for compatibility
                price.last_modified = file_date
                
                price.open = get_scalar(row['Open']) if 'Open' in row else None
                price.high = get_scalar(row['High']) if 'High' in row else None
                price.low = get_scalar(row['Low']) if 'Low' in row else None
                price.close = get_scalar(row['Close']) if 'Close' in row else None
                price.volume = get_scalar(row['Volume']) if 'Volume' in row else None
                price.adj_close = get_scalar(row['Adj Close']) if 'Adj Close' in row else None
                
                # Data quality check: Validate price data
                if price.close is not None and price.close <= 0:
                    company_invalid_prices += 1
                    logger.warning(f"Invalid close price for {company.name} on {date.date()}: {price.close}")
                
                if price.high is not None and price.low is not None and price.high < price.low:
                    company_invalid_prices += 1
                    logger.warning(f"High price less than low price for {company.name} on {date.date()}: High={price.high}, Low={price.low}")
                
                # Only add if at least one price field is not None
                if any([
                    price.open is not None,
                    price.high is not None,
                    price.low is not None,
                    price.close is not None,
                    price.volume is not None
                ]):
                    price_objects.append(price)
                else:
                    company_invalid_prices += 1
            
            quality_metrics['total_price_records'] += company_price_count
            quality_metrics['invalid_price_records'] += company_invalid_prices
            
            if all_keys:
                existing_keys = set(
                    session.query(Price.company_code, Price.date)
                    .filter(tuple_(Price.company_code, Price.date).in_(list(all_keys)))
                    .all()
                )
            else:
                existing_keys = set()
            
            new_prices = [p for p in price_objects if (p.company_code, p.date) not in existing_keys]
            quality_metrics['new_price_records'] += len(new_prices)
            quality_metrics['duplicate_price_records'] += len(price_objects) - len(new_prices)
            
            if new_prices:
                try:
                    session.bulk_save_objects(new_prices)
                    session.commit()
                except Exception as e:
                    quality_metrics['database_errors'] += 1
                    logger.error(f"Database error for {company.name}: {e}")
                    session.rollback()
            
            count += 1
            quality_metrics['companies_processed'] += 1
            logger.info(f"{count + skipped}/{total}: {company.name} ({ticker}, {exchange}) done. Added {len(new_prices)} new prices.")
            print(f"{count + skipped}/{total}: {company.name} ({ticker}, {exchange}) done.")
    
    # Calculate final metrics
    quality_metrics['end_time'] = datetime.now()
    quality_metrics['duration'] = quality_metrics['end_time'] - quality_metrics['start_time']
    
    # Log comprehensive data quality summary
    logger.info("=== DATA QUALITY SUMMARY ===")
    logger.info(f"Total companies: {quality_metrics['total_companies']}")
    logger.info(f"Companies with valid codes: {quality_metrics['companies_with_valid_codes']}")
    logger.info(f"Companies skipped (already have data): {quality_metrics['companies_skipped_already_have_data']}")
    logger.info(f"Companies processed: {quality_metrics['companies_processed']}")
    logger.info(f"Companies with no yfinance data: {quality_metrics['companies_no_yf_data']}")
    logger.info(f"Companies with API errors: {quality_metrics['companies_api_errors']}")
    logger.info(f"Total price records fetched: {quality_metrics['total_price_records']}")
    logger.info(f"New price records inserted: {quality_metrics['new_price_records']}")
    logger.info(f"Duplicate price records (skipped): {quality_metrics['duplicate_price_records']}")
    logger.info(f"Invalid price records: {quality_metrics['invalid_price_records']}")
    logger.info(f"API calls made: {quality_metrics['api_calls']}")
    logger.info(f"API errors: {quality_metrics['api_errors']}")
    logger.info(f"Database errors: {quality_metrics['database_errors']}")
    logger.info(f"Processing duration: {quality_metrics['duration']}")
    logger.info(f"Success rate: {quality_metrics['companies_processed'] / quality_metrics['companies_with_valid_codes'] * 100:.2f}%")
    
    # Analyze prices data quality
    print("Analyzing prices data quality...")
    logger.info("=== PRICES DATA QUALITY ANALYSIS ===")
    prices_quality = analyze_prices_data_quality(session)
    
    # Log prices data quality report
    logger.info(f"Total price records in database: {prices_quality['total_prices']}")
    logger.info("Prices column-level data quality:")
    for column, stats in prices_quality['columns'].items():
        logger.info(f"  {column}:")
        logger.info(f"    - Data type: {stats['data_type']}")
        logger.info(f"    - Non-null values: {stats['non_null_values']}/{stats['total_values']} ({stats['non_null_percentage']:.2f}%)")
        logger.info(f"    - Null values: {stats['null_values']}/{stats['total_values']} ({stats['null_percentage']:.2f}%)")
        logger.info(f"    - Unique values: {stats['unique_values']}")
    
    # Print summary to console
    print(f"\nPrices Data Quality Summary:")
    print(f"Total price records: {prices_quality['total_prices']}")
    print(f"Total columns: {len(prices_quality['columns'])}")
    print(f"\nPrices column completion rates:")
    for column, stats in prices_quality['columns'].items():
        print(f"  {column}: {stats['non_null_percentage']:.1f}% complete ({stats['non_null_values']}/{stats['total_values']})")
    
    logger.info(f"Done. Prices updated for {count} companies.")
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

def analyze_prices_data_quality(session):
    """Analyze data quality for all columns in the prices table"""
    quality_report = {
        'total_prices': 0,
        'columns': {}
    }
    
    # Get total count
    total_prices = session.query(Price).count()
    quality_report['total_prices'] = total_prices
    
    # Get column information from the model
    columns = Price.__table__.columns
    
    for column in columns:
        column_name = column.name
        
        # Count non-null values
        non_null_count = session.query(Price).filter(getattr(Price, column_name) != None).count()
        null_count = total_prices - non_null_count
        null_percentage = (null_count / total_prices) * 100 if total_prices > 0 else 0
        non_null_percentage = (non_null_count / total_prices) * 100 if total_prices > 0 else 0
        
        # Count unique values
        unique_count = session.query(getattr(Price, column_name)).distinct().count()
        
        quality_report['columns'][column_name] = {
            'total_values': total_prices,
            'non_null_values': non_null_count,
            'null_values': null_count,
            'null_percentage': null_percentage,
            'non_null_percentage': non_null_percentage,
            'unique_values': unique_count,
            'data_type': str(column.type)
        }
    
    return quality_report

def get_today_csv_file():
    today_str = datetime.now().strftime('%Y%m%d')
    expected_file = f'data_ingestion/screener_export_{today_str}.csv'
    if os.path.exists(expected_file):
        return expected_file
    else:
        raise FileNotFoundError(f"No screener_export_{today_str}.csv file found in data_ingestion folder.")

csv_file = get_today_csv_file()

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'fetch':
        if len(sys.argv) > 2 and sys.argv[2].isdigit():
            fetch_and_store_prices(limit=int(sys.argv[2]))
        else:
            fetch_and_store_prices()
    else:
        fetch_and_store_prices() 