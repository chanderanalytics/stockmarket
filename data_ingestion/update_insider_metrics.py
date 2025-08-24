""" 
Script to calculate and update cumulative insider trading metrics by company and stakeholder.
"""
import sys
import os
import traceback
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from sqlalchemy import create_engine, func, text
from sqlalchemy.orm import sessionmaker
from backend.models import Base, InsiderTrade
from datetime import datetime, date
import logging
import argparse
from sqlalchemy.dialects.postgresql import insert

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('insider_metrics_update.log')
    ]
)
logger = logging.getLogger(__name__)

# Database connection
DATABASE_URL = 'postgresql://stockuser:stockpass@localhost:5432/stockdb'
try:
    engine = create_engine(DATABASE_URL)
    Session = sessionmaker(bind=engine)
    logger.info("Successfully connected to the database")
except Exception as e:
    logger.error(f"Failed to connect to the database: {e}")
    sys.exit(1)

# Set up logging
log_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
logging.basicConfig(
    filename=f'log/insider_metrics_update_{log_datetime}.log',
    filemode='a',
    format='%(asctime)s %(levelname)s: %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

class InsiderMetricsUpdater:
    def __init__(self, session):
        self.session = session
        
    def create_tables(self):
        """Create the cumulative_insider_metrics table if it doesn't exist."""
        try:
            logger.info("Checking if cumulative_insider_metrics table exists...")
            
            # Check if table exists
            result = self.session.execute(
                text(
                    """
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables 
                        WHERE table_name = 'cumulative_insider_metrics'
                    )
                    """
                )
            ).scalar()
            
            if not result:
                logger.info("Creating cumulative_insider_metrics table...")
                
                # Create table if not exists
                self.session.execute(text(
                    """
                    CREATE TABLE cumulative_insider_metrics (
                        id SERIAL PRIMARY KEY,
                        company_name TEXT NOT NULL,
                        symbol TEXT NOT NULL,
                        acquirer_disposer TEXT NOT NULL,
                        category TEXT NOT NULL,
                        total_buy_quantity BIGINT DEFAULT 0,
                        total_buy_value NUMERIC(20, 2) DEFAULT 0,
                        total_sell_quantity BIGINT DEFAULT 0,
                        total_sell_value NUMERIC(20, 2) DEFAULT 0,
                        last_trade_date DATE,
                        last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        UNIQUE(company_name, symbol, acquirer_disposer, category)
                    )
                    """
                ))
                
                # Create index for faster lookups
                self.session.execute(text(
                    """
                    CREATE INDEX idx_cumulative_insider_metrics_company 
                    ON cumulative_insider_metrics(company_name, symbol)
                    """
                ))
                
                self.session.execute(text(
                    """
                    CREATE INDEX idx_cumulative_insider_metrics_stakeholder 
                    ON cumulative_insider_metrics(acquirer_disposer, category)
                    """
                ))
                
                self.session.commit()
                logger.info("Successfully created cumulative_insider_metrics table and indexes")
            else:
                logger.info("cumulative_insider_metrics table already exists")
            
            return True
            
        except Exception as e:
            self.session.rollback()
            logger.error(f"Error in create_tables: {str(e)}\n{traceback.format_exc()}")
            return False
    
    def update_metrics(self):
        """Calculate and update cumulative insider trading metrics."""
        try:
            logger.info("Starting metrics update...")
            
            # Get the most recent trade date in the metrics table
            result = self.session.execute(
                text(
                    """
                    SELECT MAX(last_trade_date) as max_date 
                    FROM cumulative_insider_metrics
                    """
                )
            ).fetchone()
            
            last_processed_date = result[0] if result and result[0] else None
            
            # Query for new trades since last processed date
            query = self.session.query(InsiderTrade)
            if last_processed_date:
                logger.info(f"Last processed date: {last_processed_date}")
                query = query.filter(InsiderTrade.date > last_processed_date)
            else:
                logger.info("No previous processing date found, will process all trades")
            
            # Get count of new trades
            new_trades_count = query.count()
            
            if new_trades_count == 0:
                if last_processed_date:
                    logger.info(f"No new trades to process. Last processed date: {last_processed_date}")
                else:
                    logger.info("No insider trades found in the database.")
                return True
            
            logger.info(f"Found {new_trades_count} new trades to process...")
            
            # Process trades in batches
            batch_size = 500
            offset = 0
            total_batches = (new_trades_count + batch_size - 1) // batch_size
            
            while offset < new_trades_count:
                batch = query.offset(offset).limit(batch_size).all()
                batch_num = (offset // batch_size) + 1
                
                if not batch:
                    logger.warning("No more trades to process in batch")
                    break
                    
                logger.info(f"Processing batch {batch_num}/{total_batches} ({len(batch)} trades)")
                
                try:
                    self._process_batch(batch)
                    offset += len(batch)
                except Exception as e:
                    logger.error(f"Error processing batch {batch_num}: {str(e)}\n{traceback.format_exc()}")
                    self.session.rollback()
                    return False
            
            logger.info("Successfully updated cumulative insider metrics.")
            return True
            
        except Exception as e:
            self.session.rollback()
            logger.error(f"Error in update_metrics: {str(e)}\n{traceback.format_exc()}")
            return False
    
    def _process_batch(self, trades):
        """Process a batch of trades and update metrics."""
        try:
            logger.debug(f"Processing batch of {len(trades)} trades")
            
            for trade in trades:
                try:
                    # Skip trades without required fields
                    if not all([trade.company, trade.symbol, trade.acquirer_disposer, trade.category, trade.date]):
                        logger.warning(f"Skipping trade with missing required fields: {vars(trade)}")
                        continue
                    
                    # Determine if it's a buy or sell
                    is_buy = trade.regulation.upper() in ['BUY', 'ACQUISITION']
                    
                    # Calculate trade value if possible
                    trade_value = 0
                    shares_traded = 0
                    
                    if hasattr(trade, 'trade_value') and trade.trade_value:
                        try:
                            trade_value = float(trade.trade_value)
                        except (ValueError, TypeError) as ve:
                            logger.warning(f"Invalid trade_value for trade {trade.id}: {trade.trade_value}")
                            trade_value = 0
                    
                    if hasattr(trade, 'shares_traded') and trade.shares_traded:
                        try:
                            shares_traded = int(trade.shares_traded)
                        except (ValueError, TypeError) as ve:
                            logger.warning(f"Invalid shares_traded for trade {trade.id}: {trade.shares_traded}")
                            shares_traded = 0
                    
                    # Skip if no shares were traded
                    if shares_traded == 0:
                        logger.warning(f"Skipping trade {trade.id} with 0 shares traded")
                        continue
                    
                    # Log trade details
                    logger.debug(f"Processing trade: {trade.id}, Company: {trade.company} ({trade.symbol}), "
                                 f"Type: {'BUY' if is_buy else 'SELL'}, Shares: {shares_traded}, "
                                 f"Value: {trade_value}, Date: {trade.date}")
                    
                    # Update or insert metrics using upsert
                    stmt = text("""
                    INSERT INTO cumulative_insider_metrics 
                    (company_name, symbol, acquirer_disposer, category, 
                     total_buy_quantity, total_buy_value,
                     total_sell_quantity, total_sell_value, last_trade_date)
                    VALUES (:company, :symbol, :acquirer, :category,
                            :buy_qty, :buy_val, :sell_qty, :sell_val, :trade_date)
                    ON CONFLICT (company_name, symbol, acquirer_disposer, category) 
                    DO UPDATE SET
                        total_buy_quantity = cumulative_insider_metrics.total_buy_quantity + EXCLUDED.total_buy_quantity,
                        total_buy_value = cumulative_insider_metrics.total_buy_value + EXCLUDED.total_buy_value,
                        total_sell_quantity = cumulative_insider_metrics.total_sell_quantity + EXCLUDED.total_sell_quantity,
                        total_sell_value = cumulative_insider_metrics.total_sell_value + EXCLUDED.total_sell_value,
                        last_trade_date = GREATEST(cumulative_insider_metrics.last_trade_date, EXCLUDED.last_trade_date),
                        last_updated = CURRENT_TIMESTAMP
                    RETURNING id;
                    """)
                    
                    params = {
                        'company': trade.company,
                        'symbol': trade.symbol,
                        'acquirer': trade.acquirer_disposer,
                        'category': trade.category,
                        'buy_qty': shares_traded if is_buy else 0,
                        'buy_val': trade_value if is_buy else 0,
                        'sell_qty': 0 if is_buy else shares_traded,
                        'sell_val': 0 if is_buy else trade_value,
                        'trade_date': trade.date
                    }
                    
                    # Execute and commit each trade individually for better error isolation
                    result = self.session.execute(stmt, params)
                    self.session.commit()
                    
                    logger.debug(f"Processed trade {trade.id}, affected row ID: {result.scalar() if result else 'N/A'}")
                    
                except Exception as trade_error:
                    logger.error(f"Error processing trade {getattr(trade, 'id', 'unknown')}: {str(trade_error)}\n{traceback.format_exc()}")
                    self.session.rollback()
                    # Continue with next trade even if one fails
                    continue
            
            return True
            
        except Exception as e:
            logger.error(f"Error in _process_batch: {str(e)}\n{traceback.format_exc()}")
            return False

def main():
    parser = argparse.ArgumentParser(description='Update cumulative insider trading metrics')
    parser.add_argument('--init', action='store_true', help='Initialize the metrics table')
    parser.add_argument('--batch-size', type=int, default=500, help='Number of records to process in each batch')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging')
    args = parser.parse_args()
    
    # Set log level based on debug flag
    log_level = logging.DEBUG if args.debug else logging.INFO
    logger.setLevel(log_level)
    
    logger.info("=" * 80)
    logger.info(f"Starting insider metrics update at {datetime.now()}")
    logger.info(f"Arguments: {vars(args)}")
    
    session = None
    success = False
    
    try:
        # Create database session
        session = Session()
        logger.info("✅ Database session created successfully")
        
        # Initialize updater
        updater = InsiderMetricsUpdater(session)
        
        if args.init:
            logger.info("⚙️ Initializing cumulative insider metrics table...")
            if not updater.create_tables():
                logger.error("❌ Failed to initialize tables")
                return 1
            logger.info("✅ Table initialized successfully")
        
        logger.info("🔄 Updating cumulative insider metrics...")
        start_time = datetime.now()
        
        # Update metrics
        if not updater.update_metrics():
            logger.error("❌ Failed to update metrics")
            return 1
        
        # Log completion
        elapsed = (datetime.now() - start_time).total_seconds()
        logger.info(f"✅ Update completed in {elapsed:.2f} seconds")
        success = True
        
    except Exception as e:
        logger.error(f"❌ Unhandled error in main: {str(e)}\n{traceback.format_exc()}")
        if session:
            session.rollback()
        return 1
    finally:
        if session:
            try:
                session.close()
                logger.info("✅ Database session closed")
            except Exception as e:
                logger.error(f"❌ Error closing database session: {str(e)}")
        
        if success:
            logger.info("✨ Script completed successfully!")
        else:
            logger.error("❌ Script completed with errors")
        
        logger.info(f"Finished at {datetime.now()}")
        logger.info("=" * 80)
    
    return 0 if success else 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        logger.warning("\n⚠️  Script interrupted by user")
        sys.exit(1)
    except Exception as e:
        logger.error(f"\n❌ Unhandled exception: {str(e)}\n{traceback.format_exc()}")
        sys.exit(1)
