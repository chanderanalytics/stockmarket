"""
Part 1: Create CSV for database insertion
Processes master bhavcopy data and creates a clean CSV ready for database insertion.
"""

import pandas as pd
import os
import sys
import logging
from pathlib import Path

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('create_db_csv.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def process_data_for_db(input_file, output_file):
    """
    Process the master bhavcopy data to create a clean CSV for database insertion.
    """
    try:
        logger.info(f"Processing data from: {input_file}")
        
        # Read data in chunks
        chunk_size = 100000
        all_chunks = []
        
        logger.info("Reading data in chunks...")
        for chunk in pd.read_csv(input_file, chunksize=chunk_size):
            logger.info(f"Processing chunk with {len(chunk)} rows...")
            
            # Add exchange priority for sorting (NSE = 1, BSE = 2)
            chunk['exchange_priority'] = chunk['exchange'].map({'NSE': 1, 'BSE': 2})
            
            all_chunks.append(chunk)
        
        logger.info(f"Combining {len(all_chunks)} chunks...")
        df = pd.concat(all_chunks, ignore_index=True)
        
        logger.info(f"Total rows before deduplication: {len(df):,}")
        
        # Use company_name as the company name column
        company_col = 'company_name_updated'
        
        # Sort by company name, timestamp, and exchange priority (NSE first)
        df = df.sort_values([company_col, 'timestamp', 'exchange_priority'])
        
        # Remove duplicates by company and date, keeping first occurrence (NSE preferred)
        df_deduped = df.drop_duplicates(subset=[company_col, 'timestamp'], keep='first')
        
        logger.info(f"Rows after deduplication: {len(df_deduped):,}")
        logger.info(f"Duplicates removed: {len(df) - len(df_deduped):,}")
        
        # Calculate deduplication statistics
        nse_preferred = len(df_deduped[df_deduped['exchange'] == 'NSE'])
        bse_preferred = len(df_deduped[df_deduped['exchange'] == 'BSE'])
        
        logger.info(f"NSE records in final data: {nse_preferred:,}")
        logger.info(f"BSE records in final data: {bse_preferred:,}")
        
        # Rename company_name_updated to company_name for database (if needed)
        if company_col == 'company_name_updated':
            df_deduped = df_deduped.rename(columns={'company_name_updated': 'company_name'})
        
        # Select columns matching the database table structure
        columns_for_db = [
            'symbol', 'series', 'open_price', 'high', 'low', 'close',
            'last_price', 'prev_close', 'total_traded_qty', 'total_traded_val',
            'total_trades', 'isin', 'exchange', 'timestamp', 'company_name', 'company_id'
        ]
        
        # Select only the columns we need
        df_final = df_deduped[columns_for_db].copy()
        
        # Handle missing values
        df_final['isin'] = df_final['isin'].fillna('')
        df_final['company_name'] = df_final['company_name'].fillna(df_final['symbol'])
        # Convert company_id to Int64 to handle NA values properly
        df_final['company_id'] = pd.to_numeric(df_final['company_id'], errors='coerce').astype('Int64')
        
        # Convert data types for database compatibility
        logger.info("Converting data types for database compatibility...")
        df_final['timestamp'] = pd.to_datetime(df_final['timestamp']).dt.date
        df_final['open_price'] = pd.to_numeric(df_final['open_price'], errors='coerce')
        df_final['high'] = pd.to_numeric(df_final['high'], errors='coerce')
        df_final['low'] = pd.to_numeric(df_final['low'], errors='coerce')
        df_final['close'] = pd.to_numeric(df_final['close'], errors='coerce')
        df_final['last_price'] = pd.to_numeric(df_final['last_price'], errors='coerce')
        df_final['prev_close'] = pd.to_numeric(df_final['prev_close'], errors='coerce')
        df_final['total_traded_qty'] = pd.to_numeric(df_final['total_traded_qty'], errors='coerce').astype('Int64')
        df_final['total_traded_val'] = pd.to_numeric(df_final['total_traded_val'], errors='coerce')
        # Convert total_trades to integer (remove decimal points) - ensure proper integer conversion
        df_final['total_trades'] = pd.to_numeric(df_final['total_trades'], errors='coerce').fillna(0).astype(int)
        
        # Save to CSV
        logger.info(f"Saving processed data to: {output_file}")
        df_final.to_csv(output_file, index=False)
        
        logger.info("="*50)
        logger.info("Processing Summary:")
        logger.info(f"Original rows: {len(df):,}")
        logger.info(f"Final rows: {len(df_final):,}")
        logger.info(f"Reduction: {((len(df) - len(df_final)) / len(df) * 100):.2f}%")
        logger.info(f"NSE records: {nse_preferred:,}")
        logger.info(f"BSE records: {bse_preferred:,}")
        logger.info(f"Output file: {output_file}")
        logger.info("="*50)
        
        return True
        
    except Exception as e:
        logger.error(f"Error processing data: {e}")
        return False

def main():
    if len(sys.argv) < 3:
        print("Usage: python create_db_csv.py <input_file> <output_file>")
        print("Example: python create_db_csv.py data/master_bhavcopy_with_names.csv data/db_ready.csv")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    
    if not os.path.exists(input_file):
        logger.error(f"Input file does not exist: {input_file}")
        sys.exit(1)
    
    logger.info("Starting CSV creation for database insertion...")
    success = process_data_for_db(input_file, output_file)
    
    if success:
        logger.info(f"Successfully created database-ready CSV: {output_file}")
        sys.exit(0)
    else:
        logger.error("Failed to create database-ready CSV. Check the log for details.")
        sys.exit(1)

if __name__ == "__main__":
    main()

