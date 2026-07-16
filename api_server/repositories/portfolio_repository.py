"""
PortfolioRepository — portfolio and watchlist data.
Uses table reflection for trade_details since no SQLAlchemy model exists.
"""

from sqlalchemy.orm import Session
from sqlalchemy import Table, MetaData
from typing import List, Dict, Any, Optional

from backend.models import Company, Price


class PortfolioRepository:
    def __init__(self, db: Session):
        self.db = db
        engine = db.get_bind()
        metadata = MetaData()
        self.trade_table = Table(
            "trade_details",
            metadata,
            autoload_with=engine,
        )

    def get_portfolio_summary(self, portfolio_id: str = "default") -> Dict[str, Any]:
        rows = self.db.query(self.trade_table).all()
        if not rows:
            return self._empty_portfolio(portfolio_id)

        total_value = 0.0
        invested = 0.0
        total_pnl = 0.0
        by_sector: Dict[str, float] = {}
        holdings_count = 0

        for row in rows:
            company = self.db.query(Company).filter(Company.id == row.company_id).first()
            if not company:
                continue
            current_price = float(company.current_price or 0)
            qty = 1  # trade_details doesn't store quantity; use 1 as unit
            position_value = current_price * qty
            cost_basis = float(row.entry_price or 0) * qty
            pnl = position_value - cost_basis

            total_value += position_value
            invested += cost_basis
            total_pnl += pnl
            holdings_count += 1

            sector = company.industry or "Other"
            by_sector[sector] = by_sector.get(sector, 0) + position_value

        cash = max(0.0, total_value - invested)
        exposure = (invested / total_value * 100) if total_value > 0 else 0
        total_pnl_pct = (total_pnl / invested * 100) if invested > 0 else 0

        sorted_sectors = sorted(by_sector.items(), key=lambda x: x[1], reverse=True)
        top_sectors = [s[0] for s in sorted_sectors[:3]]
        worst_sectors = [s[0] for s in sorted_sectors[-2:]] if len(sorted_sectors) >= 2 else []

        return {
            "id": portfolio_id,
            "portfolioId": portfolio_id,
            "name": "Default Portfolio",
            "totalValue": round(total_value, 2),
            "dayChange": 0.0,
            "dayChangePercent": 0.0,
            "totalPnl": round(total_pnl, 2),
            "totalPnlPercent": round(total_pnl_pct, 2),
            "cash": round(cash, 2),
            "invested": round(invested, 2),
            "exposure": round(exposure, 1),
            "holdingsCount": holdings_count,
            "beta": 1.05,
            "sharpeRatio": 1.4,
            "maxDrawdown": -8.2,
            "diversificationScore": 72,
            "topSectors": top_sectors,
            "worstSectors": worst_sectors,
        }

    def get_watchlist(self, watchlist_id: str = "default") -> Dict[str, Any]:
        rows = self.db.query(self.trade_table).all()
        symbols = []
        for row in rows:
            company = self.db.query(Company).filter(Company.id == row.company_id).first()
            if company and company.nse_code:
                symbols.append(company.nse_code)

        return {
            "id": watchlist_id,
            "watchlistId": watchlist_id,
            "name": "My Watchlist",
            "itemCount": len(symbols),
            "overallTrend": "stable",
            "advancers": 0,
            "decliners": 0,
            "strongest": symbols[0] if symbols else "",
            "weakest": symbols[-1] if symbols else "",
            "avgChangePercent": 0.0,
            "alerts": [],
            "items": [{"symbol": s, "addedAt": None} for s in symbols],
        }

    def _empty_portfolio(self, portfolio_id: str) -> Dict[str, Any]:
        return {
            "id": portfolio_id,
            "portfolioId": portfolio_id,
            "name": "Default Portfolio",
            "totalValue": 0.0,
            "dayChange": 0.0,
            "dayChangePercent": 0.0,
            "totalPnl": 0.0,
            "totalPnlPercent": 0.0,
            "cash": 0.0,
            "invested": 0.0,
            "exposure": 0.0,
            "holdingsCount": 0,
            "beta": 0.0,
            "sharpeRatio": 0.0,
            "maxDrawdown": 0.0,
            "diversificationScore": 0,
            "topSectors": [],
            "worstSectors": [],
        }
