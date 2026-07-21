#!/usr/bin/env python3
"""Standalone breadth signals refresh script.

Usage:
    python refresh_breadth_signals.py
    python refresh_breadth_signals.py --dma-periods 20,50,100,200 --horizons 1,5,21,63,126,256
"""

import argparse
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from api_server.repositories.breadth_analytics_repository import BreadthAnalyticsRepository, DEFAULT_DMA_PERIODS, DEFAULT_HORIZONS


def parse_args():
    parser = argparse.ArgumentParser(description="Refresh company_breadth_signals table")
    parser.add_argument("--dma-periods", type=str, default=",".join(map(str, DEFAULT_DMA_PERIODS)),
                        help="Comma-separated DMA periods (default: 20,50,100,200)")
    parser.add_argument("--horizons", type=str, default=",".join(map(str, DEFAULT_HORIZONS)),
                        help="Comma-separated horizons (default: 1,5,21,63,126,256)")
    return parser.parse_args()


def main():
    args = parse_args()
    dma_periods = [int(x.strip()) for x in args.dma_periods.split(",") if x.strip()]
    horizons = [int(x.strip()) for x in args.horizons.split(",") if x.strip()]

    database_url = os.environ.get("DATABASE_URL", "postgresql://stockuser:stockpass@localhost:5432/stockdb")
    engine = create_engine(database_url)
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        repo = BreadthAnalyticsRepository(session)
        print(f"Refreshing breadth signals: dma_periods={dma_periods}, horizons={horizons}")
        results = repo.refresh_cache(dma_periods=dma_periods, horizons=horizons)
        print(f"Done. Companies processed: {len(results)}")
    finally:
        session.close()


if __name__ == "__main__":
    main()
