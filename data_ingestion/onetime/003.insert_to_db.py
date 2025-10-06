"""
Part 2: Insert CSV into database
Takes a processed CSV file and inserts it into the prices_bhavcopy_2 table using upsert.
"""

import pandas as pd
import os
import sys
import logging
from pathlib import Path
import psycopg2
from sqlalchemy import create_engine, text

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('insert_to_db.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Database configuration
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://stockuser:stockpass@localhost:5432/stockdb')

def create_table_if_not_exists(engine, table_name):
    """Create the prices_chavcopy_2 table if it doesn't exist."""
    create_table_sql = f"""
    CREATE TABLE IF NOT EXISTS {table_name} (
        id SERIAL PRIMARY KEY,
        symbol VARCHAR(50) NOT NULL,
        series VARCHAR(10),
        open NUMERIC(12, 2),
        high NUMERIC(12, 2),
        low NUMERIC(12, 2),
        close NUMERIC(12, 2),
        last_price NUMERIC(12, 2),
        prev_close NUMERIC(12, 2),
        total_traded_quantity NUMERIC(18, 2),
        total_traded_value NUMERIC(18, 2),
        timestamp DATE,
        total_trades NUMERIC(18, 2),
        isin VARCHAR(50),
        exchange VARCHAR(10),
        company_name_updated VARCHAR(255),
        company_id INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (symbol, timestamp, exchange)
    );
    """
    
    index_sql = f"""
    CREATE INDEX IF NOT EXISTS idx_{table_name}_symbol ON {table_name}(symbol);
    CREATE INDEX IF NOT EXISTS idx_{table_name}_timestamp ON {table_name}(timestamp);
    CREATE INDEX IF NOT EXISTS idx_{table_name}_company_id ON {table_name}(company_id);
    """
    
    with engine.begin() as conn:
        logger.info(f"Creating table {table_name} if it doesn't exist...")
        conn.execute(text(create_table_sql))
        logger.info("Creating indexes...")
        conn.execute(text(index_sql))

def insert_csv_to_database(csv_file, table_name='prices_bhavcopy_2'):
    """
    Insert the processed CSV data into the database table using upsert.
    """
    try:
        logger.info(f"Connecting to database...")
        engine = create_engine(DATABASE_URL)
        
        # Create table if it doesn't exist
        create_table_if_not_exists(engine, table_name)
        
        logger.info(f"Inserting data from {csv_file} into {table_name}...")
        
        chunk_size = 1000000  # Process 100,000 rows at a time
        total_rows = 0
        
        for chunk in pd.read_csv(csv_file, chunksize=chunk_size):
            logger.info(f"Processing chunk with {len(chunk)} rows...")
            
            
            
            # Rename columns to match database schema
            chunk = chunk.rename(columns={
                'open_price': 'open',
                'total_traded_val': 'total_traded_value',
                'total_traded_qty': 'total_traded_quantity',
                'company_name': 'company_name_updated'
            })

                    # Convert and clean numeric columns
            numeric_columns = {
                'open': (12, 2, 9999999999),      # Max for NUMERIC(12,2)
                'high': (12, 2, 9999999999),
                'low': (12, 2, 9999999999),
                'close': (12, 2, 9999999999),
                'last_price': (12, 2, 9999999999),
                'prev_close': (12, 2, 9999999999),
                'total_traded_quantity': (18, 2, 9999999999999999),  # Max for NUMERIC(18,2)
                'total_traded_value': (18, 2, 9999999999999999),
                'total_trades': (18, 2, 9999999999999999)
            }

            for col, (precision, scale, max_val) in numeric_columns.items():
                if col in chunk.columns:
                    # Convert to numeric, coerce errors to NaN
                    chunk[col] = pd.to_numeric(chunk[col], errors='coerce')
                    # Cap values at max_val
                    chunk[col] = chunk[col].clip(upper=max_val)

            # Convert NaN to None for database insertion
            chunk = chunk.where(pd.notnull(chunk), None)

            # Convert to list of dictionaries for bulk insert
            records = chunk.to_dict('records')
            # Ensure company_id is present in each record
            for record in records:
                if 'company_id' not in record or pd.isna(record.get('company_id')):
                    record['company_id'] = None
            
            # Prepare the upsert query
            upsert_query = text(f"""
                INSERT INTO {table_name} (
                    symbol, series, open, high, low, close,
                    last_price, prev_close, total_traded_quantity, total_traded_value,
                    total_trades, isin, exchange, timestamp, company_name_updated, company_id
                ) VALUES (
                    :symbol, :series, :open, :high, :low, :close,
                    :last_price, :prev_close, :total_traded_quantity, :total_traded_value,
                    :total_trades, :isin, :exchange, :timestamp, :company_name_updated, :company_id
                )
                ON CONFLICT (symbol, timestamp, exchange) DO UPDATE SET
                    open = EXCLUDED.open,
                    high = EXCLUDED.high,
                    low = EXCLUDED.low,
                    close = EXCLUDED.close,
                    last_price = EXCLUDED.last_price,
                    prev_close = EXCLUDED.prev_close,
                    total_traded_quantity = EXCLUDED.total_traded_quantity,
                    total_traded_value = EXCLUDED.total_traded_value,
                    total_trades = EXCLUDED.total_trades,
                    isin = EXCLUDED.isin,
                    company_name_updated = EXCLUDED.company_name_updated,
                    company_id = EXCLUDED.company_id,
                    updated_at = CURRENT_TIMESTAMP
            """)
            
            # Execute upsert in batches to avoid memory issues
            batch_size = 50000
            for i in range(0, len(records), batch_size):
                batch = records[i:i + batch_size]
                with engine.begin() as conn:
                    conn.execute(upsert_query, batch)
                logger.info(f"Processed batch {i//batch_size + 1}")
            
            total_rows += len(chunk)
            logger.info(f"Processed {total_rows:,} rows so far...")
        
        logger.info(f"Successfully inserted {total_rows:,} rows into {table_name}")
        return True
        
    except Exception as e:
        logger.error(f"Error inserting to database: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python insert_to_db.py <csv_file> [table_name]")
        print("Example: python insert_to_db.py data/db_ready.csv prices_bhavcopy_2")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    table_name = sys.argv[2] if len(sys.argv) > 2 else 'prices_bhavcopy_2'
    
    if not os.path.exists(csv_file):
        logger.error(f"CSV file does not exist: {csv_file}")
        sys.exit(1)
    
    logger.info("Starting database insertion...")
    success = insert_csv_to_database(csv_file, table_name)
    
    if success:
        logger.info(f"Successfully inserted data into {table_name}")
        sys.exit(0)
    else:
        logger.error("Failed to insert data into database. Check the log for details.")
        sys.exit(1)

if __name__ == "__main__":
    main()
