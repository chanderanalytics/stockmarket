"""
Script to extract data from bhavcopy ZIP files and create a master CSV file.
"""

import os
import sys
import zipfile
import pandas as pd
from pathlib import Path
import logging
from datetime import datetime

# Set up logging with separate file and console handlers
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

# Create file handler which logs even debug messages
file_handler = logging.FileHandler('create_master_csv.log')
file_handler.setLevel(logging.DEBUG)

# Create console handler with a higher log level
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)  # Only show INFO and above in console

# Create formatter and add it to the handlers
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
file_handler.setFormatter(formatter)
console_handler.setFormatter(formatter)

# Add the handlers to the logger
logger.addHandler(file_handler)
logger.addHandler(console_handler)

# Prevent duplicate logs in console
logger.propagate = False
logger = logging.getLogger(__name__)

def process_zip_file(zip_path, output_dir):
    """Process a single ZIP file and return a DataFrame with the combined data."""
    all_data = []
    processed_dates = {'NSE': set(), 'BSE': set()}
    
    try:
        with zipfile.ZipFile(zip_path, 'r') as z:
            for csv_file in z.namelist():
                # Get the base filename in lowercase
                csv_filename = os.path.basename(csv_file).lower()
                
                # Check if file matches NSE or BSE pattern (e.g., 20250915_NSE.csv)
                # Explicitly exclude NSEFO files
                if csv_filename.endswith('_nse.csv') and not 'nsefo' in csv_filename:
                    exchange = 'NSE'
                elif csv_filename.endswith('_bse.csv') and not 'bsefo' in csv_filename:
                    exchange = 'BSE'
                else:
                    logger.debug(f"Skipping non-exchange file: {csv_file}")
                    continue
                
                # Extract date from CSV filename (format: YYYYMMDD_NSE.csv or YYYYMMDD_BSE.csv)
                try:
                    # Get date from filename (e.g., 20250915 from 20250915_NSE.csv)
                    date_str = os.path.basename(csv_file).split('_')[0]
                    trade_date = datetime.strptime(date_str, '%Y%m%d').date()
                except (ValueError, IndexError) as e:
                    logger.error(f"Could not extract date from filename: {zip_path}")
                    continue
                
                try:
                    with z.open(csv_file) as f:
                        # Try reading with different encodings
                        try:
                            df = pd.read_csv(f, encoding='utf-8')
                        except UnicodeDecodeError:
                            f.seek(0)
                            df = pd.read_csv(f, encoding='latin1')
                        
                        initial_count = len(df)  # Get initial record count
                        
                        # Standardize column names
                        df.columns = [col.strip().lower() for col in df.columns]
                        
                        # Map columns based on exchange
                        if exchange == 'NSE':
                            column_mapping = {
                                'symbol': 'symbol',
                                'series': 'series',
                                'open': 'open_price',
                                'high': 'high',
                                'low': 'low',
                                'close': 'close',
                                'last': 'last_price',
                                'prevclose': 'prev_close',
                                'tottrdqty': 'total_traded_qty',
                                'tottrdval': 'total_traded_val',
                                'totaltrades': 'total_trades',
                                'isin': 'isin'
                            }
                        else:  # BSE
                            column_mapping = {
                                'sc_code': 'symbol',
                                'sc_name': 'company_name',
                                'open': 'open_price',
                                'high': 'high',
                                'low': 'low',
                                'close': 'close',
                                'last': 'last_price',
                                'prevclose': 'prev_close',
                                'no_trades': 'total_trades',
                                'no_of_shrs': 'total_traded_qty',
                                'net_turnov': 'total_traded_val',
                                'isin_code': 'isin'
                            }
                            df['series'] = 'EQ'  # Default series for BSE
                        
                        # Rename columns
                        df = df.rename(columns=column_mapping)
                        
                        # Add exchange and timestamp
                        df['exchange'] = exchange
                        df['timestamp'] = trade_date
                        
                        # Track processed dates
                        processed_dates[exchange].add(trade_date.strftime('%Y-%m-%d'))
                        
                        # Select only the columns we want
                        columns = ['symbol', 'series', 'open_price', 'high', 'low', 'close', 
                                 'last_price', 'prev_close', 'total_traded_qty', 'total_traded_val',
                                 'total_trades', 'isin', 'exchange', 'timestamp']
                        
                        # Only keep columns that exist in the DataFrame
                        columns = [col for col in columns if col in df.columns]
                        df = df[columns]
                        
                        record_count = len(df)
                        logger.info(f"Processed {record_count} records from {os.path.basename(zip_path)} - {csv_file} ({exchange})")
                        
                        all_data.append(df)
                        
                except Exception as e:
                    logger.error(f"Error processing {csv_file}: {str(e)}")
                    continue
        
        if all_data:
            combined_df = pd.concat(all_data, ignore_index=True)
            total_records = len(combined_df)
            
            # Log summary
            logger.info(f"\n{'='*50}")
            logger.info(f"Summary for {os.path.basename(zip_path)}:")
            
            # Log exchange-wise summary
            for exchange, dates in processed_dates.items():
                if dates:
                    date_range = f"from {min(dates)} to {max(dates)}" if len(dates) > 1 else f"for {dates.pop()}"
                    logger.info(f"  - {exchange}: {len([d for d in all_data if not d.empty and d['exchange'].iloc[0] == exchange])} files {date_range}")
            
            logger.info(f"Total records processed: {total_records}")
            logger.info(f"{'='*50}\n")
            
            return combined_df
        return None
        
    except Exception as e:
        logger.error(f"Error processing ZIP file {zip_path}: {str(e)}")
        return None

