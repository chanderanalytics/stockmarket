"""
BreadthRepository — market breadth metrics.
Uses table reflection for prices_bhavcopy_2.
"""

from sqlalchemy.orm import Session
from sqlalchemy import Table, MetaData, func
from typing import List, Dict, Any

from backend.models import Company


class BreadthRepository:
    def __init__(self, db: Session):
        self.db = db
        engine = db.get_bind()
        metadata = MetaData()
        self.prices_table = Table(
            "prices_bhavcopy_2",
            metadata,
            autoload_with=engine,
        )

    def compute_breadth(self) -> Dict[str, Any]:
        companies = self.db.query(Company).all()
        if not companies:
            return {
                "marketParticipationScore": 50,
                "percentageAbove50DMA": 50,
                "percentageAbove200DMA": 50,
                "netAdvances": 0,
                "breadthTrend": "stable",
                "breadthMomentum": "neutral",
                "newHighs": 0,
                "newLows": 0,
                "advanceDeclineRatio": 1.0,
            }

        above_50 = 0
        above_200 = 0
        advancers = 0
        decliners = 0
        new_highs = 0
        new_lows = 0
        total = len(companies)

        sample = companies[:200]
        for c in sample:
            prices = (
                self.db.query(self.prices_table)
                .filter(self.prices_table.c.company_id == c.id)
                .order_by(self.prices_table.c.timestamp.desc())
                .limit(60)
                .all()
            )
            if not prices or len(prices) < 2:
                continue

            closes = [float(p.close) for p in reversed(prices) if p.close is not None]
            current = closes[-1]
            prev = closes[-2]

            ma50 = sum(closes[-50:]) / min(50, len(closes))
            ma200 = sum(closes[-200:]) / min(200, len(closes))

            if current > ma50:
                above_50 += 1
            if current > ma200:
                above_200 += 1

            if current > prev:
                advancers += 1
            else:
                decliners += 1

            high_52w = max(closes) if closes else current
            low_52w = min(closes) if closes else current
            if current >= high_52w * 0.98:
                new_highs += 1
            if current <= low_52w * 1.02:
                new_lows += 1

        participation = (above_50 / len(sample) * 100) if sample else 50
        above_200_pct = (above_200 / len(sample) * 100) if sample else 50
        net_adv = advancers - decliners
        ad_ratio = advancers / decliners if decliners > 0 else 1.0

        if participation >= 55:
            trend = "up"
            momentum = "strong" if participation >= 65 else "neutral"
        elif participation <= 40:
            trend = "down"
            momentum = "weak"
        else:
            trend = "stable"
            momentum = "neutral"

        return {
            "marketParticipationScore": round(participation, 1),
            "percentageAbove50DMA": round(participation, 1),
            "percentageAbove200DMA": round(above_200_pct, 1),
            "netAdvances": net_adv,
            "breadthTrend": trend,
            "breadthMomentum": momentum,
            "newHighs": new_highs,
            "newLows": new_lows,
            "advanceDeclineRatio": round(ad_ratio, 2),
        }
