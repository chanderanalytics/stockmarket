"""
Script to fetch and update yfinance information for companies using unified codes - ONETIME/FULL VERSION.

This script fetches additional company information from yfinance and updates
the companies table with this data using unified codes.
Optimized for one-time/full runs with onetime logging.
"""

import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import yfinance as yf
from sqlalchemy import create_engine, or_, and_
from sqlalchemy.orm import sessionmaker
from backend.models import Base, Company
from datetime import datetime, timedelta
import math
import logging

# Set up logging for one-time/full runs
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
        # Remove .0 suffix from BSE code for yfinance format
        bse_code_str = str(company.bse_code)
        if "." in bse_code_str:
            bse_code_str = bse_code_str.split(".")[0]
        return f"{bse_code_str}.BO", 'BSE'
    return None, None

def analyze_yfinance_data_quality(session):
    """Analyze data quality for all yfinance columns in the companies table"""
    quality_report = {
        'total_companies': 0,
        'yfinance_columns': {}
    }
    
    # Get total count
    total_companies = session.query(Company).count()
    quality_report['total_companies'] = total_companies
    
    # Define yfinance columns to analyze
    yf_columns = [
        'sector_yf', 'industry_yf', 'country_yf', 'website_yf', 'longBusinessSummary_yf',
        'fullTimeEmployees_yf', 'city_yf', 'state_yf', 'address1_yf', 'zip_yf', 'phone_yf',
        'marketCap_yf', 'sharesOutstanding_yf', 'logo_url_yf', 'exchange_yf', 'currency_yf',
        'financialCurrency_yf', 'beta_yf', 'trailingPE_yf', 'forwardPE_yf', 'priceToBook_yf',
        'bookValue_yf', 'payoutRatio_yf', 'ebitda_yf', 'revenueGrowth_yf', 'grossMargins_yf',
        'operatingMargins_yf', 'profitMargins_yf', 'returnOnAssets_yf', 'returnOnEquity_yf',
        'totalRevenue_yf', 'grossProfits_yf', 'freeCashflow_yf', 'operatingCashflow_yf',
        'debtToEquity_yf', 'currentRatio_yf', 'quickRatio_yf', 'shortRatio_yf', 'pegRatio_yf',
        'enterpriseValue_yf', 'enterpriseToRevenue_yf', 'enterpriseToEbitda_yf'
    ]
    
    for column_name in yf_columns:
        if hasattr(Company, column_name):
            # Count non-null values
            non_null_count = session.query(Company).filter(getattr(Company, column_name) != None).count()
            null_count = total_companies - non_null_count
            null_percentage = (null_count / total_companies) * 100 if total_companies > 0 else 0
            non_null_percentage = (non_null_count / total_companies) * 100 if total_companies > 0 else 0
            
            # Count unique values
            unique_count = session.query(getattr(Company, column_name)).distinct().count()
            
            quality_report['yfinance_columns'][column_name] = {
                'total_values': total_companies,
                'non_null_values': non_null_count,
                'null_values': null_count,
                'null_percentage': null_percentage,
                'non_null_percentage': non_null_percentage,
                'unique_values': unique_count
            }
    
    return quality_report

def has_yfinance_data(company):
    """Check if company already has yfinance data"""
    # Check if key yfinance fields are populated
    key_fields = ['sector_yf', 'industry_yf', 'marketCap_yf', 'trailingPE_yf']
    for field in key_fields:
        if hasattr(company, field) and getattr(company, field) is not None:
            return True
    return False

def normalize_value(val):
    if val is None:
        return None
    if isinstance(val, float) and math.isnan(val):
        return None
    sval = str(val).strip().lower()
    if sval in ('', 'nan', 'none'):
        return None
    return sval

