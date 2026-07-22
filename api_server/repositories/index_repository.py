"""
IndexRepository — indices_with_features and index_prices queries.

Authoritative sources:
  - indices_with_features: latest snapshot per index with OHLCV + returns
  - index_prices: historical time-series OHLCV
"""

from sqlalchemy.orm import Session
from sqlalchemy import Table, MetaData, func, desc, asc
from typing import List, Dict, Any, Optional

RETURN_COLUMNS = [
    "return_1d",
    "return_2d",
    "return_3d",
    "return_4d",
    "return_5d",
    "return_21d",
    "return_63d",
    "return_126d",
    "return_252d",
    "return_504d",
    "return_756d",
    "return_1260d",
    "return_2520d",
]


def _safe_float(value):
    if value is None:
        return None
    if isinstance(value, float):
        if value != value or abs(value) == float("inf"):
            return None
    return float(value)


class IndexRepository:
    def __init__(self, db: Session):
        self.db = db
        engine = db.get_bind()
        metadata = MetaData()
        self.snapshot_table = Table(
            "indices_with_features",
            metadata,
            autoload_with=engine,
        )
        self.price_table = Table(
            "index_prices",
            metadata,
            autoload_with=engine,
        )

    def get_features_snapshot(
        self,
        region: Optional[str] = None,
        limit: int = 200,
        offset: int = 0,
    ) -> Dict[str, Any]:
        c = self.snapshot_table.c
        query = self.db.query(c)
        if region:
            query = query.filter(c.region == region)

        total = query.count()
        rows = query.order_by(c.name).limit(limit).offset(offset).all()

        result = []
        for r in rows:
            item = {
                "name": r.name,
                "ticker": r.ticker,
                "region": r.region,
                "description": r.description,
                "date": r.date.isoformat() if r.date else None,
                "open": _safe_float(r.open),
                "high": _safe_float(r.high),
                "low": _safe_float(r.low),
                "close": _safe_float(r.close),
                "volume": int(r.volume) if r.volume is not None else None,
                "last_modified": r.last_modified.isoformat() if r.last_modified else None,
                "as_of_date": r.as_of_date.isoformat() if hasattr(r, "as_of_date") and r.as_of_date else None,
            }
            for col in RETURN_COLUMNS:
                if hasattr(r, col):
                    item[col] = _safe_float(getattr(r, col))
            result.append(item)

        return {"total": total, "rows": result, "as_of_date": result[0]["as_of_date"] if result else None}

    def get_index_price_history(
        self,
        name: Optional[str] = None,
        ticker: Optional[str] = None,
        days: int = 252,
    ) -> List[Dict[str, Any]]:
        c = self.price_table.c
        query = self.db.query(c)
        if name:
            query = query.filter(c.name == name)
        if ticker:
            query = query.filter(c.ticker == ticker)
        rows = query.order_by(c.date.asc()).limit(days).all()
        return [
            {
                "date": r.date.isoformat() if r.date else None,
                "open": _safe_float(r.open),
                "high": _safe_float(r.high),
                "low": _safe_float(r.low),
                "close": _safe_float(r.close),
                "volume": int(r.volume) if r.volume is not None else None,
            }
            for r in rows
        ]

    def get_regional_strength(self, period: str = "21d") -> Dict[str, Any]:
        c = self.snapshot_table.c
        col = getattr(c, period, None)
        if col is None:
            return {"rows": [], "period": period}

        rows = (
            self.db.query(c.region, func.avg(col).label("avg_return"), func.count(c.id).label("index_count"))
            .filter(c.region.isnot(None))
            .group_by(c.region)
            .all()
        )
        return {
            "period": period,
            "rows": [
                {
                    "region": r.region,
                    "avg_return": _safe_float(r.avg_return),
                    "index_count": r.index_count,
                }
                for r in rows
            ],
        }

    def get_latest_snapshot_date(self) -> Optional[str]:
        c = self.snapshot_table.c
        row = self.db.query(func.max(c.as_of_date).label("max_date")).first()
        return row.max_date.isoformat() if row and row.max_date else None
