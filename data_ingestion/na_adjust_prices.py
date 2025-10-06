#!/usr/bin/env python3
"""
Adjust stock prices for corporate actions (splits, bonuses, etc.)

This script adjusts historical price data for corporate actions to ensure
consistent time series analysis. It updates the 'adj_close' column in the
prices table.
"""
import logging
from datetime import datetime
from typing import Dict, List, Tuple, Optional
import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import SQLAlchemyError
import re
import os
import itertools

# Configure logging
log_file = 'adjust_prices.log'
# Ensure the log file is writable
if os.path.exists(log_file):
    if not os.access(log_file, os.W_OK):
        print(f"Error: Log file {log_file} is not writable. Please check permissions.")
        exit(1)

# Set up logging to file with DEBUG level
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),  # Default level is WARNING
        logging.FileHandler(log_file, mode='w', encoding='utf-8')  # All levels to file
    ]
)

# Set the root logger level to DEBUG
logging.getLogger().setLevel(logging.DEBUG)

# Set console handler to INFO level
for handler in logging.getLogger().handlers:
    if isinstance(handler, logging.StreamHandler):
        handler.setLevel(logging.INFO)
logger = logging.getLogger(__name__)

# --- Database Connection ---
db_uri = "postgresql://stockuser:stockpass@localhost:5432/stockdb"
logger.info(f"Connecting to database: {db_uri}")
try:
    engine = create_engine(db_uri)
    Session = sessionmaker(bind=engine)
    logger.info("Database engine created successfully.")
except Exception as e:
    logger.error(f"Failed to create database engine: {e}", exc_info=True)
    exit(1)
# -------------------------

