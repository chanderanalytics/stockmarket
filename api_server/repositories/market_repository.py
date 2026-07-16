"""
MarketRepository — market-level aggregates.
"""

from sqlalchemy.orm import Session
from sqlalchemy import func, and_
from typing import List, Optional
from datetime import date

from backend.models import Company, Price, Index, IndexPrice
from repositories.base import BaseRepository


class MarketRepository(BaseRepository):
    def __init__(self, db: Session):
        self.db = db

    def get_indices(self) -> List[dict]:
        indices = self.db.query(Index).all()
        return [
            {
                "id": idx.id,
                "name": idx.name,
                "ticker": idx.ticker,
                "region": idx.region,
                "description": idx.description,
            }
            for idx in indices
        ]

    def get_index_prices(self, ticker: str, days: int = 252) -> List[dict]:
        idx = self.db.query(Index).filter(Index.ticker == ticker).first()
        if not idx:
            return []
        prices = (
            self.db.query(IndexPrice)
            .filter(IndexPrice.index_id == idx.id)
            .order_by(IndexPrice.date.desc())
            .limit(days)
            .all()
        )
        return [
            {
                "date": p.date.isoformat(),
                "open": float(p.open) if p.open else None,
                "high": float(p.high) if p.high else None,
                "low": float(p.low) if p.low else None,
                "close": float(p.close) if p.close else None,
                "volume": int(p.volume) if p.volume else None,
            }
            for p in reversed(prices)
        ]

    def get_market_overview(self) -> dict:
        total_companies = self.db.query(func.count(Company.id)).scalar()
        total_market_cap = self.db.query(func.coalesce(func.sum(Company.market_capitalization), 0)).scalar()
        avg_pe = self.db.query(func.coalesce(func.avg(Company.price_to_earning), 0)).scalar()

        sector_counts = (
            self.db.query(Company.industry, func.count(Company.id))
            .group_by(Company.industry)
            .all()
        )
        sector_distribution = {sector: count for sector, count in sector_counts if sector}

        def safe_float(value):
            if value is None:
                return 0.0
            if isinstance(value, float):
                if value != value or abs(value) == float("inf"):
                    return 0.0
            return float(value)

        return {
            "total_companies": total_companies,
            "total_market_cap": safe_float(total_market_cap),
            "avg_pe_ratio": safe_float(avg_pe),
            "sector_distribution": sector_distribution,
        }

    def get_top_gainers(self, limit: int = 10) -> List[dict]:
        def safe_float(value):
            if value is None:
                return None
            if isinstance(value, float):
                if value != value or abs(value) == float("inf"):
                    return None
            return float(value)

        companies = (
            self.db.query(Company)
            .filter(Company.return_over_1year.isnot(None))
            .order_by(Company.return_over_1year.desc())
            .limit(limit)
            .all()
        )
        return [
            {
                "id": c.id,
                "name": c.name,
                "nse_code": c.nse_code,
                "current_price": safe_float(c.current_price),
                "return_1y": safe_float(c.return_over_1year),
            }
            for c in companies
        ]

    def get_top_losers(self, limit: int = 10) -> List[dict]:
        def safe_float(value):
            if value is None:
                return None
            if isinstance(value, float):
                if value != value or abs(value) == float("inf"):
                    return None
            return float(value)

        companies = (
            self.db.query(Company)
            .filter(Company.return_over_1year.isnot(None))
            .order_by(Company.return_over_1year.asc())
            .limit(limit)
            .all()
        )
        return [
            {
                "id": c.id,
                "name": c.name,
                "nse_code": c.nse_code,
                "current_price": safe_float(c.current_price),
                "return_1y": safe_float(c.return_over_1year),
            }
            for c in companies
        ]
