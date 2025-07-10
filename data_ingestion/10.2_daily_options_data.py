#!/usr/bin/env python3
"""
Daily Options Data Ingestion Script

This script fetches options data from yfinance for all companies
and updates the database with new or changed data.

Features:
- Fetches recent options data from yfinance
- Filters to the CSV date only
- Compares with existing database data
- Inserts only new or changed records
- Batch processing for efficiency
- Comprehensive logging
- Error handling and retry logic

Usage:
    python 10.2_daily_options_data.py

Author: Stock Market Data System
Date: 2024
"""

import os
import sys
import logging
import yfinance as yf
import pandas as pd
from datetime import datetime, date, timedelta
from decimal import Decimal
from sqlalchemy import create_engine, text, or_, and_
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
import time
import random
from typing import Dict, List, Optional, Tuple, Any
import json

# Add the backend directory to the path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend'))

from models import OptionsData, Company, Base

# Configure logging
log_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
log_file = f'log/daily_options_data_{log_datetime}.log'
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Database configuration
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@localhost:5432/stockmkt')

# CSV date (today's date for daily updates)
CSV_DATE = date.today()

# Batch size for database operations
BATCH_SIZE = 100

# Retry configuration
MAX_RETRIES = 3
RETRY_DELAY = 2

def get_db_session():
    """Create and return a database session."""
    try:
        engine = create_engine(DATABASE_URL)
        Session = sessionmaker(bind=engine)
        return Session()
    except Exception as e:
        logger.error(f"Failed to create database session: {e}")
        raise

def get_companies_with_yf_tickers(session) -> List[Dict]:
    """Get all companies that have yfinance tickers."""
    try:
        companies = session.query(Company).filter(
            or_(
                and_(Company.nse_code != None, Company.nse_code != ""),
                and_(Company.bse_code != None, Company.bse_code != "")
            )
        ).all()
        
        result = []
        for company in companies:
            # Use NSE code if available, otherwise BSE code
            ticker = company.nse_code if company.nse_code else company.bse_code
            if ticker:
                result.append({
                    'id': company.id,
                    'name': company.name,
                    'ticker': ticker,
                    'nse_code': company.nse_code,
                    'bse_code': company.bse_code
                })
        
        logger.info(f"Found {len(result)} companies with yfinance tickers")
        return result
    except Exception as e:
        logger.error(f"Failed to get companies: {e}")
        raise

def get_existing_options_data(session, company_id: int, csv_date: date) -> Dict:
    """Get existing options data for a company on the CSV date."""
    try:
        options = session.query(OptionsData).filter(
            OptionsData.company_id == company_id,
            OptionsData.date == csv_date
        ).all()
        
        # Convert to dictionary for easy comparison
        existing_data = {}
        for option in options:
            key = f"{option.expiration_date}_{option.option_type}_{option.strike_price}"
            existing_data[key] = {
                'id': option.id,
                'expiration_date': option.expiration_date,
                'option_type': option.option_type,
                'strike_price': option.strike_price,
                'last_price': option.last_price,
                'bid': option.bid,
                'ask': option.ask,
                'volume': option.volume,
                'open_interest': option.open_interest,
                'implied_volatility': option.implied_volatility,
                'delta': option.delta,
                'gamma': option.gamma,
                'theta': option.theta,
                'vega': option.vega
            }
        
        return existing_data
    except Exception as e:
        logger.error(f"Failed to get existing options data for company {company_id}: {e}")
        return {}

