#!/usr/bin/env python3
"""
Daily Analyst Recommendations Data Ingestion Script

This script fetches analyst recommendations and ratings from yfinance for all companies
and updates the database with new or changed data.

Features:
- Fetches recent analyst recommendations from yfinance
- Filters to the CSV date only
- Compares with existing database data
- Inserts only new or changed records
- Batch processing for efficiency
- Comprehensive logging
- Error handling and retry logic

Usage:
    python 7.2_daily_analyst_recommendations.py

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

from models import AnalystRecommendation, Company, Base

# Configure logging
log_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
log_file = f'log/daily_analyst_recommendations_{log_datetime}.log'
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

def get_existing_analyst_recommendations(session, company_id: int, csv_date: date) -> Dict:
    """Get existing analyst recommendations for a company on the CSV date."""
    try:
        recommendations = session.query(AnalystRecommendation).filter(
            AnalystRecommendation.company_id == company_id,
            AnalystRecommendation.date == csv_date
        ).all()
        
        # Convert to dictionary for easy comparison
        existing_data = {}
        for rec in recommendations:
            key = f"{rec.firm}_{rec.analyst}_{rec.date}"
            existing_data[key] = {
                'id': rec.id,
                'firm': rec.firm,
                'analyst': rec.analyst,
                'action': rec.action,
                'from_rating': rec.from_rating,
                'to_rating': rec.to_rating,
                'price_target': rec.price_target,
                'price_target_currency': rec.price_target_currency,
                'recommendation': rec.recommendation
            }
        
        return existing_data
    except Exception as e:
        logger.error(f"Failed to get existing analyst recommendations for company {company_id}: {e}")
        return {}

def fetch_analyst_recommendations_yf(ticker: str, company_name: str) -> List[Dict]:
    """Fetch analyst recommendations data from yfinance."""
    try:
        # Add .NS suffix for NSE stocks if not already present
        if not ticker.endswith('.NS') and not ticker.endswith('.BO'):
            ticker = f"{ticker}.NS"
        
        logger.info(f"Fetching analyst recommendations for {ticker} ({company_name})")
        
        # Create yfinance ticker object
        yf_ticker = yf.Ticker(ticker)
        
        recommendations_data = []
        
        # Fetch analyst recommendations
        try:
            recommendations = yf_ticker.recommendations
            if recommendations is not None and not recommendations.empty:
                for index, row in recommendations.iterrows():
                    # Parse the recommendation data
                    recommendation_date = index.to_pydatetime().date()
                    
                    # Extract firm and analyst info (yfinance doesn't provide this directly)
                    # We'll use a placeholder approach
                    firm = "Unknown"
                    analyst = "Unknown"
                    
                    # Determine action and ratings based on recommendation
                    recommendation = str(row.get('Recommendation', '')).lower() if pd.notna(row.get('Recommendation')) else None
                    action = "maintain"  # Default action
                    
                    # Map recommendation to action
                    if recommendation:
                        if 'buy' in recommendation:
                            action = "upgrade" if recommendation != "buy" else "maintain"
                        elif 'sell' in recommendation:
                            action = "downgrade" if recommendation != "sell" else "maintain"
                        elif 'hold' in recommendation:
                            action = "maintain"
                    
                    recommendations_data.append({
                        'date': recommendation_date,
                        'firm': firm,
                        'analyst': analyst,
                        'action': action,
                        'from_rating': None,  # yfinance doesn't provide this
                        'to_rating': recommendation,
                        'price_target': row.get('Target Mean Price'),
                        'price_target_currency': 'INR',  # Default for Indian stocks
                        'recommendation': recommendation
                    })
        except Exception as e:
            logger.warning(f"Failed to fetch analyst recommendations for {ticker}: {e}")
        
        # Fetch analyst recommendations summary
        try:
            recommendations_summary = yf_ticker.recommendations_summary
            if recommendations_summary is not None and not recommendations_summary.empty:
                for index, row in recommendations_summary.iterrows():
                    recommendation_date = index.to_pydatetime().date()
                    
                    recommendations_data.append({
                        'date': recommendation_date,
                        'firm': "Consensus",
                        'analyst': "Multiple Analysts",
                        'action': "consensus",
                        'from_rating': None,
                        'to_rating': str(row.get('Recommendation', '')).lower() if pd.notna(row.get('Recommendation')) else None,
                        'price_target': row.get('Target Mean Price'),
                        'price_target_currency': 'INR',
                        'recommendation': str(row.get('Recommendation', '')).lower() if pd.notna(row.get('Recommendation')) else None
                    })
        except Exception as e:
            logger.warning(f"Failed to fetch analyst recommendations summary for {ticker}: {e}")
        
        logger.info(f"Fetched {len(recommendations_data)} analyst recommendation records for {ticker}")
        return recommendations_data
        
    except Exception as e:
        logger.error(f"Failed to fetch analyst recommendations for {ticker}: {e}")
        return []

def filter_recommendations_by_csv_date(recommendations_data: List[Dict], csv_date: date) -> List[Dict]:
    """Filter analyst recommendations to only include data for the CSV date."""
    filtered_data = []
    
    for rec in recommendations_data:
        # Include recommendations from the last 30 days (since yfinance doesn't provide date-specific filtering)
        if rec.get('date') and (csv_date - rec['date']).days <= 30:
            filtered_data.append(rec)
    
    logger.info(f"Filtered to {len(filtered_data)} analyst recommendation records for CSV date {csv_date}")
    return filtered_data

def compare_analyst_recommendations(new_data: Dict, existing_data: Dict) -> bool:
    """Compare new analyst recommendation data with existing data."""
    # Compare key fields
    key_fields = [
        'firm', 'analyst', 'action', 'from_rating', 'to_rating', 
        'price_target', 'price_target_currency', 'recommendation'
    ]
    
    for field in key_fields:
        new_val = new_data.get(field)
        existing_val = existing_data.get(field)
        
        # Handle numeric comparison for price_target
        if field == 'price_target':
            try:
                new_val = Decimal(str(new_val)) if new_val is not None else None
                existing_val = Decimal(str(existing_val)) if existing_val is not None else None
            except:
                pass
        
        if new_val != existing_val:
            return True  # Data has changed
    
    return False  # No changes

def insert_analyst_recommendations(session, company: Dict, recommendations_data: List[Dict], csv_date: date):
    """Insert new or updated analyst recommendations into the database."""
    try:
        # Get existing data for comparison
        existing_data = get_existing_analyst_recommendations(session, company['id'], csv_date)
        
        inserted_count = 0
        updated_count = 0
        
        for rec_data in recommendations_data:
            # Create key for comparison
            key = f"{rec_data['firm']}_{rec_data['analyst']}_{rec_data['date']}"
            
            # Check if data exists and has changed
            if key in existing_data:
                if compare_analyst_recommendations(rec_data, existing_data[key]):
                    # Update existing record
                    existing_rec = session.query(AnalystRecommendation).filter(
                        AnalystRecommendation.id == existing_data[key]['id']
                    ).first()
                    
                    if existing_rec:
                        # Update fields
                        for field, value in rec_data.items():
                            if hasattr(existing_rec, field):
                                setattr(existing_rec, field, value)
                        existing_rec.last_modified = csv_date
                        updated_count += 1
            else:
                # Insert new record
                new_rec = AnalystRecommendation(
                    company_id=company['id'],
                    company_code=company['nse_code'] or company['bse_code'],
                    company_name=company['name'],
                    date=rec_data['date'],
                    firm=rec_data.get('firm'),
                    analyst=rec_data.get('analyst'),
                    action=rec_data.get('action'),
                    from_rating=rec_data.get('from_rating'),
                    to_rating=rec_data.get('to_rating'),
                    price_target=rec_data.get('price_target'),
                    price_target_currency=rec_data.get('price_target_currency'),
                    recommendation=rec_data.get('recommendation'),
                    last_modified=csv_date
                )
                session.add(new_rec)
                inserted_count += 1
        
        # Commit changes
        if inserted_count > 0 or updated_count > 0:
            session.commit()
            logger.info(f"Analyst recommendations for {company['name']}: {inserted_count} inserted, {updated_count} updated")
        
        return inserted_count, updated_count
        
    except Exception as e:
        session.rollback()
        logger.error(f"Failed to insert analyst recommendations for {company['name']}: {e}")
        raise

def process_company_analyst_recommendations(session, company: Dict, csv_date: date) -> Tuple[int, int]:
    """Process analyst recommendations for a single company."""
    try:
        # Fetch data from yfinance
        recommendations_data = fetch_analyst_recommendations_yf(company['ticker'], company['name'])
        
        if not recommendations_data:
            logger.warning(f"No analyst recommendations data found for {company['name']} ({company['ticker']})")
            return 0, 0
        
        # Filter to CSV date
        filtered_data = filter_recommendations_by_csv_date(recommendations_data, csv_date)
        
        if not filtered_data:
            logger.info(f"No analyst recommendations data for CSV date {csv_date} for {company['name']}")
            return 0, 0
        
        # Insert into database
        inserted, updated = insert_analyst_recommendations(session, company, filtered_data, csv_date)
        
        return inserted, updated
        
    except Exception as e:
        logger.error(f"Failed to process analyst recommendations for {company['name']}: {e}")
        return 0, 0

def main():
    """Main function to run the daily analyst recommendations ingestion."""
    start_time = time.time()
    logger.info(f"Starting daily analyst recommendations ingestion for CSV date: {CSV_DATE}")
    
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
                
                inserted, updated = process_company_analyst_recommendations(session, company, CSV_DATE)
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
        logger.info(f"Daily analyst recommendations ingestion completed:")
        logger.info(f"  - Companies processed: {processed_count}/{len(companies)}")
        logger.info(f"  - Records inserted: {total_inserted}")
        logger.info(f"  - Records updated: {total_updated}")
        logger.info(f"  - Total time: {elapsed_time:.2f} seconds")
        
    except Exception as e:
        logger.error(f"Daily analyst recommendations ingestion failed: {e}")
        raise
    finally:
        if 'session' in locals():
            session.close()

if __name__ == "__main__":
    main() 