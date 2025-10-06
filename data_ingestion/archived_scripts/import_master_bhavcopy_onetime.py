"""
Script to import bhavcopy price data from a master CSV file into the database (bulk inserts).
"""

import os
import sys
import logging
import chardet
from datetime import datetime
import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# Add parent directory to path for module imports
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Logging setup
log_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
log_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'log')
os.makedirs(log_dir, exist_ok=True)

logging.basicConfig(
    filename=os.path.join(log_dir, f'import_bhavcopy_{log_datetime}.log'),
    filemode='a',
    format='%(asctime)s %(levelname)s: %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Database configuration
try:
    from config import DATABASE_URL
    DB_URL = DATABASE_URL
except ImportError:
    DB_URL = 'postgresql://stockuser:stockpass@localhost:5432/stockdb'

engine = create_engine(DB_URL, pool_pre_ping=True)
Session = sessionmaker(bind=engine)


def create_table():
    """Drop and recreate the prices_bhavcopy table as a normal table."""
    try:
        with engine.begin() as conn:
            logger.info("Dropping existing prices_bhavcopy table if it exists...")
            conn.execute(text("DROP TABLE IF EXISTS prices_bhavcopy CASCADE;"))
            
            logger.info("Creating new prices_bhavcopy table...")
            # Create table
            conn.execute(text("""
                CREATE TABLE prices_bhavcopy (
                    id SERIAL PRIMARY KEY,
                    symbol VARCHAR(50) NOT NULL,
                    series VARCHAR(10) NOT NULL,
                    open_price NUMERIC(12, 2) NOT NULL,
                    high NUMERIC(12, 2) NOT NULL,
                    low NUMERIC(12, 2) NOT NULL,
                    close NUMERIC(12, 2) NOT NULL,
                    last_price NUMERIC(12, 2) NOT NULL,
                    prev_close NUMERIC(12, 2) NOT NULL,
                    total_traded_qty BIGINT NOT NULL,
                    total_traded_val NUMERIC(20, 2) NOT NULL,
                    total_trades BIGINT NOT NULL,
                    isin VARCHAR(20) NOT NULL,
                    exchange VARCHAR(10) NOT NULL,
                    timestamp DATE NOT NULL,
                    CONSTRAINT unique_bhavcopy_entry UNIQUE (symbol, timestamp)
                )
            """))
            
            # Create indexes
            conn.execute(text("""
                CREATE INDEX idx_prices_bhavcopy_timestamp ON prices_bhavcopy (timestamp);
                CREATE INDEX idx_prices_bhavcopy_symbol ON prices_bhavcopy (symbol);
            
                COMMENT ON TABLE prices_bhavcopy IS 'Non-partitioned table for storing bhavcopy price data';
                
                ANALYZE prices_bhavcopy;
            """))
            logger.info("Successfully recreated prices_bhavcopy as a normal table with indexes")
        return True
    except Exception as e:
        logger.error(f"Error recreating table: {e}", exc_info=True)
        raise


def import_bhavcopy_from_csv(csv_file_path, chunk_size=100000):
    """Import bhavcopy data from master CSV file into the database (bulk insert per chunk)."""
    if not os.path.isfile(csv_file_path):
        logger.error(f"CSV file not found: {csv_file_path}")
        return False

    # Metrics
    metrics = {
        'total_rows': 0,
        'imported_rows': 0,
        'skipped_rows': 0,
        'errors': 0,
        'database_errors': 0,
        'csv_valid_rows': 0,
        'csv_invalid_rows': 0,
        'start_time': datetime.now(),
        'end_time': None,
        'duration': None,
        'error_messages': {}
    }

    def log_error(err_type, msg):
        metrics['errors'] += 1
        metrics['error_messages'].setdefault(err_type, []).append(msg)
        logger.error(f"{err_type}: {msg}")

    # Count rows
    with open(csv_file_path, 'r', encoding="utf-8", errors="ignore") as f:
        metrics['total_rows'] = sum(1 for _ in f) - 1

    logger.info(f"Importing {metrics['total_rows']} rows from {csv_file_path}")

    # Detect encoding
    with open(csv_file_path, 'rb') as f:
        file_encoding = chardet.detect(f.read(10000))['encoding'] or "utf-8"
    logger.info(f"Detected file encoding: {file_encoding}")

    # Required columns
    required_columns = [
        'symbol', 'series', 'open_price', 'high', 'low', 'close', 'last_price',
        'prev_close', 'total_traded_qty', 'total_traded_val', 'total_trades',
        'isin', 'exchange', 'timestamp'
    ]

    try:
        create_table()

        chunk_iter = pd.read_csv(
            csv_file_path,
            chunksize=chunk_size,
            dtype=str,
            encoding=file_encoding,
            parse_dates=['timestamp'],
            infer_datetime_format=True,
            on_bad_lines='skip'
        )

        insert_sql = text(f"""
            INSERT INTO prices_bhavcopy
            ({", ".join(required_columns)})
            VALUES ({", ".join(f":{c}" for c in required_columns)})
            ON CONFLICT DO NOTHING
        """)

        with engine.begin() as conn:
            for chunk_num, chunk in enumerate(chunk_iter, 1):
                logger.info(f"Processing chunk {chunk_num} ({len(chunk)} rows)")

                # Drop invalid
                chunk = chunk.dropna(subset=['symbol', 'timestamp', 'close'])
                metrics['csv_valid_rows'] += len(chunk)

                # Convert timestamp from Unix epoch nanoseconds to date
                try:
                    # First convert to datetime (handling nanoseconds by converting to seconds first)
                    chunk['timestamp'] = pd.to_datetime(
                        chunk['timestamp'].astype('int64') // 10**9,  # Convert ns to s
                        unit='s',
                        errors='coerce'  # Will set invalid parsing to NaT
                    )
                    
                    # Check for any failed conversions
                    if chunk['timestamp'].isna().any():
                        failed_count = chunk['timestamp'].isna().sum()
                        log_error("INVALID_TIMESTAMP", f"Chunk {chunk_num}: Failed to parse {failed_count} timestamps")
                        metrics['csv_invalid_rows'] += failed_count
                        
                        # Only keep rows where timestamp conversion succeeded
                        chunk = chunk.dropna(subset=['timestamp'])
                        if len(chunk) == 0:
                            continue
                    
                    # Convert to date and ensure it's not in the future
                    chunk['timestamp'] = chunk['timestamp'].dt.date
                    today = datetime.now().date()
                    future_dates = chunk['timestamp'] > today
                    if future_dates.any():
                        future_count = future_dates.sum()
                        log_error("FUTURE_DATE", f"Chunk {chunk_num}: Found {future_count} future dates, setting to today")
                        chunk.loc[future_dates, 'timestamp'] = today
                    
                    metrics['csv_valid_rows'] += len(chunk)
                    
                except Exception as e:
                    log_error("TIMESTAMP_ERROR", f"Chunk {chunk_num}: {str(e)}")
                    metrics['csv_invalid_rows'] += len(chunk)
                    continue

                # Clean numeric columns
                numeric_int_cols = ["total_traded_qty", "total_trades"]
                numeric_float_cols = ["open_price", "high", "low", "close", "last_price",
                                    "prev_close", "total_traded_val"]

                for col in numeric_int_cols:
                    if col in chunk.columns:
                        chunk[col] = pd.to_numeric(chunk[col], errors="coerce").fillna(0).astype("Int64")  # pandas nullable int

                for col in numeric_float_cols:
                    if col in chunk.columns:
                        chunk[col] = pd.to_numeric(chunk[col], errors="coerce").fillna(0).astype(float)

                # Convert to list of dicts
                records = chunk.to_dict(orient='records')

                if not records:
                    continue

                try:
                    conn.execute(insert_sql, records)  # bulk insert
                    metrics['imported_rows'] += len(records)
                except Exception as e:
                    metrics['database_errors'] += len(records)
                    log_error("DB_BULK_INSERT_ERROR", f"Chunk {chunk_num}: {e}")

        metrics['end_time'] = datetime.now()
        metrics['duration'] = metrics['end_time'] - metrics['start_time']

        summary = f"""
========================================
Bhavcopy Import Summary
========================================
Source file: {csv_file_path}
Rows in CSV: {metrics['total_rows']}
Rows imported: {metrics['imported_rows']}
Skipped rows: {metrics['skipped_rows']}
Database errors: {metrics['database_errors']}
Invalid rows: {metrics['csv_invalid_rows']}
Duration: {metrics['duration']}
========================================
"""
        logger.info(summary)
        print(summary)
        return metrics['database_errors'] == 0

    except Exception as e:
        log_error("FATAL", str(e))
        return False


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Import bhavcopy data from master CSV")
    parser.add_argument("csv_file", nargs="?", default=os.path.join(os.path.dirname(__file__), "..", "data", "master_bhavcopy.csv"))
    parser.add_argument("--chunk-size", type=int, default=50000)
    args = parser.parse_args()

    success = import_bhavcopy_from_csv(args.csv_file, args.chunk_size)
    sys.exit(0 if success else 1)