"""
SignalRepository — trading signals and opportunities.
Uses table reflection for prices_bhavcopy_2.
"""

from sqlalchemy.orm import Session
from sqlalchemy import Table, MetaData
from typing import List, Dict, Any, Optional

from backend.models import Company
from repositories.probability_repository import ProbabilityRepository


class SignalRepository:
    def __init__(self, db: Session):
        self.db = db
        engine = db.get_bind()
        metadata = MetaData()
        self.prices_table = Table(
            "prices_bhavcopy_2",
            metadata,
            autoload_with=engine,
        )
        self.prob_repo = ProbabilityRepository(db)

    def get_signals(self, limit: int = 50) -> List[Dict[str, Any]]:
        companies = self.db.query(Company).limit(limit * 2).all()
        signals = []
        for c in companies:
            symbol = c.nse_code or c.bse_code
            if not symbol:
                continue
            prob = self.prob_repo.get_by_symbol(symbol)
            if not prob:
                continue

            prices = (
                self.db.query(self.prices_table)
                .filter(self.prices_table.c.company_id == c.id)
                .order_by(self.prices_table.c.timestamp.desc())
                .limit(60)
                .all()
            )
            if not prices:
                continue

            closes = [float(p.close) for p in reversed(prices) if p.close is not None]
            ma50 = sum(closes[-50:]) / min(50, len(closes)) if closes else 0
            current = closes[-1] if closes else 0

            rating = "hold"
            confidence = 50
            if prob.get("normalizedScore"):
                score = prob["normalizedScore"]
                if score >= 75:
                    rating = "strong_buy"
                elif score >= 60:
                    rating = "buy"
                elif score >= 50:
                    rating = "watch"
                elif score >= 42:
                    rating = "neutral"
                elif score >= 30:
                    rating = "weak"
                else:
                    rating = "sell"
                confidence = min(100, int(score))

            signals.append({
                "id": f"signal-{symbol}",
                "symbol": symbol,
                "rating": rating,
                "confidence": "medium",
                "confidenceScore": confidence,
                "risk": "medium",
                "riskScore": 50,
                "reason": f"Probability score: {prob.get('normalizedScore', 0):.1f}",
                "evidence": [],
                "targetPrice": round(current * 1.08, 2) if current else None,
                "stopLoss": round(current * 0.95, 2) if current else None,
                "horizonDays": prob.get("expectedHoldingPeriod", 21),
            })

        return signals

    def get_signal(self, symbol: str) -> Optional[Dict[str, Any]]:
        signals = self.get_signals(limit=200)
        return next((s for s in signals if s["symbol"] == symbol), None)

    def get_opportunities(self) -> List[Dict[str, Any]]:
        signals = self.get_signals(limit=200)
        return [s for s in signals if s["rating"] in ("strong_buy", "buy")]