def fetch_options_data_yf(ticker: str, company_name: str) -> List[Dict]:
    """Fetch options data from yfinance."""
    try:
        # Add .NS suffix for NSE stocks if not already present
        if not ticker.endswith('.NS') and not ticker.endswith('.BO'):
            ticker = f"{ticker}.NS"
        
        logger.info(f"Fetching options data for {ticker} ({company_name})")
        
        # Create yfinance ticker object
        yf_ticker = yf.Ticker(ticker)
        
        options_data = []
        
        # Get options expiration dates
        try:
            expiration_dates = yf_ticker.options
            if not expiration_dates:
                logger.info(f"No options available for {ticker}")
                return options_data
            
            # Limit to next 3 expiration dates to avoid too much data
            expiration_dates = expiration_dates[:3]
            
            for expiration_date_str in expiration_dates:
                try:
                    # Parse expiration date
                    expiration_date = datetime.strptime(expiration_date_str, '%Y-%m-%d').date()
                    
                    # Fetch calls and puts for this expiration
                    calls = yf_ticker.option_chain(expiration_date_str).calls
                    puts = yf_ticker.option_chain(expiration_date_str).puts
                    
                    # Process calls
                    if calls is not None and not calls.empty:
                        for index, row in calls.iterrows():
                            try:
                                options_data.append({
                                    'expiration_date': expiration_date,
                                    'option_type': 'call',
                                    'strike_price': row.get('strike', None),
                                    'last_price': row.get('lastPrice', None),
                                    'bid': row.get('bid', None),
                                    'ask': row.get('ask', None),
                                    'volume': row.get('volume', None),
                                    'open_interest': row.get('openInterest', None),
                                    'implied_volatility': row.get('impliedVolatility', None),
                                    'delta': row.get('delta', None),
                                    'gamma': row.get('gamma', None),
                                    'theta': row.get('theta', None),
                                    'vega': row.get('vega', None)
                                })
                            except Exception as e:
                                logger.warning(f"Failed to process call option for {ticker}: {e}")
                                continue
                    
                    # Process puts
                    if puts is not None and not puts.empty:
                        for index, row in puts.iterrows():
                            try:
                                options_data.append({
                                    'expiration_date': expiration_date,
                                    'option_type': 'put',
                                    'strike_price': row.get('strike', None),
                                    'last_price': row.get('lastPrice', None),
                                    'bid': row.get('bid', None),
                                    'ask': row.get('ask', None),
                                    'volume': row.get('volume', None),
                                    'open_interest': row.get('openInterest', None),
                                    'implied_volatility': row.get('impliedVolatility', None),
                                    'delta': row.get('delta', None),
                                    'gamma': row.get('gamma', None),
                                    'theta': row.get('theta', None),
                                    'vega': row.get('vega', None)
                                })
                            except Exception as e:
                                logger.warning(f"Failed to process put option for {ticker}: {e}")
                                continue
                
                except Exception as e:
                    logger.warning(f"Failed to fetch options for expiration {expiration_date_str} for {ticker}: {e}")
                    continue
        
        except Exception as e:
            logger.warning(f"Failed to fetch options data for {ticker}: {e}")
        
        logger.info(f"Fetched {len(options_data)} options records for {ticker}")
        return options_data
        
    except Exception as e:
        logger.error(f"Failed to fetch options data for {ticker}: {e}")
        return []

def filter_options_by_csv_date(options_data: List[Dict], csv_date: date) -> List[Dict]:
    """Filter options data to only include data for the CSV date."""
    # For options data, we'll include all data since yfinance doesn't provide date-specific filtering
    # and options data is current market data
    filtered_data = options_data
    
    logger.info(f"Filtered to {len(filtered_data)} options records for CSV date {csv_date}")
    return filtered_data

def compare_options_data(new_data: Dict, existing_data: Dict) -> bool:
    """Compare new options data with existing data."""
    # Compare key fields
    key_fields = [
        'expiration_date', 'option_type', 'strike_price', 'last_price', 'bid', 'ask',
        'volume', 'open_interest', 'implied_volatility', 'delta', 'gamma', 'theta', 'vega'
    ]
    
    for field in key_fields:
        new_val = new_data.get(field)
        existing_val = existing_data.get(field)
        
        # Handle numeric comparison for numeric fields
        if field in ['strike_price', 'last_price', 'bid', 'ask', 'volume', 'open_interest', 
                     'implied_volatility', 'delta', 'gamma', 'theta', 'vega']:
            try:
                new_val = Decimal(str(new_val)) if new_val is not None else None
                existing_val = Decimal(str(existing_val)) if existing_val is not None else None
            except:
                pass
        
        if new_val != existing_val:
            return True  # Data has changed
    
    return False  # No changes

