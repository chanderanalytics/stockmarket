"""
Script to fetch latest stock prices using unified codes.

- Uses yfinance to fetch recent price data for all companies.
- Updates the 'prices' table in the database using unified codes.
- Only fetches last 3 days of data for daily updates.
"""

import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import pandas as pd
import yfinance as yf
from sqlalchemy import create_engine, tuple_
from sqlalchemy.orm import sessionmaker
from backend.models import Base, Company, Price
from datetime import datetime
import time
import math
import logging

# Set up logging
log_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
logging.basicConfig(
    filename=f'log/daily_prices_{log_datetime}.log',
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

def get_scalar(val):
    if val is None:
        return None
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

def fetch_latest_prices(limit=None, batch_size=25):
    session = Session()
    query = session.query(Company).filter((Company.nse_code != None) | (Company.bse_code != None))
    if limit is not None:
        companies = query.limit(limit).all()
    else:
        companies = query.all()
    
    total = len(companies)
    logger.info(f"Fetching latest prices for {total} companies in batches of {batch_size}...")
    print(f"Fetching latest prices for {total} companies in batches of {batch_size}...")
    count = 0
    no_data_count = 0
    company_ticker_map = []
    
    for company in companies:
        company_code = company.nse_code if company.nse_code else company.bse_code
        ticker, exchange = get_yfinance_ticker(company)
        if ticker:
            company_ticker_map.append((company, ticker, exchange, company_code))
    
    for i in range(0, len(company_ticker_map), batch_size):
        batch = company_ticker_map[i:i+batch_size]
        tickers = [t[1] for t in batch]
        ticker_to_company = {t[1]: (t[0], t[2], t[3]) for t in batch}
        
        # Retry logic for the batch
        for attempt in range(3):
            try:
                df = yf.download(tickers, period="3d", interval="1d", group_by='ticker', auto_adjust=False, progress=False)
                if not df.empty:
                    found = True
                break
            except Exception as e:
                print(f"Failed to fetch batch {tickers} (attempt {attempt+1}): {e}")
                logger.error(f"Failed to fetch batch {tickers} (attempt {attempt+1}): {e}")
                time.sleep(10)
        time.sleep(1.5)
        
        # --- Optimization: Batch existence check ---
        all_keys = set()
        price_objects = []
        batch_no_data = 0
        for ticker in tickers:
            company, exchange, company_code = ticker_to_company[ticker]
            if len(tickers) == 1:
                company_df = df
            else:
                if ticker in df.columns.get_level_values(0):
                    company_df = df[ticker]
                else:
                    company_df = pd.DataFrame()
            if company_df is None or company_df.empty:
                msg = f"No data for {company.name} ({ticker})"
                print(msg)
                logger.warning(msg)
                company.yf_not_found = 1
                session.merge(company)
                session.commit()
                batch_no_data += 1
                continue
            else:
                company.yf_not_found = 0
                session.merge(company)
                session.commit()
            for date, row in company_df.iterrows():
                key = (company_code, date.date())
                all_keys.add(key)
                price = Price(company_code=company_code, date=date.date())
                price.company_name = company.name
                price.company_id = company.id
                price.open = get_scalar(row['Open'])
                price.high = get_scalar(row['High'])
                price.low = get_scalar(row['Low'])
                price.close = get_scalar(row['Close'])
                price.volume = get_scalar(row['Volume'])
                price.adj_close = get_scalar(row['Adj Close']) if 'Adj Close' in row else None
                if any([
                    price.open is not None,
                    price.high is not None,
                    price.low is not None,
                    price.close is not None,
                    price.volume is not None
                ]):
                    price_objects.append(price)
        # Query all existing keys in one go
        if all_keys:
            existing_keys = set(
                session.query(Price.company_code, Price.date)
                .filter(tuple_(Price.company_code, Price.date).in_(list(all_keys)))
                .all()
            )
        else:
            existing_keys = set()
        # Only keep new ones
        new_prices = [p for p in price_objects if (p.company_code, p.date) not in existing_keys]
        # Bulk insert
        if new_prices:
            session.bulk_save_objects(new_prices)
            session.commit()
            count += len(new_prices)
        msg = f"{count}/{total}: Batch {i//batch_size+1} done. Added {len(new_prices)} new prices."
        print(msg)
        logger.info(msg)
        no_data_count += batch_no_data
    logger.info(f"Done. Latest prices updated for {count} companies.")
    print(f"Done. Latest prices updated for {count} companies.")
    logger.info(f"Summary: {count} companies had new data, {no_data_count} companies had no new data.")
    print(f"Summary: {count} companies had new data, {no_data_count} companies had no new data.")
    session.close()

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Fetch latest prices for all companies using unified codes.')
    parser.add_argument('--limit', type=int, default=None, help='Limit number of companies to process')
    parser.add_argument('--batch-size', type=int, default=25, help='Batch size for yfinance requests')
    args = parser.parse_args()
    fetch_latest_prices(limit=args.limit, batch_size=args.batch_size) 