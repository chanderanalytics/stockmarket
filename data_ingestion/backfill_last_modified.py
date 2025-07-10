"""
One-off script to backfill last_modified with today for all relevant tables where last_modified is NULL.
"""

import sys
import os
import logging
from datetime import date

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from sqlalchemy import create_engine, update
from sqlalchemy.orm import sessionmaker
from backend.models import Company, Price, CorporateAction, Index, IndexPrice

DATABASE_URL = 'postgresql://stockuser:stockpass@localhost:5432/stockdb'
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)

log_datetime = date.today().strftime('%Y%m%d')
logging.basicConfig(
    filename=f'log/backfill_last_modified_{log_datetime}.log',
    filemode='a',
    format='%(asctime)s %(levelname)s: %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

if __name__ == '__main__':
    session = Session()
    today = date.today()
    try:
        logger.info('Starting backfill of last_modified fields...')
        # Companies
        updated = session.query(Company).filter(Company.last_modified == None).update({Company.last_modified: today}, synchronize_session=False)
        logger.info(f'Companies updated: {updated}')
        print(f'Companies updated: {updated}')
        # Prices
        updated = session.query(Price).filter(Price.last_modified == None).update({Price.last_modified: today}, synchronize_session=False)
        logger.info(f'Prices updated: {updated}')
        print(f'Prices updated: {updated}')
        # Corporate Actions
        updated = session.query(CorporateAction).filter(CorporateAction.last_modified == None).update({CorporateAction.last_modified: today}, synchronize_session=False)
        logger.info(f'CorporateActions updated: {updated}')
        print(f'CorporateActions updated: {updated}')
        # Indices
        updated = session.query(Index).filter(Index.last_modified == None).update({Index.last_modified: today}, synchronize_session=False)
        logger.info(f'Indices updated: {updated}')
        print(f'Indices updated: {updated}')
        # Index Prices
        # session.query(IndexPrice).filter(IndexPrice.last_modified == None).update({IndexPrice.last_modified: today}, synchronize_session=False)
        session.commit()
        logger.info('Backfill complete!')
        print('Backfill complete!')
    except Exception as e:
        session.rollback()
        logger.error(f'Error during backfill: {e}')
        print(f'Error during backfill: {e}')
    finally:
        session.close() 