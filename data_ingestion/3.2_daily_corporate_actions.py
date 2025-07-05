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

def fetch_and_store_latest_corporate_actions(limit=None, batch_size=100):
    session = Session()
    query = session.query(Company)
    if limit is not None:
        companies = query.limit(limit).all()
    else:
        companies = query.all()
    total = len(companies)
    count = 0
    new_actions = 0
    end_date = datetime.now().date()
    start_date = end_date - timedelta(days=3)
    logger.info(f"Fetching corporate actions for {total} companies from {start_date} to {end_date}")
    print(f"Fetching corporate actions for {total} companies from {start_date} to {end_date}")
    for i in range(0, len(companies), batch_size):
        batch = companies[i:i+batch_size]
        all_keys = set()
        action_objects = []
        for company in batch:
            ticker = None
            if is_valid_code(company.nse_code):
                ticker = f"{company.nse_code}.NS"
            elif is_valid_code(company.bse_code):
                bse_code_str = str(company.bse_code)
                if "." in bse_code_str:
                    bse_code_str = bse_code_str.split(".")[0]
                ticker = f"{bse_code_str}.BO"
            if not ticker:
                continue
            try:
                yf_ticker = yf.Ticker(ticker)
                splits = yf_ticker.splits
                dividends = yf_ticker.dividends
            except Exception as e:
                logger.warning(f"Failed to fetch actions for {ticker}: {e}")
                continue
            company_code = company.nse_code if company.nse_code else company.bse_code
            # Store splits (filter for last 3 days)
            if splits is not None and not splits.empty:
                for date, ratio in splits.items():
                    if ratio is not None and ratio != 0:
                        action_date = date.date() if hasattr(date, 'date') else date
                        if start_date <= action_date <= end_date:
                            key = (company_code, action_date, 'split')
                            all_keys.add(key)
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
                        action_date = date.date() if hasattr(date, 'date') else date
                        if start_date <= action_date <= end_date:
                            key = (company_code, action_date, 'dividend')
                            all_keys.add(key)
                            action = CorporateAction(
                                company_code=company_code,
                                company_name=company.name,
                                date=action_date, 
                                type='dividend', 
                                details=f"{amount} dividend"
                            )
                            action_objects.append(action)
        # Query all existing keys in one go
        if all_keys:
            existing_keys = set(
                session.query(CorporateAction.company_code, CorporateAction.date, CorporateAction.type)
                .filter(tuple_(CorporateAction.company_code, CorporateAction.date, CorporateAction.type).in_(list(all_keys)))
                .all()
            )
        else:
            existing_keys = set()
        new_actions_batch = [a for a in action_objects if (a.company_code, a.date, a.type) not in existing_keys]
        if new_actions_batch:
            session.bulk_save_objects(new_actions_batch)
            session.commit()
            new_actions += len(new_actions_batch)
        count += len(batch)
        if count % 100 == 0:
            print(f"Processed {count}/{total} companies...")
        logger.info(f"Processed {count}/{total} companies. Added {len(new_actions_batch)} new actions.")
    session.close()
    logger.info(f"Done fetching corporate actions. Processed {count} companies, added {new_actions} new actions.")
    print(f"Done fetching corporate actions. Processed {count} companies, added {new_actions} new actions.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Fetch and store latest corporate actions for companies.')
    parser.add_argument('--limit', type=int, default=None, help='Limit number of companies to process')
    args = parser.parse_args()
    fetch_and_store_latest_corporate_actions(limit=args.limit) 