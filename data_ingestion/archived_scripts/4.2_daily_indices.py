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
import time
import numpy as np
from sqlalchemy import create_engine, tuple_
from sqlalchemy.orm import sessionmaker
from backend.models import Base, IndexPrice, Index
from datetime import datetime, timedelta
import logging
import re
import argparse

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
    """Convert pandas/numpy values to native Python scalars for DB insertion."""
    if val is None:
        return None

    # Handle pandas Series
    if hasattr(val, 'empty'):
        if val.empty:
            return None
        try:
            val = val.iloc[0] if len(val) > 0 else None
        except Exception:
            return None

    # Convert numpy types to Python native types
    if isinstance(val, (np.generic, np.ndarray)):
        try:
            val = val.item()
        except Exception:
            return None

    # Handle pandas scalar values
    if hasattr(val, 'item') and not isinstance(val, (float, int, str)):
        try:
            val = val.item()
        except Exception:
            return None

    # Handle NaN values
    if val is not None:
        if isinstance(val, float) and (val != val):  # NaN check
            return None
        if str(val).lower() == 'nan':
            return None

    return val

def get_today_csv_file():
    today_str = datetime.now().strftime('%Y%m%d')
    expected_file = f'data_ingestion/screener_export_{today_str}.csv'
    if os.path.exists(expected_file):
        return expected_file
    else:
        raise FileNotFoundError(f"No screener_export_{today_str}.csv file found in data_ingestion folder.")

csv_file = get_today_csv_file()

