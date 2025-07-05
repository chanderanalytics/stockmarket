"""
Script to fetch and store latest indices prices (last 3 days) for daily updates.

- Uses yfinance to fetch recent price data for major indices.
- Updates the 'index_prices' table in the database.
- Only fetches last 3 days of data for daily runs.
"""

import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import yfinance as yf
import pandas as pd
import math
from sqlalchemy import create_engine, tuple_
from sqlalchemy.orm import sessionmaker
from backend.models import Base, IndexPrice
from datetime import datetime, timedelta
import logging

# Set up logging
log_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
logging.basicConfig(
    filename=f'log/daily_indices_{log_datetime}.log',
    filemode='a',
    format='%(asctime)s %(levelname)s: %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

DATABASE_URL = 'postgresql://stockuser:stockpass@localhost:5432/stockdb'
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)

# List of major indices and their tickers
INDICES = [
    # India
    {"name": "Nifty 50", "ticker": "^NSEI", "region": "India", "description": "NSE main index"},
    {"name": "Nifty Bank", "ticker": "^NSEBANK", "region": "India", "description": "Nifty Bank index"},
    {"name": "Sensex", "ticker": "^BSESN", "region": "India", "description": "BSE main index"},
    {"name": "BSE 100", "ticker": "^BSE100", "region": "India", "description": "BSE 100 index"},
    {"name": "BSE 200", "ticker": "^BSE200", "region": "India", "description": "BSE 200 index"},
    {"name": "BSE Smallcap", "ticker": "^BSESMCAP", "region": "India", "description": "BSE Smallcap index"},
    {"name": "BSE Midcap", "ticker": "^BSE-MIDCAP", "region": "India", "description": "BSE Midcap index"},
    # US
    {"name": "S&P 500", "ticker": "^GSPC", "region": "USA", "description": "US large-cap index"},
    {"name": "Dow Jones", "ticker": "^DJI", "region": "USA", "description": "US blue-chip index"},
    {"name": "Nasdaq Composite", "ticker": "^IXIC", "region": "USA", "description": "US tech-heavy index"},
    {"name": "Russell 2000", "ticker": "^RUT", "region": "USA", "description": "US small-cap index"},
    # Europe
    {"name": "FTSE 100", "ticker": "^FTSE", "region": "UK", "description": "UK main index"},
    {"name": "DAX", "ticker": "^GDAXI", "region": "Germany", "description": "German main index"},
    {"name": "CAC 40", "ticker": "^FCHI", "region": "France", "description": "French main index"},
    {"name": "Euro Stoxx 50", "ticker": "^STOXX50E", "region": "Eurozone", "description": "Eurozone blue-chip index"},
    # Asia-Pacific
    {"name": "Nikkei 225", "ticker": "^N225", "region": "Japan", "description": "Japan main index"},
    {"name": "Hang Seng", "ticker": "^HSI", "region": "Hong Kong", "description": "Hong Kong main index"},
    {"name": "Shanghai Composite", "ticker": "000001.SS", "region": "China", "description": "China main index"},
    {"name": "KOSPI", "ticker": "^KS11", "region": "South Korea", "description": "South Korea main index"},
    {"name": "Straits Times", "ticker": "^STI", "region": "Singapore", "description": "Singapore main index"},
    {"name": "ASX 200", "ticker": "^AXJO", "region": "Australia", "description": "Australia main index"},
    # Global/ETF alternatives
    {"name": "MSCI World (ETF)", "ticker": "URTH", "region": "Global", "description": "iShares MSCI World ETF"},
    {"name": "MSCI Emerging Markets (ETF)", "ticker": "EEM", "region": "Global", "description": "iShares MSCI Emerging Markets ETF"},
    # Dollar Index
    {"name": "US Dollar Index", "ticker": "DX-Y.NYB", "region": "Global", "description": "US Dollar Index (DXY)"},
    # Commodities
    {"name": "Gold", "ticker": "GC=F", "region": "Commodities", "description": "Gold Futures (COMEX)"},
    {"name": "Silver", "ticker": "SI=F", "region": "Commodities", "description": "Silver Futures (COMEX)"},
    {"name": "Crude Oil (WTI)", "ticker": "CL=F", "region": "Commodities", "description": "WTI Crude Oil Futures"},
    {"name": "Crude Oil (Brent)", "ticker": "BZ=F", "region": "Commodities", "description": "Brent Crude Oil Futures"},
    {"name": "Natural Gas", "ticker": "NG=F", "region": "Commodities", "description": "Natural Gas Futures"},
    {"name": "Copper", "ticker": "HG=F", "region": "Commodities", "description": "Copper Futures"},
    {"name": "Platinum", "ticker": "PL=F", "region": "Commodities", "description": "Platinum Futures"},
    {"name": "Palladium", "ticker": "PA=F", "region": "Commodities", "description": "Palladium Futures"},
    {"name": "Corn", "ticker": "ZC=F", "region": "Commodities", "description": "Corn Futures"},
    {"name": "Soybeans", "ticker": "ZS=F", "region": "Commodities", "description": "Soybean Futures"},
    {"name": "Wheat", "ticker": "ZW=F", "region": "Commodities", "description": "Wheat Futures"},
]

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