def compare_and_update_yfinance_data(company, info):
    """Compare existing yfinance data with fresh data and update only changed values"""
    changes_made = False
    updated_fields = []
    
    # Define yfinance fields to check
    yf_fields = {
        'sector_yf': info.get('sector'),
        'industry_yf': info.get('industry'),
        'country_yf': info.get('country'),
        'website_yf': info.get('website'),
        'longBusinessSummary_yf': info.get('longBusinessSummary'),
        'fullTimeEmployees_yf': info.get('fullTimeEmployees'),
        'city_yf': info.get('city'),
        'state_yf': info.get('state'),
        'address1_yf': info.get('address1'),
        'zip_yf': info.get('zip'),
        'phone_yf': info.get('phone'),
        'marketCap_yf': info.get('marketCap'),
        'sharesOutstanding_yf': info.get('sharesOutstanding'),
        'logo_url_yf': info.get('logo_url'),
        'exchange_yf': info.get('exchange'),
        'currency_yf': info.get('currency'),
        'financialCurrency_yf': info.get('financialCurrency'),
        'beta_yf': info.get('beta'),
        'trailingPE_yf': info.get('trailingPE'),
        'forwardPE_yf': info.get('forwardPE'),
        'priceToBook_yf': info.get('priceToBook'),
        'bookValue_yf': info.get('bookValue'),
        'payoutRatio_yf': info.get('payoutRatio'),
        'ebitda_yf': info.get('ebitda'),
        'revenueGrowth_yf': info.get('revenueGrowth'),
        'grossMargins_yf': info.get('grossMargins'),
        'operatingMargins_yf': info.get('operatingMargins'),
        'profitMargins_yf': info.get('profitMargins'),
        'returnOnAssets_yf': info.get('returnOnAssets'),
        'returnOnEquity_yf': info.get('returnOnEquity'),
        'totalRevenue_yf': info.get('totalRevenue'),
        'grossProfits_yf': info.get('grossProfits'),
        'freeCashflow_yf': info.get('freeCashflow'),
        'operatingCashflow_yf': info.get('operatingCashflow'),
        'debtToEquity_yf': info.get('debtToEquity'),
        'currentRatio_yf': info.get('currentRatio'),
        'quickRatio_yf': info.get('quickRatio'),
        'shortRatio_yf': info.get('shortRatio'),
        'pegRatio_yf': info.get('pegRatio'),
        'enterpriseValue_yf': info.get('enterpriseValue'),
        'enterpriseToRevenue_yf': info.get('enterpriseToRevenue'),
        'enterpriseToEbitda_yf': info.get('enterpriseToEbitda')
    }
    
    for field_name, new_value in yf_fields.items():
        if hasattr(company, field_name):
            current_value = getattr(company, field_name)
            
            # Compare values (handle None cases)
            if normalize_value(current_value) != normalize_value(new_value):
                setattr(company, field_name, new_value)
                changes_made = True
                updated_fields.append(field_name)
    
    return changes_made, updated_fields