def fetch_and_store_latest_indices_prices():
    session = Session()
    # Extract file_date from csv_file
    match = re.search(r'(\d{8})', csv_file)
    if match:
        file_date = datetime.strptime(match.group(1), '%Y%m%d').date()
    else:
        raise ValueError("No date found in CSV filename!")
    
    # Initialize quality metrics
    quality_metrics = {
        'start_time': datetime.now(),
        'total_indices': len(INDICES),
        'indices_processed': 0,
        'indices_no_changes': 0,
        'indices_no_yf_data': 0,
        'indices_api_errors': 0,
        'total_price_records': 0,
        'new_price_records': 0,
        'duplicate_price_records': 0,
        'invalid_price_records': 0,
        'api_calls': 0,
        'api_errors': 0,
        'database_errors': 0,
        'missing_open': 0,
        'missing_high': 0,
        'missing_low': 0,
        'missing_close': 0,
        'missing_volume': 0
    }
    
    print(f"Fetching latest indices data for {len(INDICES)} indices (simple pattern)...")
    logger.info(f"Fetching latest indices data for {len(INDICES)} indices (simple pattern)")
    
    for i, idx in enumerate(INDICES):
        logger.info(f"Fetching latest data for {idx['name']} ({idx['ticker']})...")
        try:
            quality_metrics['api_calls'] += 1
            df = yf.download(idx['ticker'], period="1d", interval="1d", progress=False, auto_adjust=False)
            
            if df is None or df.empty:
                logger.warning(f"No data for {idx['name']} ({idx['ticker']})")
                quality_metrics['indices_no_yf_data'] += 1
                continue
            
            # Data quality check: Validate dataframe structure
            required_columns = ['Open', 'High', 'Low', 'Close']
            missing_columns = [col for col in required_columns if col not in df.columns]
            if missing_columns:
                logger.warning(f"Missing columns for {idx['name']}: {missing_columns}")
                quality_metrics['indices_api_errors'] += 1
                continue
            
            price_objects = []
            all_keys = set()
            index_price_count = 0
            index_invalid_prices = 0
            
            # Only process the row matching file_date
            for date, row in df.iterrows():
                if date.date() != file_date:
                    continue
                key = (idx['name'], idx['ticker'], date.date())
                all_keys.add(key)
                index_price_count += 1
                # Data quality checks for missing data
                try:
                    if 'Open' not in row or pd.isna(row['Open']).any():
                        quality_metrics['missing_open'] += 1
                except:
                    quality_metrics['missing_open'] += 1
                try:
                    if 'High' not in row or pd.isna(row['High']).any():
                        quality_metrics['missing_high'] += 1
                except:
                    quality_metrics['missing_high'] += 1
                try:
                    if 'Low' not in row or pd.isna(row['Low']).any():
                        quality_metrics['missing_low'] += 1
                except:
                    quality_metrics['missing_low'] += 1
                try:
                    if 'Close' not in row or pd.isna(row['Close']).any():
                        quality_metrics['missing_close'] += 1
                except:
                    quality_metrics['missing_close'] += 1
                try:
                    if 'Volume' not in row or pd.isna(row['Volume']).any():
                        quality_metrics['missing_volume'] += 1
                except:
                    quality_metrics['missing_volume'] += 1
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
                    volume=get_scalar(row['Volume']) if 'Volume' in row else None,
                    last_modified=file_date
                )
                # Data quality check: Validate price data
                if price.close is not None and price.close <= 0:
                    index_invalid_prices += 1
                    logger.warning(f"Invalid close price for {idx['name']} on {date.date()}: {price.close}")
                if price.high is not None and price.low is not None and price.high < price.low:
                    index_invalid_prices += 1
                    logger.warning(f"High price less than low price for {idx['name']} on {date.date()}: High={price.high}, Low={price.low}")
                price_objects.append(price)
            
            quality_metrics['total_price_records'] += index_price_count
            quality_metrics['invalid_price_records'] += index_invalid_prices
            
            if all_keys:
                existing_keys = set(
                    session.query(IndexPrice.name, IndexPrice.ticker, IndexPrice.date)
                    .filter(tuple_(IndexPrice.name, IndexPrice.ticker, IndexPrice.date).in_(list(all_keys)))
                    .all()
                )
            else:
                existing_keys = set()
            
            new_prices = [p for p in price_objects if (p.name, p.ticker, p.date) not in existing_keys]
            quality_metrics['new_price_records'] += len(new_prices)
            quality_metrics['duplicate_price_records'] += len(price_objects) - len(new_prices)
            
            if new_prices:
                try:
                    session.bulk_save_objects(new_prices)
                    session.commit()
                    logger.info(f"Updated {idx['name']} ({idx['ticker']}) - added {len(new_prices)} new price records")
                except Exception as e:
                    quality_metrics['database_errors'] += 1
                    logger.error(f"Database error for {idx['name']}: {e}")
                    session.rollback()
            else:
                quality_metrics['indices_no_changes'] += 1
                logger.info(f"No changes for {idx['name']} ({idx['ticker']}) - all price records already exist")
            
            quality_metrics['indices_processed'] += 1
            
            # Progress tracking
            print(f"Processed {i+1}/{len(INDICES)} indices: {idx['name']} ({len(new_prices)} new records)")
            
        except Exception as e:
            quality_metrics['api_errors'] += 1
            quality_metrics['indices_api_errors'] += 1
            logger.error(f"Failed to fetch/store data for {idx['name']} ({idx['ticker']}): {e}")
    
    # Calculate final metrics
    quality_metrics['end_time'] = datetime.now()
    quality_metrics['duration'] = quality_metrics['end_time'] - quality_metrics['start_time']
    
    # Log comprehensive data quality summary
    logger.info("=== DAILY INDICES DATA QUALITY SUMMARY ===")
    logger.info(f"Mode: simple pattern")
    logger.info(f"Total indices: {quality_metrics['total_indices']}")
    logger.info(f"Indices processed: {quality_metrics['indices_processed']}")
    logger.info(f"Indices with no changes: {quality_metrics['indices_no_changes']}")
    logger.info(f"Indices with no yfinance data: {quality_metrics['indices_no_yf_data']}")
    logger.info(f"Indices with API errors: {quality_metrics['indices_api_errors']}")
    logger.info(f"Total price records fetched: {quality_metrics['total_price_records']}")
    logger.info(f"New price records inserted: {quality_metrics['new_price_records']}")
    logger.info(f"Duplicate price records (skipped): {quality_metrics['duplicate_price_records']}")
    logger.info(f"Invalid price records: {quality_metrics['invalid_price_records']}")
    logger.info(f"Missing Open prices: {quality_metrics['missing_open']}")
    logger.info(f"Missing High prices: {quality_metrics['missing_high']}")
    logger.info(f"Missing Low prices: {quality_metrics['missing_low']}")
    logger.info(f"Missing Close prices: {quality_metrics['missing_close']}")
    logger.info(f"Missing Volume data: {quality_metrics['missing_volume']}")
    logger.info(f"API calls made: {quality_metrics['api_calls']}")
    logger.info(f"API errors: {quality_metrics['api_errors']}")
    logger.info(f"Database errors: {quality_metrics['database_errors']}")
    logger.info(f"Processing duration: {quality_metrics['duration']}")
    logger.info(f"Success rate: {quality_metrics['indices_processed'] / quality_metrics['total_indices'] * 100:.2f}%")
    
    print(f"\nDaily Indices Summary:")
    print(f"- Mode: simple pattern")
    print(f"- Total indices: {quality_metrics['total_indices']}")
    print(f"- Indices processed: {quality_metrics['indices_processed']}")
    print(f"- No changes needed: {quality_metrics['indices_no_changes']}")
    print(f"- New price records: {quality_metrics['new_price_records']}")
    print(f"- Success rate: {quality_metrics['indices_processed'] / quality_metrics['total_indices'] * 100:.2f}%")
    
    # Analyze indices data quality
    print("Analyzing indices data quality...")
    logger.info("=== INDICES DATA QUALITY ANALYSIS ===")
    indices_quality = analyze_indices_data_quality(session)
    
    # Log indices data quality report
    logger.info(f"Total indices in database: {indices_quality['total_indices']}")
    logger.info("Indices column-level data quality:")
    for column, stats in indices_quality['columns'].items():
        logger.info(f"  {column}:")
        logger.info(f"    - Data type: {stats['data_type']}")
        logger.info(f"    - Non-null values: {stats['non_null_values']}/{stats['total_values']} ({stats['non_null_percentage']:.2f}%)")
        logger.info(f"    - Null values: {stats['null_values']}/{stats['total_values']} ({stats['null_percentage']:.2f}%)")
        logger.info(f"    - Unique values: {stats['unique_values']}")
    
    # Analyze index prices data quality
    print("Analyzing index prices data quality...")
    logger.info("=== INDEX PRICES DATA QUALITY ANALYSIS ===")
    index_prices_quality = analyze_index_prices_data_quality(session)
    
    # Log index prices data quality report
    logger.info(f"Total index price records in database: {index_prices_quality['total_index_prices']}")
    logger.info("Index prices column-level data quality:")
    for column, stats in index_prices_quality['columns'].items():
        logger.info(f"  {column}:")
        logger.info(f"    - Data type: {stats['data_type']}")
        logger.info(f"    - Non-null values: {stats['non_null_values']}/{stats['total_values']} ({stats['non_null_percentage']:.2f}%)")
        logger.info(f"    - Null values: {stats['null_values']}/{stats['total_values']} ({stats['null_percentage']:.2f}%)")
        logger.info(f"    - Unique values: {stats['unique_values']}")
    
    # Print summary to console
    print(f"\nIndices Data Quality Summary:")
    print(f"Total indices: {indices_quality['total_indices']}")
    print(f"Total index price records: {index_prices_quality['total_index_prices']}")
    print(f"Indices columns: {len(indices_quality['columns'])}")
    print(f"Index prices columns: {len(index_prices_quality['columns'])}")
    print(f"\nIndices column completion rates:")
    for column, stats in indices_quality['columns'].items():
        print(f"  {column}: {stats['non_null_percentage']:.1f}% complete ({stats['non_null_values']}/{stats['total_values']})")
    print(f"\nIndex prices column completion rates:")
    for column, stats in index_prices_quality['columns'].items():
        print(f"  {column}: {stats['non_null_percentage']:.1f}% complete ({stats['non_null_values']}/{stats['total_values']})")
    
    logger.info(f"Daily indices completed: {quality_metrics['indices_processed']} processed, {quality_metrics['new_price_records']} new records, {quality_metrics['indices_no_changes']} no changes, {quality_metrics['indices_api_errors']} errors")
    
    session.close()
    logger.info("All indices processed.")

