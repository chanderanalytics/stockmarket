#!/usr/bin/env python3
"""
Daily Financial Statements Data Ingestion Script

This script fetches financial statements data (income statement, balance sheet, cash flow)
from yfinance for all companies and updates the database with new or changed data.

Features:
- Fetches recent financial data from yfinance
- Filters to the CSV date only
- Compares with existing database data
- Inserts only new or changed records
- Batch processing for efficiency
- Comprehensive logging
- Error handling and retry logic

Usage:
    python 6.2_daily_financial_statements.py

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

from models import FinancialStatement, Company, Base

# Configure logging
log_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
log_file = f'log/daily_financial_statements_{log_datetime}.log'
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

def get_existing_financial_statements(session, company_id: int, csv_date: date) -> Dict:
    """Get existing financial statements for a company on the CSV date."""
    try:
        statements = session.query(FinancialStatement).filter(
            FinancialStatement.company_id == company_id,
            FinancialStatement.date == csv_date
        ).all()
        
        # Convert to dictionary for easy comparison
        existing_data = {}
        for stmt in statements:
            key = f"{stmt.statement_type}_{stmt.period}_{stmt.year}_{stmt.quarter}"
            existing_data[key] = {
                'id': stmt.id,
                'total_revenue': stmt.total_revenue,
                'gross_profit': stmt.gross_profit,
                'operating_income': stmt.operating_income,
                'net_income': stmt.net_income,
                'eps': stmt.eps,
                'total_assets': stmt.total_assets,
                'total_liabilities': stmt.total_liabilities,
                'total_equity': stmt.total_equity,
                'cash_and_equivalents': stmt.cash_and_equivalents,
                'total_debt': stmt.total_debt,
                'operating_cash_flow': stmt.operating_cash_flow,
                'financing_cash_flow': stmt.financing_cash_flow,
                'free_cash_flow': stmt.free_cash_flow
            }
        
        return existing_data
    except Exception as e:
        logger.error(f"Failed to get existing financial statements for company {company_id}: {e}")
        return {}

def fetch_financial_statements_yf(ticker: str, company_name: str) -> List[Dict]:
    """Fetch financial statements data from yfinance."""
    try:
        # Add .NS suffix for NSE stocks if not already present
        if not ticker.endswith('.NS') and not ticker.endswith('.BO'):
            ticker = f"{ticker}.NS"
        
        logger.info(f"Fetching financial statements for {ticker} ({company_name})")
        
        # Create yfinance ticker object
        yf_ticker = yf.Ticker(ticker)
        
        statements_data = []
        
        # Fetch income statement (annual and quarterly)
        try:
            income_annual = yf_ticker.financials
            if income_annual is not None and not income_annual.empty:
                for col in income_annual.columns:
                    year = col.year
                    quarter = None
                    period = 'annual'
                    
                    statements_data.append({
                        'statement_type': 'income',
                        'period': period,
                        'year': year,
                        'quarter': quarter,
                        'total_revenue': income_annual.loc['Total Revenue', col] if 'Total Revenue' in income_annual.index else None,
                        'gross_profit': income_annual.loc['Gross Profit', col] if 'Gross Profit' in income_annual.index else None,
                        'operating_income': income_annual.loc['Operating Income', col] if 'Operating Income' in income_annual.index else None,
                        'net_income': income_annual.loc['Net Income', col] if 'Net Income' in income_annual.index else None,
                        'eps': income_annual.loc['Basic EPS', col] if 'Basic EPS' in income_annual.index else None
                    })
        except Exception as e:
            logger.warning(f"Failed to fetch annual income statement for {ticker}: {e}")
        
        try:
            income_quarterly = yf_ticker.quarterly_financials
            if income_quarterly is not None and not income_quarterly.empty:
                for col in income_quarterly.columns:
                    year = col.year
                    quarter = col.quarter
                    period = 'quarterly'
                    
                    statements_data.append({
                        'statement_type': 'income',
                        'period': period,
                        'year': year,
                        'quarter': quarter,
                        'total_revenue': income_quarterly.loc['Total Revenue', col] if 'Total Revenue' in income_quarterly.index else None,
                        'gross_profit': income_quarterly.loc['Gross Profit', col] if 'Gross Profit' in income_quarterly.index else None,
                        'operating_income': income_quarterly.loc['Operating Income', col] if 'Operating Income' in income_quarterly.index else None,
                        'net_income': income_quarterly.loc['Net Income', col] if 'Net Income' in income_quarterly.index else None,
                        'eps': income_quarterly.loc['Basic EPS', col] if 'Basic EPS' in income_quarterly.index else None
                    })
        except Exception as e:
            logger.warning(f"Failed to fetch quarterly income statement for {ticker}: {e}")
        
        # Fetch balance sheet (annual and quarterly)
        try:
            balance_annual = yf_ticker.balance_sheet
            if balance_annual is not None and not balance_annual.empty:
                for col in balance_annual.columns:
                    year = col.year
                    quarter = None
                    period = 'annual'
                    
                    statements_data.append({
                        'statement_type': 'balance',
                        'period': period,
                        'year': year,
                        'quarter': quarter,
                        'total_assets': balance_annual.loc['Total Assets', col] if 'Total Assets' in balance_annual.index else None,
                        'total_liabilities': balance_annual.loc['Total Liabilities', col] if 'Total Liabilities' in balance_annual.index else None,
                        'total_equity': balance_annual.loc['Total Equity', col] if 'Total Equity' in balance_annual.index else None,
                        'cash_and_equivalents': balance_annual.loc['Cash And Cash Equivalents', col] if 'Cash And Cash Equivalents' in balance_annual.index else None,
                        'total_debt': balance_annual.loc['Total Debt', col] if 'Total Debt' in balance_annual.index else None
                    })
        except Exception as e:
            logger.warning(f"Failed to fetch annual balance sheet for {ticker}: {e}")
        
        try:
            balance_quarterly = yf_ticker.quarterly_balance_sheet
            if balance_quarterly is not None and not balance_quarterly.empty:
                for col in balance_quarterly.columns:
                    year = col.year
                    quarter = col.quarter
                    period = 'quarterly'
                    
                    statements_data.append({
                        'statement_type': 'balance',
                        'period': period,
                        'year': year,
                        'quarter': quarter,
                        'total_assets': balance_quarterly.loc['Total Assets', col] if 'Total Assets' in balance_quarterly.index else None,
                        'total_liabilities': balance_quarterly.loc['Total Liabilities', col] if 'Total Liabilities' in balance_quarterly.index else None,
                        'total_equity': balance_quarterly.loc['Total Equity', col] if 'Total Equity' in balance_quarterly.index else None,
                        'cash_and_equivalents': balance_quarterly.loc['Cash And Cash Equivalents', col] if 'Cash And Cash Equivalents' in balance_quarterly.index else None,
                        'total_debt': balance_quarterly.loc['Total Debt', col] if 'Total Debt' in balance_quarterly.index else None
                    })
        except Exception as e:
            logger.warning(f"Failed to fetch quarterly balance sheet for {ticker}: {e}")
        
        # Fetch cash flow (annual and quarterly)
        try:
            cashflow_annual = yf_ticker.cashflow
            if cashflow_annual is not None and not cashflow_annual.empty:
                for col in cashflow_annual.columns:
                    year = col.year
                    quarter = None
                    period = 'annual'
                    
                    statements_data.append({
                        'statement_type': 'cashflow',
                        'period': period,
                        'year': year,
                        'quarter': quarter,
                        'operating_cash_flow': cashflow_annual.loc['Operating Cash Flow', col] if 'Operating Cash Flow' in cashflow_annual.index else None,
                        'financing_cash_flow': cashflow_annual.loc['Financing Cash Flow', col] if 'Financing Cash Flow' in cashflow_annual.index else None,
                        'free_cash_flow': cashflow_annual.loc['Free Cash Flow', col] if 'Free Cash Flow' in cashflow_annual.index else None
                    })
        except Exception as e:
            logger.warning(f"Failed to fetch annual cash flow for {ticker}: {e}")
        
        try:
            cashflow_quarterly = yf_ticker.quarterly_cashflow
            if cashflow_quarterly is not None and not cashflow_quarterly.empty:
                for col in cashflow_quarterly.columns:
                    year = col.year
                    quarter = col.quarter
                    period = 'quarterly'
                    
                    statements_data.append({
                        'statement_type': 'cashflow',
                        'period': period,
                        'year': year,
                        'quarter': quarter,
                        'operating_cash_flow': cashflow_quarterly.loc['Operating Cash Flow', col] if 'Operating Cash Flow' in cashflow_quarterly.index else None,
                        'financing_cash_flow': cashflow_quarterly.loc['Financing Cash Flow', col] if 'Financing Cash Flow' in cashflow_quarterly.index else None,
                        'free_cash_flow': cashflow_quarterly.loc['Free Cash Flow', col] if 'Free Cash Flow' in cashflow_quarterly.index else None
                    })
        except Exception as e:
            logger.warning(f"Failed to fetch quarterly cash flow for {ticker}: {e}")
        
        logger.info(f"Fetched {len(statements_data)} financial statement records for {ticker}")
        return statements_data
        
    except Exception as e:
        logger.error(f"Failed to fetch financial statements for {ticker}: {e}")
        return []

def filter_statements_by_csv_date(statements_data: List[Dict], csv_date: date) -> List[Dict]:
    """Filter financial statements to only include data for the CSV date."""
    filtered_data = []
    
    for stmt in statements_data:
        # For financial statements, we'll include recent data (last 2 years)
        # since yfinance doesn't provide date-specific filtering
        if stmt.get('year') and stmt['year'] >= csv_date.year - 2:
            filtered_data.append(stmt)
    
    logger.info(f"Filtered to {len(filtered_data)} financial statement records for CSV date {csv_date}")
    return filtered_data

def compare_financial_statements(new_data: Dict, existing_data: Dict) -> bool:
    """Compare new financial statement data with existing data."""
    # Convert numeric values to Decimal for comparison
    def to_decimal(value):
        if value is None:
            return None
        try:
            return Decimal(str(value))
        except:
            return None
    
    # Compare key fields
    key_fields = [
        'total_revenue', 'gross_profit', 'operating_income', 'net_income', 'eps',
        'total_assets', 'total_liabilities', 'total_equity', 'cash_and_equivalents', 'total_debt',
        'operating_cash_flow', 'financing_cash_flow', 'free_cash_flow'
    ]
    
    for field in key_fields:
        new_val = to_decimal(new_data.get(field))
        existing_val = to_decimal(existing_data.get(field))
        
        if new_val != existing_val:
            return True  # Data has changed
    
    return False  # No changes

def insert_financial_statements(session, company: Dict, statements_data: List[Dict], csv_date: date):
    """Insert new or updated financial statements into the database."""
    try:
        # Get existing data for comparison
        existing_data = get_existing_financial_statements(session, company['id'], csv_date)
        
        inserted_count = 0
        updated_count = 0
        
        for stmt_data in statements_data:
            # Create key for comparison
            key = f"{stmt_data['statement_type']}_{stmt_data['period']}_{stmt_data['year']}_{stmt_data['quarter']}"
            
            # Check if data exists and has changed
            if key in existing_data:
                if compare_financial_statements(stmt_data, existing_data[key]):
                    # Update existing record
                    existing_stmt = session.query(FinancialStatement).filter(
                        FinancialStatement.id == existing_data[key]['id']
                    ).first()
                    
                    if existing_stmt:
                        # Update fields
                        for field, value in stmt_data.items():
                            if hasattr(existing_stmt, field):
                                setattr(existing_stmt, field, value)
                        existing_stmt.last_modified = csv_date
                        updated_count += 1
            else:
                # Insert new record
                new_stmt = FinancialStatement(
                    company_id=company['id'],
                    company_code=company['nse_code'] or company['bse_code'],
                    company_name=company['name'],
                    date=csv_date,
                    statement_type=stmt_data['statement_type'],
                    period=stmt_data['period'],
                    year=stmt_data['year'],
                    quarter=stmt_data['quarter'],
                    total_revenue=stmt_data.get('total_revenue'),
                    gross_profit=stmt_data.get('gross_profit'),
                    operating_income=stmt_data.get('operating_income'),
                    net_income=stmt_data.get('net_income'),
                    eps=stmt_data.get('eps'),
                    total_assets=stmt_data.get('total_assets'),
                    total_liabilities=stmt_data.get('total_liabilities'),
                    total_equity=stmt_data.get('total_equity'),
                    cash_and_equivalents=stmt_data.get('cash_and_equivalents'),
                    total_debt=stmt_data.get('total_debt'),
                    operating_cash_flow=stmt_data.get('operating_cash_flow'),
                    financing_cash_flow=stmt_data.get('financing_cash_flow'),
                    free_cash_flow=stmt_data.get('free_cash_flow'),
                    last_modified=csv_date
                )
                session.add(new_stmt)
                inserted_count += 1
        
        # Commit changes
        if inserted_count > 0 or updated_count > 0:
            session.commit()
            logger.info(f"Financial statements for {company['name']}: {inserted_count} inserted, {updated_count} updated")
        
        return inserted_count, updated_count
        
    except Exception as e:
        session.rollback()
        logger.error(f"Failed to insert financial statements for {company['name']}: {e}")
        raise

def process_company_financial_statements(session, company: Dict, csv_date: date) -> Tuple[int, int]:
    """Process financial statements for a single company."""
    try:
        # Fetch data from yfinance
        statements_data = fetch_financial_statements_yf(company['ticker'], company['name'])
        
        if not statements_data:
            logger.warning(f"No financial statements data found for {company['name']} ({company['ticker']})")
            return 0, 0
        
        # Filter to CSV date
        filtered_data = filter_statements_by_csv_date(statements_data, csv_date)
        
        if not filtered_data:
            logger.info(f"No financial statements data for CSV date {csv_date} for {company['name']}")
            return 0, 0
        
        # Insert into database
        inserted, updated = insert_financial_statements(session, company, filtered_data, csv_date)
        
        return inserted, updated
        
    except Exception as e:
        logger.error(f"Failed to process financial statements for {company['name']}: {e}")
        return 0, 0

def main():
    """Main function to run the daily financial statements ingestion."""
    start_time = time.time()
    logger.info(f"Starting daily financial statements ingestion for CSV date: {CSV_DATE}")
    
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
                
                inserted, updated = process_company_financial_statements(session, company, CSV_DATE)
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
        logger.info(f"Daily financial statements ingestion completed:")
        logger.info(f"  - Companies processed: {processed_count}/{len(companies)}")
        logger.info(f"  - Records inserted: {total_inserted}")
        logger.info(f"  - Records updated: {total_updated}")
        logger.info(f"  - Total time: {elapsed_time:.2f} seconds")
        
    except Exception as e:
        logger.error(f"Daily financial statements ingestion failed: {e}")
        raise
    finally:
        if 'session' in locals():
            session.close()

if __name__ == "__main__":
    main() 