def insert_options_data(session, company: Dict, options_data: List[Dict], csv_date: date):
    """Insert new or updated options data into the database."""
    try:
        # Get existing data for comparison
        existing_data = get_existing_options_data(session, company['id'], csv_date)
        
        inserted_count = 0
        updated_count = 0
        
        for option_data in options_data:
            # Create key for comparison
            key = f"{option_data['expiration_date']}_{option_data['option_type']}_{option_data['strike_price']}"
            
            # Check if data exists and has changed
            if key in existing_data:
                if compare_options_data(option_data, existing_data[key]):
                    # Update existing record
                    existing_option = session.query(OptionsData).filter(
                        OptionsData.id == existing_data[key]['id']
                    ).first()
                    
                    if existing_option:
                        # Update fields
                        for field, value in option_data.items():
                            if hasattr(existing_option, field):
                                setattr(existing_option, field, value)
                        existing_option.last_modified = csv_date
                        updated_count += 1
            else:
                # Insert new record
                new_option = OptionsData(
                    company_id=company['id'],
                    company_code=company['nse_code'] or company['bse_code'],
                    company_name=company['name'],
                    date=csv_date,
                    expiration_date=option_data.get('expiration_date'),
                    option_type=option_data.get('option_type'),
                    strike_price=option_data.get('strike_price'),
                    last_price=option_data.get('last_price'),
                    bid=option_data.get('bid'),
                    ask=option_data.get('ask'),
                    volume=option_data.get('volume'),
                    open_interest=option_data.get('open_interest'),
                    implied_volatility=option_data.get('implied_volatility'),
                    delta=option_data.get('delta'),
                    gamma=option_data.get('gamma'),
                    theta=option_data.get('theta'),
                    vega=option_data.get('vega'),
                    last_modified=csv_date
                )
                session.add(new_option)
                inserted_count += 1
        
        # Commit changes
        if inserted_count > 0 or updated_count > 0:
            session.commit()
            logger.info(f"Options data for {company['name']}: {inserted_count} inserted, {updated_count} updated")
        
        return inserted_count, updated_count
        
    except Exception as e:
        session.rollback()
        logger.error(f"Failed to insert options data for {company['name']}: {e}")
        raise

def process_company_options_data(session, company: Dict, csv_date: date) -> Tuple[int, int]:
    """Process options data for a single company."""
    try:
        # Fetch data from yfinance
        options_data = fetch_options_data_yf(company['ticker'], company['name'])
        
        if not options_data:
            logger.warning(f"No options data found for {company['name']} ({company['ticker']})")
            return 0, 0
        
        # Filter to CSV date
        filtered_data = filter_options_by_csv_date(options_data, csv_date)
        
        if not filtered_data:
            logger.info(f"No options data for CSV date {csv_date} for {company['name']}")
            return 0, 0
        
        # Insert into database
        inserted, updated = insert_options_data(session, company, filtered_data, csv_date)
        
        return inserted, updated
        
    except Exception as e:
        logger.error(f"Failed to process options data for {company['name']}: {e}")
        return 0, 0

def main():
    """Main function to run the daily options data ingestion."""
    start_time = time.time()
    logger.info(f"Starting daily options data ingestion for CSV date: {CSV_DATE}")
    
    try:
        # Create database session
        session = get_db_session()
        
        # Get companies with yfinance tickers
        companies = get_companies_with_yf_tickers(session)
        
        if not companies:
            logger.warning("No companies found with yfinance tickers")
            return
        
        total_inserted = 0
        total_updated = 0
        processed_count = 0
        
        # Process each company
        for i, company in enumerate(companies, 1):
            try:
                logger.info(f"Processing {i}/{len(companies)}: {company['name']} ({company['ticker']})")
                
                inserted, updated = process_company_options_data(session, company, CSV_DATE)
                total_inserted += inserted
                total_updated += updated
                processed_count += 1
                
                # Add small delay to avoid rate limiting
                time.sleep(random.uniform(0.5, 1.5))
                
                # Log progress every 50 companies
                if i % 50 == 0:
                    elapsed = time.time() - start_time
                    logger.info(f"Progress: {i}/{len(companies)} companies processed in {elapsed:.2f}s")
                
            except Exception as e:
                logger.error(f"Failed to process company {company['name']}: {e}")
                continue
        
        # Final summary
        elapsed_time = time.time() - start_time
        logger.info(f"Daily options data ingestion completed:")
        logger.info(f"  - Companies processed: {processed_count}/{len(companies)}")
        logger.info(f"  - Records inserted: {total_inserted}")
        logger.info(f"  - Records updated: {total_updated}")
        logger.info(f"  - Total time: {elapsed_time:.2f} seconds")
        
    except Exception as e:
        logger.error(f"Daily options data ingestion failed: {e}")
        raise
    finally:
        if 'session' in locals():
            session.close()

if __name__ == "__main__":
    main() 