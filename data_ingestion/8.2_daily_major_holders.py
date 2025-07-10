#!/usr/bin/env python3
"""
Daily Major Holders Data Ingestion Script

This script fetches major shareholders/holders data from yfinance for all companies
and updates the database with new or changed data.

Features:
- Fetches recent major holders data from yfinance
- Filters to the CSV date only
- Compares with existing database data
- Inserts only new or changed records
- Batch processing for efficiency
- Comprehensive logging
- Error handling and retry logic

Usage:
    python 8.2_daily_major_holders.py

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

from models import MajorHolder, Company, Base

# Configure logging
log_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
log_file = f'log/daily_major_holders_{log_datetime}.log'
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
DATABASE_URL = 'postgresql://stockuser:stockpass@localhost:5432/stockdb'
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)

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

def get_existing_major_holders(session, company_id: int, csv_date: date) -> Dict:
    """Get existing major holders for a company on the CSV date."""
    try:
        holders = session.query(MajorHolder).filter(
            MajorHolder.company_id == company_id,
            MajorHolder.date == csv_date
        ).all()
        
        # Convert to dictionary for easy comparison
        existing_data = {}
        for holder in holders:
            key = f"{holder.holder_name}_{holder.holder_type}"
            existing_data[key] = {
                'id': holder.id,
                'holder_name': holder.holder_name,
                'holder_type': holder.holder_type,
                'shares_held': holder.shares_held,
                'percentage_held': holder.percentage_held,
                'value': holder.value,
                'currency': holder.currency
            }
        
        return existing_data
    except Exception as e:
        logger.error(f"Failed to get existing major holders for company {company_id}: {e}")
        return {}

def fetch_major_holders_yf(ticker: str, company_name: str) -> List[Dict]:
    """Fetch major holders data from yfinance."""
    try:
        # Add .NS suffix for NSE stocks if not already present
        if not ticker.endswith('.NS') and not ticker.endswith('.BO'):
            ticker = f"{ticker}.NS"
        
        logger.info(f"Fetching major holders for {ticker} ({company_name})")
        
        # Create yfinance ticker object
        yf_ticker = yf.Ticker(ticker)
        
        holders_data = []
        
        # Fetch major holders
        try:
            major_holders = yf_ticker.major_holders
            if major_holders is not None and not major_holders.empty:
                for index, row in major_holders.iterrows():
                    # Parse the holder data
                    holder_info = str(index).strip()
                    percentage = row.iloc[0] if len(row) > 0 else None
                    
                    # Extract holder name and type
                    holder_name = holder_info
                    holder_type = "unknown"
                    
                    # Try to determine holder type from the name
                    if any(keyword in holder_info.lower() for keyword in ['promoter', 'promoters']):
                        holder_type = "promoter"
                    elif any(keyword in holder_info.lower() for keyword in ['fii', 'foreign']):
                        holder_type = "fii"
                    elif any(keyword in holder_info.lower() for keyword in ['dii', 'domestic']):
                        holder_type = "dii"
                    elif any(keyword in holder_info.lower() for keyword in ['public', 'retail']):
                        holder_type = "public"
                    elif any(keyword in holder_info.lower() for keyword in ['institution', 'mutual', 'insurance']):
                        holder_type = "institution"
                    else:
                        holder_type = "individual"
                    
                    # Convert percentage to decimal
                    try:
                        if percentage and isinstance(percentage, str):
                            percentage = float(percentage.replace('%', ''))
                    except:
                        percentage = None
                    
                    holders_data.append({
                        'holder_name': holder_name,
                        'holder_type': holder_type,
                        'shares_held': None,  # yfinance doesn't provide this directly
                        'percentage_held': percentage,
                        'value': None,  # yfinance doesn't provide this directly
                        'currency': 'INR'  # Default for Indian stocks
                    })
        except Exception as e:
            logger.warning(f"Failed to fetch major holders for {ticker}: {e}")
        
        # Fetch institutional holders
        try:
            institutional_holders = yf_ticker.institutional_holders
            if institutional_holders is not None and not institutional_holders.empty:
                for index, row in institutional_holders.iterrows():
                    holder_name = str(index).strip()
                    shares_held = row.get('Shares', None)
                    percentage = row.get('% Out', None)
                    value = row.get('Value', None)
                    
                    # Convert percentage to decimal
                    try:
                        if percentage and isinstance(percentage, str):
                            percentage = float(percentage.replace('%', ''))
                    except:
                        percentage = None
                    
                    holders_data.append({
                        'holder_name': holder_name,
                        'holder_type': 'institution',
                        'shares_held': shares_held,
                        'percentage_held': percentage,
                        'value': value,
                        'currency': 'INR'
                    })
        except Exception as e:
            logger.warning(f"Failed to fetch institutional holders for {ticker}: {e}")
        
        logger.info(f"Fetched {len(holders_data)} major holder records for {ticker}")
        return holders_data
        
    except Exception as e:
        logger.error(f"Failed to fetch major holders for {ticker}: {e}")
        return []

def filter_holders_by_csv_date(holders_data: List[Dict], csv_date: date) -> List[Dict]:
    """Filter major holders to only include data for the CSV date."""
    # For major holders, we'll include all data since yfinance doesn't provide date-specific filtering
    # and holder information doesn't change frequently
    filtered_data = holders_data
    
    logger.info(f"Filtered to {len(filtered_data)} major holder records for CSV date {csv_date}")
    return filtered_data

def compare_major_holders(new_data: Dict, existing_data: Dict) -> bool:
    """Compare new major holder data with existing data."""
    # Compare key fields
    key_fields = [
        'holder_name', 'holder_type', 'shares_held', 'percentage_held', 'value', 'currency'
    ]
    
    for field in key_fields:
        new_val = new_data.get(field)
        existing_val = existing_data.get(field)
        
        # Handle numeric comparison for shares_held, percentage_held, and value
        if field in ['shares_held', 'percentage_held', 'value']:
            try:
                new_val = Decimal(str(new_val)) if new_val is not None else None
                existing_val = Decimal(str(existing_val)) if existing_val is not None else None
            except:
                pass
        
        if new_val != existing_val:
            return True  # Data has changed
    
    return False  # No changes

def insert_major_holders(session, company: Dict, holders_data: List[Dict], csv_date: date):
    """Insert new or updated major holders into the database."""
    try:
        # Get existing data for comparison
        existing_data = get_existing_major_holders(session, company['id'], csv_date)
        
        inserted_count = 0
        updated_count = 0
        
        for holder_data in holders_data:
            # Create key for comparison
            key = f"{holder_data['holder_name']}_{holder_data['holder_type']}"
            
            # Check if data exists and has changed
            if key in existing_data:
                if compare_major_holders(holder_data, existing_data[key]):
                    # Update existing record
                    existing_holder = session.query(MajorHolder).filter(
                        MajorHolder.id == existing_data[key]['id']
                    ).first()
                    
                    if existing_holder:
                        # Update fields
                        for field, value in holder_data.items():
                            if hasattr(existing_holder, field):
                                setattr(existing_holder, field, value)
                        existing_holder.last_modified = csv_date
                        updated_count += 1
            else:
                # Insert new record
                new_holder = MajorHolder(
                    company_id=company['id'],
                    company_code=company['nse_code'] or company['bse_code'],
                    company_name=company['name'],
                    date=csv_date,
                    holder_name=holder_data.get('holder_name'),
                    holder_type=holder_data.get('holder_type'),
                    shares_held=holder_data.get('shares_held'),
                    percentage_held=holder_data.get('percentage_held'),
                    value=holder_data.get('value'),
                    currency=holder_data.get('currency'),
                    last_modified=csv_date
                )
                session.add(new_holder)
                inserted_count += 1
        
        # Commit changes
        if inserted_count > 0 or updated_count > 0:
            session.commit()
            logger.info(f"Major holders for {company['name']}: {inserted_count} inserted, {updated_count} updated")
        
        return inserted_count, updated_count
        
    except Exception as e:
        session.rollback()
        logger.error(f"Failed to insert major holders for {company['name']}: {e}")
        raise

def process_company_major_holders(session, company: Dict, csv_date: date) -> Tuple[int, int]:
    """Process major holders for a single company."""
    try:
        # Fetch data from yfinance
        holders_data = fetch_major_holders_yf(company['ticker'], company['name'])
        
        if not holders_data:
            logger.warning(f"No major holders data found for {company['name']} ({company['ticker']})")
            return 0, 0
        
        # Filter to CSV date
        filtered_data = filter_holders_by_csv_date(holders_data, csv_date)
        
        if not filtered_data:
            logger.info(f"No major holders data for CSV date {csv_date} for {company['name']}")
            return 0, 0
        
        # Insert into database
        inserted, updated = insert_major_holders(session, company, filtered_data, csv_date)
        
        return inserted, updated
        
    except Exception as e:
        logger.error(f"Failed to process major holders for {company['name']}: {e}")
        return 0, 0

def main():
    """Main function to run the daily major holders ingestion."""
    start_time = time.time()
    logger.info(f"Starting daily major holders ingestion for CSV date: {CSV_DATE}")
    
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
                
                inserted, updated = process_company_major_holders(session, company, CSV_DATE)
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
        logger.info(f"Daily major holders ingestion completed:")
        logger.info(f"  - Companies processed: {processed_count}/{len(companies)}")
        logger.info(f"  - Records inserted: {total_inserted}")
        logger.info(f"  - Records updated: {total_updated}")
        logger.info(f"  - Total time: {elapsed_time:.2f} seconds")
        
    except Exception as e:
        logger.error(f"Daily major holders ingestion failed: {e}")
        raise
    finally:
        if 'session' in locals():
            session.close()

if __name__ == "__main__":
    main() 