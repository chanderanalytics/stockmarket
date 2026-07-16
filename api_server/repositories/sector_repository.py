"""
SectorRepository — sector-level aggregates.
Uses table reflection for prices_bhavcopy_2.
"""

from sqlalchemy.orm import Session
from sqlalchemy import Table, MetaData, func
from typing import List, Dict, Any, Optional

from backend.models import Company


class SectorRepository:
    def __init__(self, db: Session):
        self.db = db
        engine = db.get_bind()
        metadata = MetaData()
        self.prices_table = Table(
            "prices_bhavcopy_2",
            metadata,
            autoload_with=engine,
        )

    def get_sectors(self) -> List[Dict[str, Any]]:
        sectors = (
            self.db.query(Company.industry, func.count(Company.id).label("count"))
            .filter(Company.industry.isnot(None))
            .group_by(Company.industry)
            .all()
        )

        result = []
        for sector_name, count in sectors:
            companies = self.db.query(Company).filter(Company.industry == sector_name).limit(50).all()
            if not companies:
                continue

            total_market_cap = sum(float(c.market_capitalization or 0) for c in companies)
            returns = []
            for c in companies:
                r = self._get_latest_return(c.id)
                if r is not None:
                    returns.append(r)

            avg_return = sum(returns) / len(returns) if returns else 0
            participation = len([r for r in returns if r > 0]) / len(returns) * 100 if returns else 0

            result.append({
                "sector": sector_name,
                "companyCount": count,
                "totalMarketCap": total_market_cap,
                "avgReturn": round(avg_return, 2),
                "participation": round(participation, 1),
                "leadership": avg_return > 1.0,
                "weakening": avg_return < -1.0,
                "rank": 0,
            })

        result.sort(key=lambda x: x["avgReturn"], reverse=True)
        for i, s in enumerate(result):
            s["rank"] = i + 1

        return result

    def _get_latest_return(self, company_id: int) -> Optional[float]:
        prices = (
            self.db.query(self.prices_table)
            .filter(self.prices_table.c.company_id == company_id)
            .order_by(self.prices_table.c.timestamp.desc())
            .limit(2)
            .all()
        )
        if len(prices) < 2:
            return None
        prev = float(prices[1].close or 0)
        curr = float(prices[0].close or 0)
        if prev == 0:
            return None
        return (curr - prev) / prev * 100