class PriceAdjuster:
    def __init__(self):
        """Initialize the price adjuster with database connection."""
        self.engine = engine
        self.Session = Session
        
    def clear_tables(self):
        """Clear the prices_adjusted and split_factors tables."""
        try:
            with self.engine.connect() as conn:
                # Clear prices_adjusted
                conn.execute(text("TRUNCATE TABLE prices_adjusted CASCADE"))
                # Clear split_factors
                conn.execute(text("TRUNCATE TABLE split_factors CASCADE"))
                conn.commit()
                logger.info("Successfully cleared prices_adjusted and split_factors tables")
        except Exception as e:
            logger.error(f"Error clearing tables: {e}")
            raise
    
    def get_corporate_actions(self) -> pd.DataFrame:
        """Fetch all corporate actions from the database."""
        logger.info("Attempting to connect to the database...")
        try:
            # First, log the distinct types of corporate actions for debugging
            type_check_query = """
            SELECT type, COUNT(*) as count 
            FROM corporate_actions 
            GROUP BY type 
            ORDER BY count DESC;
            """
            
            logger.info("Executing type check query...")
            with self.engine.connect() as conn:
                logger.info("Connection established, executing query...")
                type_counts = pd.read_sql(type_check_query, conn)
                logger.info(f"Corporate action types and counts:\n{type_counts.to_string()}")
            
            # Now get the actual corporate actions
            query = """
            SELECT id, company_id, company_code, company_name, date, type, details
            FROM corporate_actions
            ORDER BY company_id, date
            """
            
            logger.info("Fetching all corporate actions...")
            with self.engine.connect() as conn:
                df = pd.read_sql(query, conn)
                logger.info(f"Fetched {len(df)} corporate actions")
                return df
                
        except Exception as e:
            logger.error(f"Error in get_corporate_actions: {e}", exc_info=True)
            raise
    
    def parse_split_ratio(self, details: str) -> Optional[Tuple[float, float]]:
        """Parse split ratio from details string."""
        if not details:
            return None
            
        # Clean up the details string
        details = details.strip().lower()
        
        # Handle common formats:
        # 1. "5.0:1 split" -> (5.0, 1)
        # 2. "1.8:1 split" -> (1.8, 1)
        # 3. "1:5" -> (1, 5)
        # 4. "1 split" -> (1, 1)
        
        # Try to match patterns like "5.0:1", "1:5", "1 split", etc.
        patterns = [
            r'([\d\.]+)[:]([\d\.]+)\s*split',  # Matches 5.0:1 split, 1:5 split
            r'([\d\.]+)\s*split',                # Matches 1 split, 5 split
            r'([\d\.]+)[:/\s]+([\d\.]+)',       # Matches 1:2, 1/2, 1.0:2.0, 1 2
            r'([\d\.]+)\s*into\s*([\d\.]+)',   # Matches 1 into 2
            r'sub-division.+?rs\s*([\d\.]+).+?rs\s*([\d\.]+)', # Matches sub-division from Rs.10 to Rs.2
            r'consolidation.+?rs\s*([\d\.]+).+?rs\s*([\d\.]+)', # Matches consolidation from Rs.2 to Rs.10
        ]
        
        for pattern in patterns:
            match = re.search(pattern, details, re.IGNORECASE)
            if match:
                try:
                    groups = match.groups()
                    if len(groups) == 2:
                        a, b = map(float, groups)
                        if a > 0 and b > 0:
                            return (a, b)
                    elif len(groups) == 1:
                        # Handle cases like "1 split" which means 1:1
                        a = float(groups[0])
                        if a > 0:
                            return (a, 1.0)
                except (ValueError, TypeError) as e:
                    logger.debug(f"Error parsing pattern '{pattern}' with details '{details}': {e}")
                    continue
        
        logger.warning(f"Could not parse split ratio from: {details}")
        return None
    
    def parse_bonus_ratio(self, details: str) -> Optional[Tuple[float, float]]:
        """Parse bonus ratio from details string."""
        if not details:
            return None
            
        # Try to match patterns like "1:1", "1 for 1", "1 bonus share for 1 held"
        patterns = [
            r'(\d+)[:/ ]+(\d+)',  # Matches 1:1, 1/1, 1 1
            r'(\d+)\s*(?:for|:)\s*(\d+)',  # Matches 1 for 1, 1:1
            r'(\d+)\s*(?:bonus share|share)',  # Matches 1 bonus share
        ]
        
        for pattern in patterns:
            match = re.search(pattern, details.lower())
            if match:
                try:
                    if len(match.groups()) == 2:
                        a, b = map(float, match.groups())
                        if a > 0 and b > 0:
                            return (a, b)
                    else:
                        # For patterns that only match one number (e.g., "1 bonus share")
                        a = float(match.group(1))
                        return (a, 1)  # Assume 1:1 ratio if only one number is found
                except (ValueError, TypeError):
                    continue
        
        logger.warning(f"Could not parse bonus ratio from: {details}")
        return None
    
    def calculate_combined_split_factors(self, split_factors: list) -> dict:
        """
        Calculate the cumulative split factors that need to be applied to each price point.
        
        For example, with splits:
        - 2023-11-02: 1.8:1 (factor=0.555556)
        - 2025-06-12: 5:1 (factor=0.2)
        
        The cumulative factor for prices before 2023-11-02 should be 0.2 * 0.555556 = 0.111111
        The cumulative factor for prices between 2023-11-02 and 2025-06-12 should be 0.2
        
        Args:
            split_factors: List of (split_date, from_ratio, to_ratio, split_factor) tuples
            
        Returns:
            Dictionary with split dates as keys and cumulative split factors to be applied
            to all prices before that date
        """
        if not split_factors:
            return {}
            
        # Sort splits by date in descending order (most recent first)
        sorted_splits = sorted(split_factors, key=lambda x: x[0], reverse=True)
        
        # Calculate the cumulative product of all split factors
        cumulative_factor = 1.0
        for _, _, _, factor in sorted_splits:
            cumulative_factor *= factor
            
        # Now create the result dictionary with the correct cumulative factors
        result = {}
        current_factor = 1.0
        
        # Process splits in chronological order (oldest first)
        for date, _, _, factor in sorted(split_factors, key=lambda x: x[0]):
            # The factor for this date is the cumulative factor up to this point
            result[date] = cumulative_factor / current_factor
            # Update the current factor for the next iteration
            current_factor *= factor
            
        return result
        
    def get_company_prices(self, company_id: int) -> pd.DataFrame:
        """Fetch all historical prices for a given company."""
        # Convert company_id to native Python int if it's a numpy type
        company_id = int(company_id) if hasattr(company_id, 'item') else int(company_id)
        
        query = text("""
        SELECT 
            price_id, company_id, company_code, date,
            open, high, low, close, volume,
            adj_open, adj_high, adj_low, adj_close, adj_volume
        FROM prices_adjusted
        WHERE company_id = :company_id
        ORDER BY date
        """)
        session = self.Session()
        try:
            result = session.execute(query, {'company_id': company_id})
            df = pd.DataFrame(result.fetchall(), columns=result.keys())
            
            # Convert all numeric columns to float to ensure consistent types
            numeric_cols = ['open', 'high', 'low', 'close', 'volume', 'adj_close', 'adjustment_factor']
            for col in numeric_cols:
                if col in df.columns:
                    # Convert to float and handle any potential conversion issues
                    df[col] = pd.to_numeric(df[col], errors='coerce').astype(float)
                    
            # Ensure date is in datetime format
            if 'date' in df.columns:
                df['date'] = pd.to_datetime(df['date']).dt.date
                
            return df
        except Exception as e:
            logger.error(f"Error fetching prices for company {company_id}: {e}")
            raise
        finally:
            session.close()
    
    def adjust_prices(self, df: pd.DataFrame, actions: pd.DataFrame) -> pd.DataFrame:
        """
        Adjust historical prices based on corporate actions.
        Uses combined split factors to efficiently apply all adjustments in one pass.
        
        Args:
            df: DataFrame containing historical prices
            actions: DataFrame containing corporate actions
            
        Returns:
            DataFrame with adjusted prices
        """
        if df.empty:
            return df
            
        # Make a copy to avoid modifying the original
        df = df.copy()
        
        # Initialize adjusted columns with original values
        for col in ['open', 'high', 'low', 'close']:
            df[f'adj_{col}'] = df[col].copy()
        df['adj_volume'] = df['volume'].copy()
        
        # Ensure price_id exists
        if 'price_id' not in df.columns and 'id' in df.columns:
            df['price_id'] = df['id']
        
        # Sort actions by date in descending order (most recent first)
        actions = actions.sort_values('date', ascending=False)
        
        # Process splits to get all split factors
        split_factors = []
        for _, action in actions.iterrows():
            if action['type'].lower() != 'split' or action['date'] > datetime.now().date():
                continue
                
            ratio = self.parse_split_ratio(action['details'])
            if not ratio:
                continue
                
            pre_split, post_split = ratio
            factor = post_split / pre_split
            split_factors.append((action['date'], float(pre_split), float(post_split), float(factor)))
        
        # If no splits, return original data with adjusted columns as is
        if not split_factors:
            return df
            
        # Calculate combined split factors
        combined_factors = self.calculate_combined_split_factors(split_factors)
        
        # Sort split dates in reverse chronological order (most recent first) and take only the most recent
        sorted_splits = sorted(combined_factors.items(), key=lambda x: x[0], reverse=True)
        if not sorted_splits:
            return df
            
        # Take only the most recent split
        most_recent_split = sorted_splits[0]
        logger.info(f"Applying only the most recent split on {most_recent_split[0]} with factor {most_recent_split[1]:.6f}")
        
        # Initialize adjusted columns with original values
        for col in ['open', 'high', 'low', 'close']:
            df[f'adj_{col}'] = df[col]
        df['adj_volume'] = df['volume']
        
        # Create a copy of the original data for logging
        df_original = df.copy()
        
        # Apply only the most recent split
        split_date, factor = most_recent_split
        
        # Apply to all prices before the split date
        mask = df['date'] < split_date
        if mask.any():
            # Get a sample of the data before adjustment
            sample_indices = df[mask].head(3).index
            
            # Apply the factor to all price columns
            for col in ['open', 'high', 'low', 'close']:
                df.loc[mask, f'adj_{col}'] = df.loc[mask, f'adj_{col}'] * factor
            
            # Adjust volume in the opposite direction
            df.loc[mask, 'adj_volume'] = df.loc[mask, 'adj_volume'] / factor
            
            # Log the adjustments
            logger.info(f"Applied factor {factor:.6f} to {mask.sum()} rows before {split_date}")
            logger.info("  Sample of adjusted prices (original -> adjusted):")
            
            # Show before/after for the sample rows
            for idx in sample_indices:
                orig_row = df_original.loc[idx]
                adj_row = df.loc[idx]
                logger.info(f"    Date: {orig_row['date']}")
                logger.info(f"      Close: {orig_row['close']:.2f} -> {adj_row['adj_close']:.2f}")
                logger.info(f"      Volume: {orig_row['volume']:,.0f} -> {adj_row['adj_volume']:,.0f}")
        
        # Store the split factors in the database if we have any
        if 'company_id' in df.columns and not df.empty:
            company_id = df['company_id'].iloc[0]
            if pd.notna(company_id):
                try:
                    self.store_split_factors(company_id, split_factors)
                except Exception as e:
                    logger.error(f"Failed to store split factors for company {company_id}: {e}")
        
        # Define the columns we want in the output
        all_columns = [
            'price_id', 'company_id', 'company_code', 'date',
            'open', 'high', 'low', 'close', 'volume',
            'adj_open', 'adj_high', 'adj_low', 'adj_close', 'adj_volume'
        ]
        
        # Ensure all columns exist with appropriate defaults
        for col in all_columns:
            if col not in df.columns:
                if col in ['open', 'high', 'low', 'close', 'volume',
                         'adj_open', 'adj_high', 'adj_low', 'adj_close', 'adj_volume']:
                    df[col] = 0.0  # Initialize numeric columns with 0
                else:
                    df[col] = None  # Initialize other columns with None
        
        # Use only the columns that exist in the dataframe
        cols = [col for col in all_columns if col in df.columns]
        
        # Sort by date in descending order (most recent first)
        df = df.sort_values('date', ascending=False)
        
        # Ensure company_id and company_code are propagated to all rows
        if 'company_id' in df.columns and df['company_id'].notna().any():
            company_id = df['company_id'].dropna().iloc[0] if df['company_id'].notna().any() else None
            company_code = df['company_code'].dropna().iloc[0] if 'company_code' in df.columns and df['company_code'].notna().any() else None
            
            if company_id is not None:
                df['company_id'] = company_id
            if company_code is not None:
                df['company_code'] = company_code
        
        return df[cols]  # Return with most recent first
    
    def save_adjusted_prices(self, prices: pd.DataFrame) -> int:
        """Save adjusted prices to the prices_adjusted table with correct precision."""
        if prices.empty:
            return 0
            
        # Make a copy to avoid modifying the original dataframe
        df_to_save = prices.copy()
        
        # Ensure we have all required columns with proper types
        numeric_cols = ['open', 'high', 'low', 'close', 'volume']
        for col in numeric_cols:
            if col in df_to_save.columns:
                df_to_save[col] = pd.to_numeric(df_to_save[col], errors='coerce')
        
        # Ensure adjusted columns exist and are numeric
        for col in ['adj_open', 'adj_high', 'adj_low', 'adj_close']:
            if col not in df_to_save.columns:
                # If adj_ columns don't exist, use original values
                base_col = col[4:]  # Remove 'adj_' prefix
                df_to_save[col] = df_to_save[base_col]
            df_to_save[col] = pd.to_numeric(df_to_save[col], errors='coerce')
        
        # Handle adjusted volume
        if 'adj_volume' not in df_to_save.columns:
            df_to_save['adj_volume'] = df_to_save['volume']
        df_to_save['adj_volume'] = pd.to_numeric(df_to_save['adj_volume'], errors='coerce').fillna(0).astype(int)
        
        # Convert price_id to string to prevent bigint overflow
        if 'price_id' in df_to_save.columns:
            df_to_save['price_id'] = df_to_save['price_id'].astype(str)
        
        # Ensure the original volume is integer
        if 'volume' in df_to_save.columns:
            df_to_save['volume'] = df_to_save['volume'].fillna(0).astype(int)
        
        # Log the first few rows of the data being saved
        logger.info("Sample of data being saved to prices_adjusted:")
        for _, row in df_to_save.head(3).iterrows():
            logger.info(f"Date: {row['date']}, "
                      f"Close: {row['close']:.2f}, "
                      f"Adj Close: {row.get('adj_close', 'N/A'):.2f}")
        
        try:
            # Get company_id for deletion
            company_id = int(df_to_save['company_id'].iloc[0])
            
            # Select only the columns that exist in the target table
            table_columns = [
                'price_id', 'company_id', 'company_code', 'company_name', 'date',
                'open', 'high', 'low', 'close', 'volume',
                'adj_open', 'adj_high', 'adj_low', 'adj_close', 'adj_volume'
            ]
            
            # Filter to only include columns that exist in both the dataframe and the table
            columns_to_save = [col for col in table_columns if col in df_to_save.columns]
            
            # Use pandas to_sql for more robust data type handling
            with self.engine.connect() as conn:
                # Start a transaction
                with conn.begin():
                    from sqlalchemy import text
                    # Delete existing records for this company using text() for safety
                    conn.execute(
                        text("DELETE FROM prices_adjusted WHERE company_id = :company_id"),
                        {'company_id': company_id}
                    )
                    
                    # Insert new records using pandas to_sql
                    df_to_save[columns_to_save].to_sql(
                        'prices_adjusted',
                        conn,
                        if_exists='append',
                        index=False,
                        method='multi',
                        chunksize=1000
                    )
            
            logger.info(f"Successfully saved/updated {len(df_to_save)} adjusted prices")
            return len(df_to_save)
            
        except Exception as e:
            logger.error(f"Error saving adjusted prices: {e}", exc_info=True)
            return 0
    
    def process_all_companies(self):
        """Process all companies with corporate actions."""
        try:
            # Get all corporate actions
            actions_df = self.get_corporate_actions()
            logger.info(f"Total corporate actions found: {len(actions_df)}")
            
            if actions_df.empty:
                logger.info("No corporate actions found")
                return
            
            # For debugging: Only process company ID 1960
            company_ids = [1960]
            logger.info(f"Processing only company ID {company_ids[0]} for debugging")
            
            # Process the specified company
            for company_id in company_ids:
                try:
                    logger.info(f"\n{'='*50}")
                    logger.info(f"Processing company ID: {company_id}")
                    
                    # Filter actions for this company
                    company_actions = actions_df[actions_df['company_id'] == company_id]
                    logger.info(f"Found {len(company_actions)} corporate actions for company {company_id}")
                    
                    # Get the company's prices
                    logger.info("Fetching company prices...")
                    prices = self.get_company_prices(company_id)
                    logger.info(f"Retrieved {len(prices)} price records for company {company_id}")
                    
                    if not prices.empty:
                        logger.info(f"Price data range: {prices['date'].min()} to {prices['date'].max()}")
                        logger.info(f"Sample of original prices (first 3 rows):")
                        logger.info(prices[['date', 'close', 'volume']].head(3).to_string())
                    else:
                        logger.warning(f"No price data found for company ID {company_id}")
                        continue
                    
                    # Get stored split factors for this company
                    split_factors = self.get_split_factors(company_id)
                    if split_factors:
                        logger.info(f"\nFound {len(split_factors)} stored split factors for company {company_id}:")
                        for sf in split_factors:
                            logger.info(f"  - {sf[0]}: {sf[1]}:{sf[2]} (factor: {sf[3]:.6f})")
                    else:
                        logger.info("No split factors found for this company.")
                    
                    # Adjust prices for corporate actions
                    logger.info("\nAdjusting prices for corporate actions...")
                    adjusted_prices = self.adjust_prices(prices, company_actions)
                    
                    if adjusted_prices is not None and not adjusted_prices.empty:
                        logger.info("\nSample of adjusted prices (first 3 rows):")
                        logger.info(adjusted_prices[['date', 'close', 'adj_close', 'volume', 'adj_volume']].head(3).to_string())
                        
                        # Save the adjusted prices
                        logger.info("Saving adjusted prices to database...")
                        updated = self.save_adjusted_prices(adjusted_prices)
                        logger.info(f"Successfully saved/updated {updated} adjusted prices for company {company_id}")
                        
                        # Verify the saved data
                        with self.engine.connect() as conn:
                            result = conn.execute(
                                text("SELECT date, close, adj_close, volume, adj_volume FROM prices_adjusted WHERE company_id = :company_id ORDER BY date DESC LIMIT 3"),
                                {'company_id': company_id}
                            )
                            saved_rows = result.fetchall()
                            if saved_rows:
                                logger.info("\nSample of saved adjusted prices (most recent 3 rows):")
                                for row in saved_rows:
                                    logger.info(f"Date: {row[0]}, Close: {row[1]}, Adj Close: {row[2]}, Volume: {row[3]}, Adj Volume: {row[4]}")
                        
                        # Update the company's last_updated timestamp
                        self.update_company_last_updated(company_id)
                        logger.info(f"Updated last_updated timestamp for company {company_id}")
                    else:
                        logger.warning("No adjusted prices to save")
                        
                except Exception as e:
                    logger.error(f"Error processing company {company_id}: {e}", exc_info=True)
                    continue
            
            logger.info("\nPrice adjustment completed for all companies")
            
        except Exception as e:
            logger.error(f"Fatal error in process_all_companies: {e}", exc_info=True)
            raise

    def store_split_factors(self, company_id: int, split_factors: list) -> None:
        """Store split factors in the database.
        
        Args:
            company_id: ID of the company
            split_factors: List of tuples (split_date, from_ratio, to_ratio, split_ratio)
        """
        if not split_factors:
            return
            
        # Convert company_id to native Python int if it's a numpy type
        company_id = int(company_id) if hasattr(company_id, 'item') else int(company_id)
        
        try:
            with self.engine.connect() as conn:
                # First, delete any existing split factors for this company
                delete_sql = """
                DELETE FROM split_factors 
                WHERE company_id = :company_id
                """
                conn.execute(text(delete_sql), {'company_id': company_id})
                
                # Insert new split factors
                insert_sql = """
                INSERT INTO split_factors 
                (company_id, split_date, from_ratio, to_ratio, split_ratio)
                VALUES (:company_id, :split_date, :from_ratio, :to_ratio, :split_ratio)
                """
                
                for split_date, from_ratio, to_ratio, split_ratio in split_factors:
                    conn.execute(
                        text(insert_sql),
                        {
                            'company_id': company_id,
                            'split_date': split_date,
                            'from_ratio': float(from_ratio),
                            'to_ratio': float(to_ratio),
                            'split_ratio': float(split_ratio)
                        }
                    )
                conn.commit()
                logger.info(f"Stored {len(split_factors)} split factors for company {company_id}")
                
        except Exception as e:
            logger.error(f"Error storing split factors for company {company_id}: {e}")
            raise

    def get_split_factors(self, company_id: int) -> list:
        """Retrieve split factors for a company from the database.
        
        Returns:
            List of tuples (split_date, from_ratio, to_ratio, split_ratio)
            sorted by split_date in ascending order (oldest first)
        """
        # Convert company_id to native Python int if it's a numpy type
        company_id = int(company_id) if hasattr(company_id, 'item') else int(company_id)
        
        query = """
        SELECT split_date, from_ratio, to_ratio, split_ratio
        FROM split_factors
        WHERE company_id = :company_id
        ORDER BY split_date ASC
        """
        try:
            with self.engine.connect() as conn:
                result = conn.execute(text(query), {'company_id': company_id})
                return [
                    (row.split_date, row.from_ratio, row.to_ratio, row.split_ratio)
                    for row in result
                ]
        except Exception as e:
            logger.error(f"Error retrieving split factors for company {company_id}: {e}")
            return []

    def update_company_last_updated(self, company_id: int) -> None:
        """Update the last_updated timestamp for a company."""
        update_sql = """
        UPDATE companies 
        SET last_modified = NOW()
        WHERE id = :company_id
        """
        try:
            with self.engine.connect() as conn:
                conn.execute(text(update_sql), {'company_id': company_id})
                conn.commit()
                logger.debug(f"Updated last_updated for company {company_id}")
        except Exception as e:
            logger.error(f"Error updating last_updated for company {company_id}: {e}")
            raise

def main():
    logger.info("--- Starting Price Adjustment Script ---")
    try:
        adjuster = PriceAdjuster()
        adjuster.process_all_companies()
        logger.info("--- Script Finished Successfully ---")
    except Exception as e:
        logger.error(f"Script failed in main(): {e}", exc_info=True)
        print(f"An error occurred. See {log_file} for details.")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())