def create_master_csv(zip_dir, output_file, max_files=None):
    """Create a master CSV file from all ZIP files in the directory."""
    try:
        logger.info(f"Processing ZIP files from: {zip_dir}")
        logger.info(f"Output file: {output_file}")
        # Get list of ZIP files
        zip_files = sorted(Path(zip_dir).glob('*.zip'), key=lambda x: x.name)
        
        if not zip_files:
            logger.error(f"No ZIP files found in {zip_dir}")
            return False
        
        if max_files:
            zip_files = zip_files[:max_files]
            logger.info(f"Processing {max_files} out of {len(zip_files)} ZIP files")
        
        all_data = []
        
        # Process each ZIP file
        for i, zip_file in enumerate(zip_files, 1):
            logger.info(f"\nProcessing file {i}/{len(zip_files)}: {zip_file.name}")
            df = process_zip_file(zip_file, os.path.dirname(output_file))
            
            if df is not None and not df.empty:
                all_data.append(df)
                logger.info(f"Added {len(df)} records from {zip_file.name}")
        
        if not all_data:
            logger.error("No data found in any of the ZIP files")
            return False
        
        # Combine all data
        master_df = pd.concat(all_data, ignore_index=True)
        
        # Save to CSV
        master_df.to_csv(output_file, index=False)
        logger.info(f"\nSuccessfully created master CSV with {len(master_df):,} total records")
        logger.info(f"Saved to: {output_file}")
        return True
        
    except Exception as e:
        logger.error(f"Error creating master CSV: {str(e)}", exc_info=True)
        return False

if __name__ == "__main__":
    # Default paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    default_zip_dir = os.path.join(script_dir, '..', 'data', 'bhavcopies')
    default_output = os.path.join(script_dir, '..', 'data', 'master_bhavcopy.csv')
    
    # Get command line arguments
    if len(sys.argv) > 1:
        zip_dir = sys.argv[1]
    else:
        zip_dir = default_zip_dir
    
    if len(sys.argv) > 2:
        output_file = sys.argv[2]
    else:
        output_file = default_output
    
    # Create output directory if it doesn't exist
    os.makedirs(os.path.dirname(os.path.abspath(output_file)), exist_ok=True)
    
    # Create master CSV from all ZIP files
    success = create_master_csv(zip_dir, output_file, max_files=None)  # Process all files
    
    if success:
        print(f"Master CSV created successfully: {output_file}")
        sys.exit(0)
    else:
        print("Failed to create master CSV. Check the log file for details.")
        sys.exit(1)
