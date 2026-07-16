"""
ProbabilityRepository — maps wide probability table to ProbabilityWideRow.
Uses SQLAlchemy table reflection to avoid defining 397-column model.
"""

from sqlalchemy.orm import Session
from sqlalchemy import Table, MetaData
from typing import List, Dict, Any, Optional


class ProbabilityRepository:
    def __init__(self, db: Session):
        self.db = db
        engine = db.get_bind()
        metadata = MetaData()
        self.prob_table = Table(
            "merged_price_baseline_probabilities_wide",
            metadata,
            autoload_with=engine,
        )

    def get_by_symbol(self, symbol: str) -> Optional[Dict[str, Any]]:
        row = (
            self.db.query(self.prob_table)
            .filter(self.prob_table.c.nse_code == symbol)
            .first()
        )
        if not row:
            return None
        return self._row_to_dict(row)

    def get_all(self, limit: int = 100) -> List[Dict[str, Any]]:
        rows = self.db.query(self.prob_table).limit(limit).all()
        return [self._row_to_dict(r) for r in rows]

    def _row_to_dict(self, row) -> Dict[str, Any]:
        return_buckets = []
        for from_val in [3, 7, 10, 15]:
            for to_val, threshold in [(5, 0.05), (7, 0.07), (10, 0.1)]:
                col = f"price_return_{from_val}_{threshold}"
                prob = getattr(row, col, None)
                if prob is not None:
                    return_buckets.append({
                        "from": from_val,
                        "to": to_val,
                        "probability": float(prob),
                    })

        return {
            "symbol": row.nse_code or row.company_id,
            "returnBuckets": return_buckets,
            "volatility21d": float(getattr(row, "volatility21d", 15) or 15),
            "volatility63d": float(getattr(row, "volatility63d", 20) or 20),
            "pvol21d": float(getattr(row, "pvol21d", 15) or 15),
            "pvol252d": float(getattr(row, "pvol252d", 12) or 12),
            "volumeTrend": float(getattr(row, "volume_trend", 0) or 0),
        }
