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
            print(f"{count + skipped}/{total}: {company.name} skipped (already has price data).")
            continue
        
        ticker, exchange = get_yfinance_ticker(company)
        if ticker:
            company_ticker_map.append((company, ticker, exchange, company_code))
    
    # Batch processing
    for i in range(0, len(company_ticker_map), batch_size):
        batch = company_ticker_map[i:i+batch_size]
        tickers = [t[1] for t in batch]
        ticker_to_company = {t[1]: (t[0], t[2], t[3]) for t in batch}
        
        # Retry logic for the batch
        for attempt in range(3):
            try:
                df = yf.download(tickers, period="5y", interval="1d", group_by='ticker', progress=False, auto_adjust=False)
                break
            except Exception as e:
                print(f"Failed to fetch batch {tickers} (attempt {attempt+1}): {e}")
                time.sleep(10)
        time.sleep(1.5)
        
        all_keys = set()
        price_objects = []
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
                continue
            else:
                company.yf_not_found = 0
                company.exchange = exchange
                session.merge(company)
            
            for date, row in company_df.iterrows():
                key = (company_code, date.date())
                all_keys.add(key)
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
                
                price.open = get_scalar(row['Open']) if 'Open' in row else None
                price.high = get_scalar(row['High']) if 'High' in row else None
                price.low = get_scalar(row['Low']) if 'Low' in row else None
                price.close = get_scalar(row['Close']) if 'Close' in row else None
                price.volume = get_scalar(row['Volume']) if 'Volume' in row else None
                price.adj_close = get_scalar(row['Adj Close']) if 'Adj Close' in row else None
                
                # Only add if at least one price field is not None
                if any([
                    price.open is not None,
                    price.high is not None,
                    price.low is not None,
                    price.close is not None,
                    price.volume is not None
                ]):
                    price_objects.append(price)
            
            count += 1
            logger.info(f"{count + skipped}/{total}: {company.name} ({ticker}, {exchange}) done.")
            print(f"{count + skipped}/{total}: {company.name} ({ticker}, {exchange}) done.")
        
        if all_keys:
            existing_keys = set(
                session.query(Price.company_code, Price.date)
                .filter(tuple_(Price.company_code, Price.date).in_(list(all_keys)))
                .all()
            )
        else:
            existing_keys = set()
        new_prices = [p for p in price_objects if (p.company_code, p.date) not in existing_keys]
        if new_prices:
            session.bulk_save_objects(new_prices)
        session.commit()
    
    logger.info(f"Done. Prices updated for {count} companies.")
    session.close()

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'fetch':
        if len(sys.argv) > 2 and sys.argv[2].isdigit():
            fetch_and_store_prices(limit=int(sys.argv[2]))
        else:
            fetch_and_store_prices()
    else:
        fetch_and_store_prices() 