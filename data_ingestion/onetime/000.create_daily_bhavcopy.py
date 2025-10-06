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

def process_csv_file(csv_path):
    """Process a single CSV file and return a DataFrame with the data."""
    try:
        # Get the base filename in lowercase
        csv_filename = os.path.basename(csv_path).lower()
        
        # Check if file matches NSE or BSE pattern (e.g., 20250915_NSE.csv)
        # Explicitly exclude NSEFO files
        if csv_filename.endswith('_nse.csv') and 'nsefo' not in csv_filename:
            exchange = 'NSE'
        elif csv_filename.endswith('_bse.csv') and 'bsefo' not in csv_filename:
            exchange = 'BSE'
        else:
            logger.debug(f"Skipping non-exchange file: {csv_path}")
            return None
        
        # Extract date from CSV filename (format: YYYYMMDD_NSE.csv or YYYYMMDD_BSE.csv)
        try:
            # Get date from filename (e.g., 20250915 from 20250915_NSE.csv)
            date_str = os.path.basename(csv_path).split('_')[0]
            trade_date = datetime.strptime(date_str, '%Y%m%d').date()
        except (ValueError, IndexError) as e:
            logger.error(f"Could not extract date from filename: {csv_path}")
            return None
        
        try:
            # Try reading with different encodings
            try:
                df = pd.read_csv(csv_path, encoding='utf-8')
            except UnicodeDecodeError:
                df = pd.read_csv(csv_path, encoding='latin1')
            
            # Standardize column names
            df.columns = [str(col).strip().lower() for col in df.columns]
            
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
            
            # Select only the columns we want
            columns = ['symbol', 'series', 'open_price', 'high', 'low', 'close', 
                     'last_price', 'prev_close', 'total_traded_qty', 'total_traded_val',
                     'total_trades', 'isin', 'exchange', 'timestamp']
            
            # Only keep columns that exist in the DataFrame
            columns = [col for col in columns if col in df.columns]
            df = df[columns]
            
            record_count = len(df)
            logger.info(f"Processed {record_count} records from {os.path.basename(csv_path)} ({exchange})")
            
            return df
            
        except Exception as e:
            logger.error(f"Error processing {csv_path}: {str(e)}")
            return None
            
    except Exception as e:
        logger.error(f"Error processing CSV file {csv_path}: {str(e)}")
        return None

def create_master_csv(base_dir, output_file, max_files=None):
    """Create a master CSV file from all CSV files in the bhavcopies directory."""
    try:
        logger.info(f"Processing CSV files from: {base_dir}")
        logger.info(f"Output file: {output_file}")
        
        # Define paths to NSE and BSE subdirectories
        bhavcopies_dir = Path(base_dir)
        nse_dir = bhavcopies_dir / 'nse'
        bse_dir = bhavcopies_dir / 'bse'
        
        if not bhavcopies_dir.exists():
            logger.error(f"bhavcopies directory not found at: {bhavcopies_dir}")
            return False
            
        # Get NSE files
        nse_files = []
        if nse_dir.exists():
            for ext in ('*.csv', '*.CSV'):
                nse_files.extend(nse_dir.glob(ext))
            # Filter out NSEFO files
            nse_files = [f for f in nse_files if 'NSEFO' not in f.name.upper()]
        
        # Get BSE files
        bse_files = []
        if bse_dir.exists():
            for ext in ('*.csv', '*.CSV'):
                bse_files.extend(bse_dir.glob(ext))
            # Filter out BSEFO files
            bse_files = [f for f in bse_files if 'BSEFO' not in f.name.upper()]
        
        # Combine and sort all files
        csv_files = nse_files + bse_files
        
        if not csv_files:
            logger.error(f"No valid exchange CSV files found in {nse_dir} or {bse_dir}")
            return False
        csv_files = sorted(csv_files, key=lambda x: x.name)
        
        if max_files:
            csv_files = csv_files[:max_files]
            logger.info(f"Processing {max_files} out of {len(csv_files)} CSV files")
        # Initialize data storage
        all_data = []
        processed_dates = {'NSE': set(), 'BSE': set()}
        exchange_counts = {'NSE': 0, 'BSE': 0}
        
        # Process each CSV file
        for i, csv_file in enumerate(csv_files, 1):
            logger.info(f"\nProcessing file {i}/{len(csv_files)}: {csv_file.name}")
            df = process_csv_file(csv_file)
            
            if df is not None and not df.empty:
                all_data.append(df)
                # Track processed dates and counts
                exchange = df['exchange'].iloc[0]
                date = df['timestamp'].iloc[0].strftime('%Y-%m-%d')
                processed_dates[exchange].add(date)
                exchange_counts[exchange] += 1
                logger.info(f"Added {len(df)} records from {csv_file.name}")
        
        if not all_data:
            logger.error("No valid data found in any of the CSV files")
            return False
        # Log summary of processed files
        logger.info("\n" + "="*50)
        logger.info("Processing Summary:")
        for exchange in ['NSE', 'BSE']:
            if processed_dates[exchange]:
                dates = sorted(processed_dates[exchange])
                date_range = f"{dates[0]} to {dates[-1]}" if len(dates) > 1 else dates[0]
                logger.info(f"{exchange}: {exchange_counts[exchange]} files, {len(dates)} unique dates ({date_range})")
        logger.info(f"Total records: {sum(len(df) for df in all_data):,}")
        logger.info("="*50)
        
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
    # Default paths - point to stockmkt/data/
    project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    default_csv_dir = os.path.join(project_root, 'data')
    default_output = os.path.join(project_root, 'data', 'master_bhavcopy.csv')
    
    # Get command line arguments
    if len(sys.argv) > 1:
        csv_dir = sys.argv[1]
    else:
        csv_dir = default_csv_dir
    
    if len(sys.argv) > 2:
        output_file = sys.argv[2]
    else:
        output_file = default_output
    
    # Create output directory if it doesn't exist
    os.makedirs(os.path.dirname(os.path.abspath(output_file)), exist_ok=True)
    
    # Create master CSV from all CSV files
    success = create_master_csv(csv_dir, output_file, max_files=None)  # Process all files
    
    if success:
        print(f"Master CSV created successfully: {output_file}")
        sys.exit(0)
    else:
        print("Failed to create master CSV. Check the log file for details.")
        sys.exit(1)
