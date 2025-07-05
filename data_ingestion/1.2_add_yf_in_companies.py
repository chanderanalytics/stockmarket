"""
Script to fetch and update yfinance information for companies using unified codes.

This script fetches additional company information from yfinance and updates
the companies table with this data using unified codes.
"""

import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import yfinance as yf
from sqlalchemy import create_engine, or_, and_
from sqlalchemy.orm import sessionmaker
from backend.models import Base, Company
from datetime import datetime
import math
import logging
import argparse

# Set up logging
log_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
logging.basicConfig(
    filename=f'log/yfinance_info_onetime_{log_datetime}.log',
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

def fetch_and_update_yfinance_info(limit=None):
    """Fetch yfinance info for all companies and update the database"""
    session = Session()
    
    # Simplified query - get all companies, filter in Python for better performance
    query = session.query(Company)
    if limit is not None:
        companies = query.limit(limit).all()
    else:
        companies = query.all()
    
    # Filter companies with valid codes in Python (faster than complex OR query)
    valid_companies = []
    for company in companies:
        if (company.nse_code and company.nse_code.strip()) or (company.bse_code and company.bse_code.strip()):
            valid_companies.append(company)
    
    total = len(valid_companies)
    print(f"Fetching yfinance info for {total} companies" + (f" (limited to {limit})" if limit else "") + "...")
    logger.info(f"Fetching yfinance info for {total} companies" + (f" (limited to {limit})" if limit else ""))
    
    updated_count = 0
    error_count = 0
    
    for i, company in enumerate(valid_companies, 1):
        try:
            ticker, exchange = get_yfinance_ticker(company)
            if not ticker:
                logger.warning(f"No valid ticker for {company.name}")
                continue
            
            # Get yfinance ticker object
            yf_ticker = yf.Ticker(ticker)
            info = yf_ticker.info
            
            if not info:
                logger.warning(f"No info found for {company.name} ({ticker})")
                continue
            
            # Update company with yfinance info
            company.sector_yf = info.get('sector')
            company.industry_yf = info.get('industry')
            company.country_yf = info.get('country')
            company.website_yf = info.get('website')
            company.longBusinessSummary_yf = info.get('longBusinessSummary')
            company.fullTimeEmployees_yf = info.get('fullTimeEmployees')
            company.city_yf = info.get('city')
            company.state_yf = info.get('state')
            company.address1_yf = info.get('address1')
            company.zip_yf = info.get('zip')
            company.phone_yf = info.get('phone')
            company.marketCap_yf = info.get('marketCap')
            company.sharesOutstanding_yf = info.get('sharesOutstanding')
            company.logo_url_yf = info.get('logo_url')
            company.exchange_yf = info.get('exchange')
            company.currency_yf = info.get('currency')
            company.financialCurrency_yf = info.get('financialCurrency')
            company.beta_yf = info.get('beta')
            company.trailingPE_yf = info.get('trailingPE')
            company.forwardPE_yf = info.get('forwardPE')
            company.priceToBook_yf = info.get('priceToBook')
            company.bookValue_yf = info.get('bookValue')
            company.payoutRatio_yf = info.get('payoutRatio')
            company.ebitda_yf = info.get('ebitda')
            company.revenueGrowth_yf = info.get('revenueGrowth')
            company.grossMargins_yf = info.get('grossMargins')
            company.operatingMargins_yf = info.get('operatingMargins')
            company.profitMargins_yf = info.get('profitMargins')
            company.returnOnAssets_yf = info.get('returnOnAssets')
            company.returnOnEquity_yf = info.get('returnOnEquity')
            company.totalRevenue_yf = info.get('totalRevenue')
            company.grossProfits_yf = info.get('grossProfits')
            company.freeCashflow_yf = info.get('freeCashflow')
            company.operatingCashflow_yf = info.get('operatingCashflow')
            company.debtToEquity_yf = info.get('debtToEquity')
            company.currentRatio_yf = info.get('currentRatio')
            company.quickRatio_yf = info.get('quickRatio')
            company.shortRatio_yf = info.get('shortRatio')
            company.pegRatio_yf = info.get('pegRatio')
            company.enterpriseValue_yf = info.get('enterpriseValue')
            company.enterpriseToRevenue_yf = info.get('enterpriseToRevenue')
            company.enterpriseToEbitda_yf = info.get('enterpriseToEbitda')
            
            # Update exchange field
            if exchange:
                company.exchange = exchange
            
            session.merge(company)
            updated_count += 1
            
            # Commit less frequently for better performance
            if i % 100 == 0:
                session.commit()
                print(f"Processed {i}/{total} companies...")
            
            logger.info(f"Updated {company.name} ({ticker}) with yfinance info")
            
        except Exception as e:
            error_count += 1
            logger.error(f"Error updating {company.name}: {e}")
            continue
    
    # Final commit
    session.commit()
    session.close()
    
    print(f"\nYFinance Info Update Summary:")
    print(f"- Total companies: {total}")
    print(f"- Successfully updated: {updated_count}")
    print(f"- Errors: {error_count}")
    
    logger.info(f"YFinance info update completed: {updated_count} updated, {error_count} errors")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Fetch yfinance information for companies.')
    parser.add_argument('--limit', type=int, default=None, help='Limit number of companies to process')
    args = parser.parse_args()
    fetch_and_update_yfinance_info(limit=args.limit) 