def fetch_and_store_latest_indices_prices():
    session = Session()
    total_indices = len(INDICES)
    count = 0
    new_records = 0
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=3)
    logger.info(f"Fetching latest indices prices for {total_indices} indices from {start_date} to {end_date}")
    print(f"Fetching latest indices prices for {total_indices} indices from {start_date} to {end_date}")
    batch_prices = []
    all_keys = set()
    for idx in INDICES:
        logger.info(f"Fetching data for {idx['name']} ({idx['ticker']})...")
        try:
            df = yf.download(idx['ticker'], period="3d", interval="1d", progress=False, auto_adjust=False)
            if df is None or df.empty:
                logger.warning(f"No data for {idx['name']} ({idx['ticker']})")
                continue
            for date, row in df.iterrows():
                key = (idx['name'], idx['ticker'], date.date())
                all_keys.add(key)
                price = IndexPrice(
                    name=idx['name'],
                    ticker=idx['ticker'],
                    region=idx['region'],
                    description=idx['description'],
                    date=date.date(),
                    open=get_scalar(row['Open']) if 'Open' in row else None,
                    high=get_scalar(row['High']) if 'High' in row else None,
                    low=get_scalar(row['Low']) if 'Low' in row else None,
                    close=get_scalar(row['Close']) if 'Close' in row else None,
                    volume=get_scalar(row['Volume']) if 'Volume' in row else None
                )
                batch_prices.append(price)
        except Exception as e:
            logger.error(f"Failed to fetch/store data for {idx['name']} ({idx['ticker']}): {e}")
            print(f"Failed to fetch/store data for {idx['name']} ({idx['ticker']}): {e}")
    # Query all existing keys in one go
    if all_keys:
        existing_keys = set(
            session.query(IndexPrice.name, IndexPrice.ticker, IndexPrice.date)
            .filter(tuple_(IndexPrice.name, IndexPrice.ticker, IndexPrice.date).in_(list(all_keys)))
            .all()
        )
    else:
        existing_keys = set()
    new_prices = [p for p in batch_prices if (p.name, p.ticker, p.date) not in existing_keys]
    if new_prices:
        session.bulk_save_objects(new_prices)
        session.commit()
        logger.info(f"Added {len(new_prices)} new index prices.")
    session.close()
    logger.info(f"Done fetching indices prices. Processed {count} indices, added {new_records} new records.")
    print(f"Done fetching indices prices. Processed {count} indices, added {new_records} new records.")

if __name__ == "__main__":
    fetch_and_store_latest_indices_prices() 