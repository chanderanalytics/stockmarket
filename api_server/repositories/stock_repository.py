"""
StockRepository — stock-level data.
Uses table reflection for prices_bhavcopy_2 since no SQLAlchemy model exists.
"""

from sqlalchemy.orm import Session
from sqlalchemy import Table, MetaData
from typing import List, Dict, Any, Optional

from backend.models import Company


class StockRepository:
    def __init__(self, db: Session):
        self.db = db
        engine = db.get_bind()
        metadata = MetaData()
        self.prices_table = Table(
            "prices_bhavcopy_2",
            metadata,
            autoload_with=engine,
        )

    def find_by_symbol(self, symbol: str) -> Optional[Dict[str, Any]]:
        company = (
            self.db.query(Company)
            .filter((Company.nse_code == symbol) | (Company.bse_code == symbol))
            .first()
        )
        if not company:
            return None
        return self._company_to_dict(company)

    def get_prices(self, company_id: int, days: int = 252) -> List[Dict[str, Any]]:
        prices = (
            self.db.query(self.prices_table)
            .filter(self.prices_table.c.company_id == company_id)
            .order_by(self.prices_table.c.timestamp.desc())
            .limit(days)
            .all()
        )
        return [
            {
                "date": p.timestamp.isoformat() if p.timestamp else None,
                "open": float(p.open) if p.open else None,
                "high": float(p.high) if p.high else None,
                "low": float(p.low) if p.low else None,
                "close": float(p.close) if p.close else None,
                "volume": float(p.total_traded_quantity) if p.total_traded_quantity else None,
            }
            for p in reversed(prices)
        ]

    def get_snapshot(self, symbol: str) -> Optional[Dict[str, Any]]:
        company = (
            self.db.query(Company)
            .filter((Company.nse_code == symbol) | (Company.bse_code == symbol))
            .first()
        )
        if not company:
            return None

        prices = (
            self.db.query(self.prices_table)
            .filter(self.prices_table.c.company_id == company.id)
            .order_by(self.prices_table.c.timestamp.desc())
            .limit(252)
            .all()
        )

        latest = prices[0] if prices else None
        prev = prices[1] if len(prices) > 1 else latest

        closes = [float(p.close) for p in reversed(prices) if p.close is not None]
        current = closes[-1] if closes else 0
        prev_close = closes[-2] if len(closes) > 1 else current
        price_change = current - prev_close
        price_change_pct = (price_change / prev_close * 100) if prev_close != 0 else 0

        ma50 = sum(closes[-50:]) / min(50, len(closes)) if closes else 0
        ma200 = sum(closes[-200:]) / min(200, len(closes)) if closes else 0
        price_vs_ma50 = ((current - ma50) / ma50 * 100) if ma50 != 0 else 0
        price_vs_ma200 = ((current - ma200) / ma200 * 100) if ma200 != 0 else 0

        high_52w = max(closes[-252:]) if len(closes) >= 252 else (max(closes) if closes else 0)
        low_52w = min(closes[-252:]) if len(closes) >= 252 else (min(closes) if closes else 0)

        return {
            "id": f"stock-{symbol}",
            "symbol": company.nse_code or company.bse_code or symbol,
            "name": company.name,
            "exchange": company.exchange or "NSE",
            "sector": company.industry or "Other",
            "industry": company.industry or "",
            "currentPrice": float(current),
            "priceChange": round(price_change, 2),
            "priceChangePercent": round(price_change_pct, 2),
            "marketCap": float(company.market_capitalization or 0),
            "volume": float(latest.total_traded_quantity) if latest and latest.total_traded_quantity else 0,
            "avgVolume": 0,
            "dayHigh": float(latest.high) if latest and latest.high else current,
            "dayLow": float(latest.low) if latest and latest.low else current,
            "week52High": float(high_52w),
            "week52Low": float(low_52w),
            "peRatio": float(company.price_to_earning) if company.price_to_earning else None,
            "pbRatio": float(company.price_to_book_value) if company.price_to_book_value else None,
            "dividendYield": float(company.dividend_yield) if company.dividend_yield else None,
            "trend": {
                "id": f"trend-{symbol}",
                "symbol": company.nse_code or symbol,
                "priceTrend": "up" if price_change_pct >= 0 else "down",
                "trendStrength": "strong" if abs(price_change_pct) > 2 else "moderate",
                "movingAverages": {
                    "ma20": round(sum(closes[-20:]) / min(20, len(closes)), 2) if closes else 0,
                    "ma50": round(ma50, 2),
                    "ma100": round(sum(closes[-100:]) / min(100, len(closes)), 2) if closes else 0,
                    "ma200": round(ma200, 2),
                    "priceVsMA20": round(((current - (sum(closes[-20:]) / min(20, len(closes)))) / (sum(closes[-20:]) / min(20, len(closes))) * 100), 2) if closes and sum(closes[-20:]) / min(20, len(closes)) != 0 else 0,
                    "priceVsMA50": round(price_vs_ma50, 2),
                    "priceVsMA100": round(((current - (sum(closes[-100:]) / min(100, len(closes)))) / (sum(closes[-100:]) / min(100, len(closes))) * 100), 2) if closes and sum(closes[-100:]) / min(100, len(closes)) != 0 else 0,
                    "priceVsMA200": round(price_vs_ma200, 2),
                },
                "momentum": 0,
                "volatility": 0,
                "supportLevel": round(current * 0.95, 2),
                "resistanceLevel": round(current * 1.05, 2),
            },
        }

    def _company_to_dict(self, company: Company) -> Dict[str, Any]:
        return {
            "id": company.id,
            "name": company.name,
            "nse_code": company.nse_code,
            "bse_code": company.bse_code,
            "industry": company.industry,
            "current_price": float(company.current_price) if company.current_price else None,
            "market_capitalization": float(company.market_capitalization) if company.market_capitalization else None,
        }
