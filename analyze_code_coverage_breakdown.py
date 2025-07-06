"""
Script to analyze price data coverage for all companies, broken down by code type (NSE-only, BSE-only, both).
Shows, for each group, the count and price data coverage: <5 years, 5-10 years, 10+ years.
"""

import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from sqlalchemy import create_engine, and_, or_
from sqlalchemy.orm import sessionmaker
from backend.models import Company, Price
from datetime import datetime, timedelta
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DATABASE_URL = 'postgresql://stockuser:stockpass@localhost:5432/stockdb'
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)

def get_coverage_breakdown(companies, session, code_type):
    """Return coverage breakdown for a list of companies by code_type (nse_code or bse_code)"""
    today = datetime.now().date()
    five_years_ago = today - timedelta(days=5*365)
    ten_years_ago = today - timedelta(days=10*365)
    
    less_than_5 = 0
    between_5_and_10 = 0
    more_than_10 = 0
    no_data = 0
    total = len(companies)
    
    for company in companies:
        code = getattr(company, code_type)
        if not code:
            no_data += 1
            continue
        prices = session.query(Price).filter(Price.company_code == code).all()
        if not prices:
            no_data += 1
            continue
        dates = [p.date for p in prices]
        min_date = min(dates)
        # Coverage logic
        if min_date <= ten_years_ago:
            more_than_10 += 1
        elif min_date <= five_years_ago:
            between_5_and_10 += 1
        else:
            less_than_5 += 1
    return {
        'total': total,
        '<5': less_than_5,
        '5-10': between_5_and_10,
        '10+': more_than_10,
        'no_data': no_data
    }

def main():
    session = Session()
    try:
        print("Analyzing price data coverage by code type...")
        print("=" * 60)
        total_companies = session.query(Company).count()
        print(f"Total companies: {total_companies}")
        
        # NSE-only
        nse_only_companies = session.query(Company).filter(
            and_(
                Company.nse_code != None, Company.nse_code != "",
                or_(Company.bse_code == None, Company.bse_code == "")
            )
        ).all()
        # BSE-only
        bse_only_companies = session.query(Company).filter(
            and_(
                Company.bse_code != None, Company.bse_code != "",
                or_(Company.nse_code == None, Company.nse_code == "")
            )
        ).all()
        # Both
        both_companies = session.query(Company).filter(
            and_(
                Company.nse_code != None, Company.nse_code != "",
                Company.bse_code != None, Company.bse_code != ""
            )
        ).all()
        
        print(f"NSE-only companies: {len(nse_only_companies)}")
        print(f"BSE-only companies: {len(bse_only_companies)}")
        print(f"Companies with both NSE and BSE: {len(both_companies)}")
        print("-" * 60)
        
        # Coverage breakdowns
        nse_only_breakdown = get_coverage_breakdown(nse_only_companies, session, 'nse_code')
        bse_only_breakdown = get_coverage_breakdown(bse_only_companies, session, 'bse_code')
        both_breakdown = get_coverage_breakdown(both_companies, session, 'nse_code')  # Use NSE code for both
        
        print("NSE-only companies:")
        print(f"  Total: {nse_only_breakdown['total']}")
        print(f"  <5 years: {nse_only_breakdown['<5']}")
        print(f"  5-10 years: {nse_only_breakdown['5-10']}")
        print(f"  10+ years: {nse_only_breakdown['10+']}")
        print(f"  No price data: {nse_only_breakdown['no_data']}")
        print()
        print("BSE-only companies:")
        print(f"  Total: {bse_only_breakdown['total']}")
        print(f"  <5 years: {bse_only_breakdown['<5']}")
        print(f"  5-10 years: {bse_only_breakdown['5-10']}")
        print(f"  10+ years: {bse_only_breakdown['10+']}")
        print(f"  No price data: {bse_only_breakdown['no_data']}")
        print()
        print("Companies with both NSE and BSE:")
        print(f"  Total: {both_breakdown['total']}")
        print(f"  <5 years: {both_breakdown['<5']}")
        print(f"  5-10 years: {both_breakdown['5-10']}")
        print(f"  10+ years: {both_breakdown['10+']}")
        print(f"  No price data: {both_breakdown['no_data']}")
        print()
        print("=" * 60)
        print("Done.")
    finally:
        session.close()

if __name__ == '__main__':
    main() 