def fetch_and_update_yfinance_info(mode='full'):
    """
    Fetch yfinance info for all companies and update the database with smart comparison.
    Only updates fields that have actually changed.
    """
    session = Session()
    
    # Initialize quality metrics
    quality_metrics = {
        'start_time': datetime.now(),
        'total_companies': 0,
        'companies_with_valid_codes': 0,
        'companies_processed': 0,
        'companies_updated': 0,
        'companies_no_changes': 0,
        'companies_api_errors': 0,
        'api_calls': 0,
        'api_errors': 0,
        'database_errors': 0
    }
    
    try:
        # Simplified query - get all companies, filter in Python for better performance
        query = session.query(Company)
        companies = query.all()
        
        quality_metrics['total_companies'] = len(companies)
        
        # Filter companies with valid codes in Python (faster than complex OR query)
        valid_companies = []
        for company in companies:
            if (company.nse_code and company.nse_code.strip()) or (company.bse_code and company.bse_code.strip()):
                valid_companies.append(company)
        
        quality_metrics['companies_with_valid_codes'] = len(valid_companies)
        total = len(valid_companies)
        
        print(f"Fetching yfinance info for {total} companies (smart comparison)" + (f" (limited to {total})" if total else "") + "...")
        logger.info(f"Fetching yfinance info for {total} companies (smart comparison)" + (f" (limited to {total})" if total else ""))
        
        for i, company in enumerate(valid_companies, 1):
            try:
                quality_metrics['companies_processed'] += 1
                quality_metrics['api_calls'] += 1
                
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
                
                # Smart comparison and update
                changes_made, updated_fields = compare_and_update_yfinance_data(company, info)
                
                if changes_made:
                    company.last_modified = datetime.now().date()
                    session.merge(company)
                    quality_metrics['companies_updated'] += 1
                    logger.info(f"Updated {company.name} ({ticker}) - changed fields: {', '.join(updated_fields)}")
                    print(f"{i}/{total}: {company.name} ({ticker}) - updated {len(updated_fields)} fields")
                else:
                    quality_metrics['companies_no_changes'] += 1
                    logger.info(f"No changes for {company.name} ({ticker}) - data is current")
                    print(f"{i}/{total}: {company.name} ({ticker}) - no changes needed")
                
                # Update exchange field if needed
                if exchange and company.exchange != exchange:
                    company.exchange = exchange
                
                # Commit less frequently for better performance
                if i % 100 == 0:
                    session.commit()
                    print(f"Processed {i}/{total} companies...")
                
            except Exception as e:
                quality_metrics['companies_api_errors'] += 1
                quality_metrics['api_errors'] += 1
                logger.error(f"Error updating {company.name}: {e}")
                print(f"{i}/{total}: {company.name} - ERROR: {e}")
                continue
        
        # Final commit
        session.commit()
        
        # Calculate final metrics
        quality_metrics['end_time'] = datetime.now()
        quality_metrics['duration'] = quality_metrics['end_time'] - quality_metrics['start_time']
        
        # Log comprehensive data quality summary
        logger.info("=== YFINANCE DATA QUALITY SUMMARY ===")
        logger.info(f"Mode: smart comparison")
        logger.info(f"Total companies: {quality_metrics['total_companies']}")
        logger.info(f"Companies with valid codes: {quality_metrics['companies_with_valid_codes']}")
        logger.info(f"Companies processed: {quality_metrics['companies_processed']}")
        logger.info(f"Companies updated: {quality_metrics['companies_updated']}")
        logger.info(f"Companies with no changes: {quality_metrics['companies_no_changes']}")
        logger.info(f"Companies with API errors: {quality_metrics['companies_api_errors']}")
        logger.info(f"API calls made: {quality_metrics['api_calls']}")
        logger.info(f"API errors: {quality_metrics['api_errors']}")
        logger.info(f"Processing duration: {quality_metrics['duration']}")
        logger.info(f"Success rate: {quality_metrics['companies_updated'] / quality_metrics['companies_with_valid_codes'] * 100:.2f}%")
        
        print(f"\nYFinance Info Update Summary:")
        print(f"- Mode: smart comparison")
        print(f"- Total companies: {quality_metrics['total_companies']}")
        print(f"- Successfully updated: {quality_metrics['companies_updated']}")
        print(f"- No changes needed: {quality_metrics['companies_no_changes']}")
        print(f"- Errors: {quality_metrics['companies_api_errors']}")
        print(f"- Success rate: {quality_metrics['companies_updated'] / quality_metrics['companies_with_valid_codes'] * 100:.2f}%")
        
        # Analyze yfinance data quality
        print("Analyzing yfinance data quality...")
        logger.info("=== YFINANCE DATA QUALITY ANALYSIS ===")
        yf_quality = analyze_yfinance_data_quality(session)
        
        # Log yfinance data quality report
        logger.info(f"Total companies in database: {yf_quality['total_companies']}")
        logger.info("YFinance column-level data quality:")
        for column, stats in yf_quality['yfinance_columns'].items():
            logger.info(f"  {column}:")
            logger.info(f"    - Non-null values: {stats['non_null_values']}/{stats['total_values']} ({stats['non_null_percentage']:.2f}%)")
            logger.info(f"    - Null values: {stats['null_values']}/{stats['total_values']} ({stats['null_percentage']:.2f}%)")
            logger.info(f"    - Unique values: {stats['unique_values']}")
        
        # Print summary to console
        print(f"\nYFinance Data Quality Summary:")
        print(f"Total companies: {yf_quality['total_companies']}")
        print(f"YFinance columns analyzed: {len(yf_quality['yfinance_columns'])}")
        print(f"\nYFinance column completion rates:")
        for column, stats in yf_quality['yfinance_columns'].items():
            print(f"  {column}: {stats['non_null_percentage']:.1f}% complete ({stats['non_null_values']}/{stats['total_values']})")
        
        logger.info(f"YFinance info update completed: {quality_metrics['companies_updated']} updated, {quality_metrics['companies_no_changes']} no changes, {quality_metrics['companies_api_errors']} errors")
        
    except Exception as e:
        quality_metrics['database_errors'] += 1
        logger.error(f"Database error during processing: {e}")
        session.rollback()
        raise
    finally:
        session.close()

if __name__ == '__main__':
    fetch_and_update_yfinance_info() 