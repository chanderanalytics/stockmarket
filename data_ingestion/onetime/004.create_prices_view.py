"""
005.create_prices_view.py - Creates a compatibility view for prices_bhavcopy_2
"""
import logging
import os
import sys
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

def create_prices_view():
    """Create or replace the prices_v2_compatible view."""
    try:
        # Get database URL from environment variable or use default
        database_url = os.getenv('DATABASE_URL', 'postgresql://stockuser:stockpass@localhost:5432/stockdb')
        logger.info("Connecting to database...")
        engine = create_engine(database_url)
        
        # SQL to create or replace the view
        create_view_sql = """
        CREATE OR REPLACE VIEW prices_v2_compatible AS
        SELECT 
            id,
            symbol,
            series,
            open,
            high,
            low,
            close,
            last_price,
            prev_close,
            total_traded_quantity,
            total_traded_value,
            timestamp AS date,
            total_trades,
            isin,
            exchange,
            company_name_updated AS company_name,
            company_id,
            created_at,
            updated_at
        FROM 
            prices_bhavcopy_2;
        """
        
        with engine.begin() as conn:
            logger.info("Creating/updating prices_v2_compatible view...")
            conn.execute(text(create_view_sql))
            logger.info("Successfully created/updated prices_v2_compatible view")
            
        return True
        
    except SQLAlchemyError as e:
        logger.error(f"Error creating view: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return False

if __name__ == "__main__":
    success = create_prices_view()
    sys.exit(0 if success else 1)