def clean_numeric_value(value):
    """Clean and convert numeric values"""
    if value is None or str(value).strip() == '' or str(value).lower() == 'nan':
        return None
    
    try:
        # Remove any currency symbols, commas, etc.
        cleaned = str(value).replace(',', '').replace('₹', '').replace('$', '').strip()
        if cleaned == '' or cleaned.lower() == 'nan':
            return None
        return float(cleaned)
    except (ValueError, TypeError):
        return None

def analyze_indices_data_quality(session):
    """Analyze data quality for all columns in the indices table"""
    quality_report = {
        'total_indices': 0,
        'columns': {}
    }
    
    # Get total count
    total_indices = session.query(Index).count()
    quality_report['total_indices'] = total_indices
    
    # Get column information from the model
    columns = Index.__table__.columns
    
    for column in columns:
        column_name = column.name
        
        # Count non-null values
        non_null_count = session.query(Index).filter(getattr(Index, column_name) != None).count()
        null_count = total_indices - non_null_count
        null_percentage = (null_count / total_indices) * 100 if total_indices > 0 else 0
        non_null_percentage = (non_null_count / total_indices) * 100 if total_indices > 0 else 0
        
        # Count unique values
        unique_count = session.query(getattr(Index, column_name)).distinct().count()
        
        quality_report['columns'][column_name] = {
            'total_values': total_indices,
            'non_null_values': non_null_count,
            'null_values': null_count,
            'null_percentage': null_percentage,
            'non_null_percentage': non_null_percentage,
            'unique_values': unique_count,
            'data_type': str(column.type)
        }
    
    return quality_report

def analyze_index_prices_data_quality(session):
    """Analyze data quality for all columns in the index_prices table"""
    quality_report = {
        'total_index_prices': 0,
        'columns': {}
    }
    
    # Get total count
    total_index_prices = session.query(IndexPrice).count()
    quality_report['total_index_prices'] = total_index_prices
    
    # Get column information from the model
    columns = IndexPrice.__table__.columns
    
    for column in columns:
        column_name = column.name
        
        # Count non-null values
        non_null_count = session.query(IndexPrice).filter(getattr(IndexPrice, column_name) != None).count()
        null_count = total_index_prices - non_null_count
        null_percentage = (null_count / total_index_prices) * 100 if total_index_prices > 0 else 0
        non_null_percentage = (non_null_count / total_index_prices) * 100 if total_index_prices > 0 else 0
        
        # Count unique values
        unique_count = session.query(getattr(IndexPrice, column_name)).distinct().count()
        
        quality_report['columns'][column_name] = {
            'total_values': total_index_prices,
            'non_null_values': non_null_count,
            'null_values': null_count,
            'null_percentage': null_percentage,
            'non_null_percentage': non_null_percentage,
            'unique_values': unique_count,
            'data_type': str(column.type)
        }
    
    return quality_report

if __name__ == "__main__":
    fetch_and_store_latest_indices_prices() 