"""
FastAPI backend for Stock Market Dashboard
Serves data from PostgreSQL to the Next.js frontend
"""

from fastapi import FastAPI, HTTPException, Query, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import create_engine, func, and_, or_
from sqlalchemy.orm import sessionmaker, Session
from typing import List, Optional
from datetime import datetime, date, timedelta
import os
import json
from pydantic import BaseModel, ConfigDict

class SafeJSONResponse(JSONResponse):
    def render(self, content) -> bytes:
        def safe_serialize(obj):
            if isinstance(obj, float):
                if obj != obj:  # NaN
                    return None
                if abs(obj) == float('inf'):  # Infinity
                    return None
            return obj
        
        return json.dumps(content, default=safe_serialize).encode('utf-8')

import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from backend.models import (
    Company, Price, HistoricalPrice, CorporateAction,
    ShareholdingPattern, Index, IndexPrice
)

# Database connection
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://stockuser:stockpass@localhost:5432/stockdb"
)

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# FastAPI app
app = FastAPI(
    title="Stock Market Dashboard API",
    description="API for serving stock market data and analytics",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:3001"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dependency for database session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Pydantic models for API responses
class CompanyBasic(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    nse_code: Optional[str]
    bse_code: Optional[str]
    industry: Optional[str]
    current_price: Optional[float]
    market_capitalization: Optional[float]
    sector: Optional[str]

class CompanyMetrics(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    nse_code: Optional[str]
    bse_code: Optional[str]
    industry: Optional[str]
    current_price: Optional[float]
    market_capitalization: Optional[float]
    return_on_equity: Optional[float]
    return_on_assets: Optional[float]
    debt_to_equity: Optional[float]
    price_to_earning: Optional[float]
    promoter_holding: Optional[float]
    fii_holding: Optional[float]
    dii_holding: Optional[float]

class PriceData(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    date: date
    open: Optional[float]
    high: Optional[float]
    low: Optional[float]
    close: Optional[float]
    volume: Optional[int]
    adj_close: Optional[float]

class MarketOverview(BaseModel):
    total_companies: int
    total_market_cap: float
    avg_pe_ratio: float
    sector_distribution: dict

@app.get("/")
def read_root():
    return {"message": "Stock Market Dashboard API", "version": "1.0.0"}

@app.get("/api/companies", response_model=List[CompanyBasic])
def get_companies(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    sector: Optional[str] = None,
    industry: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """Get list of companies with optional filters"""
    query = db.query(Company)
    
    if sector:
        query = query.filter(Company.industry == sector)
    if industry:
        query = query.filter(Company.industry == industry)
    
    companies = query.offset(skip).limit(limit).all()
    return companies

@app.get("/api/companies/{company_id}", response_model=CompanyMetrics)
def get_company(company_id: int, db: Session = Depends(get_db)):
    """Get detailed company metrics"""
    company = db.query(Company).filter(Company.id == company_id).first()
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    return company

@app.get("/api/companies/{company_id}/prices", response_model=List[PriceData])
def get_company_prices(
    company_id: int,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    db: Session = Depends(get_db)
):
    """Get historical price data for a company"""
    query = db.query(Price).filter(Price.company_id == company_id)
    
    if start_date:
        query = query.filter(Price.date >= start_date)
    if end_date:
        query = query.filter(Price.date <= end_date)
    
    prices = query.order_by(Price.date.desc()).limit(365).all()
    return prices[::-1]  # Return in chronological order

@app.get("/api/market/overview")
def get_market_overview(db: Session = Depends(get_db)):
    """Get market overview statistics"""
    total_companies = db.query(func.count(Company.id)).scalar()
    
    # Use COALESCE to handle NULL values
    total_market_cap = db.query(func.coalesce(func.sum(Company.market_capitalization), 0)).scalar()
    
    avg_pe = db.query(func.coalesce(func.avg(Company.price_to_earning), 0)).scalar()
    
    # Sector distribution
    sector_counts = db.query(
        Company.industry,
        func.count(Company.id)
    ).group_by(Company.industry).all()
    
    sector_distribution = {
        sector: count for sector, count in sector_counts if sector
    }
    
    # Handle special float values
    def safe_float(value):
        if value is None:
            return 0.0
        if isinstance(value, float):
            if value != value:  # NaN
                return 0.0
            if abs(value) == float('inf'):  # Infinity
                return 0.0
        return float(value)
    
    return {
        "total_companies": total_companies,
        "total_market_cap": safe_float(total_market_cap),
        "avg_pe_ratio": safe_float(avg_pe),
        "sector_distribution": sector_distribution
    }

@app.get("/api/market/top-gainers")
def get_top_gainers(limit: int = Query(10, ge=1, le=50), db: Session = Depends(get_db)):
    """Get top gainers based on recent returns"""
    def safe_float(value):
        if value is None:
            return None
        if isinstance(value, float):
            if value != value:  # NaN
                return None
            if abs(value) == float('inf'):  # Infinity
                return None
        return float(value)
    
    companies = db.query(Company)\
        .filter(Company.return_over_1year.isnot(None))\
        .order_by(Company.return_over_1year.desc())\
        .limit(limit)\
        .all()
    
    return [
        {
            "id": c.id,
            "name": c.name,
            "nse_code": c.nse_code,
            "current_price": safe_float(c.current_price),
            "return_1y": safe_float(c.return_over_1year)
        }
        for c in companies
    ]

@app.get("/api/market/top-losers")
def get_top_losers(limit: int = Query(10, ge=1, le=50), db: Session = Depends(get_db)):
    """Get top losers based on recent returns"""
    def safe_float(value):
        if value is None:
            return None
        if isinstance(value, float):
            if value != value:  # NaN
                return None
            if abs(value) == float('inf'):  # Infinity
                return None
        return float(value)
    
    companies = db.query(Company)\
        .filter(Company.return_over_1year.isnot(None))\
        .order_by(Company.return_over_1year.asc())\
        .limit(limit)\
        .all()
    
    return [
        {
            "id": c.id,
            "name": c.name,
            "nse_code": c.nse_code,
            "current_price": safe_float(c.current_price),
            "return_1y": safe_float(c.return_over_1year)
        }
        for c in companies
    ]

@app.get("/api/market/high-volume")
def get_high_volume_stocks(limit: int = Query(10, ge=1, le=50), db: Session = Depends(get_db)):
    """Get stocks with high trading volume"""
    def safe_float(value):
        if value is None:
            return None
        if isinstance(value, float):
            if value != value:  # NaN
                return None
            if abs(value) == float('inf'):  # Infinity
                return None
        return float(value)
    
    companies = db.query(Company)\
        .filter(Company.volume.isnot(None))\
        .order_by(Company.volume.desc())\
        .limit(limit)\
        .all()
    
    return [
        {
            "id": c.id,
            "name": c.name,
            "nse_code": c.nse_code,
            "current_price": safe_float(c.current_price),
            "volume": safe_float(c.volume)
        }
        for c in companies
    ]

@app.get("/api/sectors/performance")
def get_sector_performance(db: Session = Depends(get_db)):
    """Get sector-wise performance metrics"""
    def safe_float(value):
        if value is None:
            return 0.0
        if isinstance(value, float):
            if value != value:  # NaN
                return 0.0
            if abs(value) == float('inf'):  # Infinity
                return 0.0
        return float(value)
    
    sector_data = db.query(
        Company.industry,
        func.avg(Company.return_over_1year).label('avg_return'),
        func.sum(Company.market_capitalization).label('total_market_cap'),
        func.count(Company.id).label('company_count')
    ).group_by(Company.industry)\
     .having(Company.industry.isnot(None))\
     .all()
    
    return [
        {
            "sector": sector.industry,
            "avg_return": safe_float(sector.avg_return),
            "total_market_cap": safe_float(sector.total_market_cap),
            "company_count": sector.company_count
        }
        for sector in sector_data
    ]

@app.get("/api/indices")
def get_indices(db: Session = Depends(get_db)):
    """Get list of market indices"""
    indices = db.query(Index).all()
    return [
        {
            "id": idx.id,
            "name": idx.name,
            "ticker": idx.ticker,
            "region": idx.region
        }
        for idx in indices
    ]

@app.get("/api/indices/{index_id}/prices")
def get_index_prices(
    index_id: int,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    db: Session = Depends(get_db)
):
    """Get historical index prices"""
    query = db.query(IndexPrice).filter(IndexPrice.id == index_id)
    
    if start_date:
        query = query.filter(IndexPrice.date >= start_date)
    if end_date:
        query = query.filter(IndexPrice.date <= end_date)
    
    prices = query.order_by(IndexPrice.date.desc()).limit(365).all()
    return [
        {
            "date": p.date,
            "open": float(p.open) if p.open else None,
            "high": float(p.high) if p.high else None,
            "low": float(p.low) if p.low else None,
            "close": float(p.close) if p.close else None,
            "volume": int(p.volume) if p.volume else None
        }
        for p in prices[::-1]
    ]

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)


# ---------------------------------------------------------------------------
# Repository-backed canonical endpoints
# ---------------------------------------------------------------------------

from repositories.market_repository import MarketRepository
from repositories.breadth_repository import BreadthRepository
from repositories.breadth_analytics_repository import BreadthAnalyticsRepository
from repositories.sector_repository import SectorRepository
from repositories.stock_repository import StockRepository
from repositories.signal_repository import SignalRepository
from repositories.probability_repository import ProbabilityRepository
from repositories.portfolio_repository import PortfolioRepository
from repositories.volume_profile_repository import VolumeProfileRepository
from repositories.volume_profile_v2_repository import VolumeProfileV2Repository
from repositories.price_trend_repository import PriceTrendRepository
from repositories.price_trend_v2_repository import PriceTrendV2Repository


def get_repos(db: Session = Depends(get_db)):
    return {
        "market": MarketRepository(db),
        "breadth": BreadthRepository(db),
        "breadth_analytics": BreadthAnalyticsRepository(db),
        "sector": SectorRepository(db),
        "stock": StockRepository(db),
        "signal": SignalRepository(db),
        "probability": ProbabilityRepository(db),
        "portfolio": PortfolioRepository(db),
        "volume_profile": VolumeProfileRepository(db),
        "volume_profile_v2": VolumeProfileV2Repository(db),
        "price_trend": PriceTrendRepository(db),
        "price_trend_v2": PriceTrendV2Repository(db),
    }


@app.get("/api/domain/market/pulse")
def get_domain_pulse(repos=Depends(get_repos)):
    breadth = repos["breadth"].compute_breadth()
    overview = repos["market"].get_market_overview()
    sentiment = "bullish" if breadth["marketParticipationScore"] >= 55 else "bearish" if breadth["marketParticipationScore"] <= 40 else "neutral"
    return {
        "id": "market-pulse",
        "timestamp": datetime.utcnow().isoformat(),
        "overallSentiment": sentiment,
        "marketRegime": "Sideways" if sentiment == "neutral" else ("Bull" if sentiment == "bullish" else "Bear"),
        "regimeConfidence": "medium",
        "keyDrivers": [
            f"{breadth['marketParticipationScore']:.0f}% market participation",
            f"Net advances {breadth['netAdvances']}",
            f"{breadth['percentageAbove200DMA']:.0f}% of stocks above 200 DMA",
        ],
        "risks": [
            "Breadth constructive" if breadth["breadthTrend"] != "down" else "Breadth deteriorating",
            "Volatility contained",
        ],
        "outlook": "Market participation remains steady with mixed sector leadership.",
    }


@app.get("/api/domain/market/breadth")
def get_domain_breadth(repos=Depends(get_repos)):
    return repos["breadth"].compute_breadth()


@app.get("/api/market-breadth/summary")
def get_market_breadth_summary(
    date: Optional[str] = Query(None),
    dmaPeriods: List[int] = Query(default=[20, 50, 100, 200]),
    horizons: List[int] = Query(default=[1, 5, 21, 63, 126, 256]),
    signalType: str = Query("above50dma"),
    marketCap: Optional[str] = Query(None),
    marketCapBucket: Optional[str] = Query(None),
    companyName: Optional[str] = Query(None),
    repos=Depends(get_repos),
):
    return repos["breadth_analytics"].get_breadth_summary(
        date=date, dma_periods=dmaPeriods, horizons=horizons, signal_type=signalType,
        market_cap=marketCap, market_cap_bucket=marketCapBucket, company_name=companyName,
    )


@app.get("/api/market-breadth/distribution")
def get_market_breadth_distribution(
    dmaPeriods: List[int] = Query(default=[20, 50, 100, 200]),
    marketCap: Optional[str] = Query(None),
    marketCapBucket: Optional[str] = Query(None),
    companyName: Optional[str] = Query(None),
    repos=Depends(get_repos),
):
    return repos["breadth_analytics"].get_breadth_distribution(
        dma_periods=dmaPeriods, market_cap=marketCap, market_cap_bucket=marketCapBucket, company_name=companyName,
    )


@app.get("/api/market-breadth/sectors")
def get_market_breadth_sectors(
    sector: Optional[str] = Query(None),
    industry: Optional[str] = Query(None),
    industrySubGroup: Optional[str] = Query(None),
    dmaPeriods: List[int] = Query(default=[20, 50, 100, 200]),
    horizons: List[int] = Query(default=[1, 5, 21, 63, 126, 256]),
    signalType: str = Query("above50dma"),
    marketCap: Optional[str] = Query(None),
    marketCapBucket: Optional[str] = Query(None),
    companyName: Optional[str] = Query(None),
    sortBy: str = Query("breadthScore"),
    sortDirection: str = Query("desc"),
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    repos=Depends(get_repos),
):
    return repos["breadth_analytics"].get_sector_breadth(
        sector=sector,
        industry=industry,
        industry_sub_group=industrySubGroup,
        dma_periods=dmaPeriods,
        horizons=horizons,
        signal_type=signalType,
        sort_by=sortBy,
        sort_dir=sortDirection,
        limit=limit,
        offset=offset,
        market_cap=marketCap,
        market_cap_bucket=marketCapBucket,
        company_name=companyName,
    )


@app.get("/api/market-breadth/industries")
def get_market_breadth_industries(
    sector: Optional[str] = Query(None),
    industryGroup: Optional[str] = Query(None),
    industrySubGroup: Optional[str] = Query(None),
    dmaPeriods: List[int] = Query(default=[20, 50, 100, 200]),
    horizons: List[int] = Query(default=[1, 5, 21, 63, 126, 256]),
    signalType: str = Query("above50dma"),
    marketCap: Optional[str] = Query(None),
    marketCapBucket: Optional[str] = Query(None),
    companyName: Optional[str] = Query(None),
    sortBy: str = Query("breadthScore"),
    sortDirection: str = Query("desc"),
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    repos=Depends(get_repos),
):
    return repos["breadth_analytics"].get_industry_breadth(
        sector=sector,
        industry_group=industryGroup,
        industry_sub_group=industrySubGroup,
        dma_periods=dmaPeriods,
        horizons=horizons,
        signal_type=signalType,
        sort_by=sortBy,
        sort_dir=sortDirection,
        limit=limit,
        offset=offset,
        market_cap=marketCap,
        market_cap_bucket=marketCapBucket,
        company_name=companyName,
    )


@app.get("/api/market-breadth/companies")
def get_market_breadth_companies(
    sector: Optional[str] = Query(None),
    industry: Optional[str] = Query(None),
    industrySubGroup: Optional[str] = Query(None),
    dmaPeriods: List[int] = Query(default=[20, 50, 100, 200]),
    horizons: List[int] = Query(default=[1, 5, 21, 63, 126, 256]),
    signalType: str = Query("above50dma"),
    marketCap: Optional[str] = Query(None),
    marketCapBucket: Optional[str] = Query(None),
    companyName: Optional[str] = Query(None),
    sortBy: str = Query("breadthScore"),
    sortDirection: str = Query("desc"),
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    repos=Depends(get_repos),
):
    return repos["breadth_analytics"].get_company_breadth(
        sector=sector,
        industry=industry,
        industry_sub_group=industrySubGroup,
        dma_periods=dmaPeriods,
        horizons=horizons,
        signal_type=signalType,
        sort_by=sortBy,
        sort_dir=sortDirection,
        limit=limit,
        offset=offset,
        market_cap=marketCap,
        market_cap_bucket=marketCapBucket,
        company_name=companyName,
    )


@app.get("/api/market-breadth/subgroups")
def get_market_breadth_subgroups(
    sector: Optional[str] = Query(None),
    industry: Optional[str] = Query(None),
    industrySubGroup: Optional[str] = Query(None),
    dmaPeriods: List[int] = Query(default=[20, 50, 100, 200]),
    horizons: List[int] = Query(default=[1, 5, 21, 63, 126, 256]),
    signalType: str = Query("above50dma"),
    marketCap: Optional[str] = Query(None),
    marketCapBucket: Optional[str] = Query(None),
    companyName: Optional[str] = Query(None),
    sortBy: str = Query("breadthScore"),
    sortDirection: str = Query("desc"),
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    repos=Depends(get_repos),
):
    return repos["breadth_analytics"].get_subgroup_breadth(
        sector=sector,
        industry=industry,
        industry_sub_group=industrySubGroup,
        dma_periods=dmaPeriods,
        horizons=horizons,
        signal_type=signalType,
        sort_by=sortBy,
        sort_dir=sortDirection,
        limit=limit,
        offset=offset,
        market_cap=marketCap,
        market_cap_bucket=marketCapBucket,
        company_name=companyName,
    )


@app.get("/api/market-breadth/history")
def get_market_breadth_history(
    period: str = Query("1y", description="1m | 3m | 6m | 1y"),
    dmaPeriods: List[int] = Query(default=[20, 50, 200]),
    repos=Depends(get_repos),
):
    return repos["breadth_analytics"].get_breadth_history(period=period, dma_periods=dmaPeriods)


@app.post("/api/market-breadth/refresh-cache")
def refresh_market_breadth_cache(
    dmaPeriods: List[int] = Query(default=[20, 50, 100, 200]),
    horizons: List[int] = Query(default=[1, 5, 21, 63, 126, 256]),
    repos=Depends(get_repos),
):
    results = repos["breadth_analytics"].refresh_cache(dma_periods=dmaPeriods, horizons=horizons)
    return {"status": "ok", "companies": len(results), "dmaPeriods": dmaPeriods, "horizons": horizons}


@app.get("/api/domain/market/sectors")
def get_domain_sectors(repos=Depends(get_repos)):
    return repos["sector"].get_sectors()


@app.get("/api/domain/stocks/{symbol}")
def get_domain_stock(symbol: str, repos=Depends(get_repos)):
    snapshot = repos["stock"].find_by_symbol(symbol.upper())
    if not snapshot:
        raise HTTPException(status_code=404, detail="Stock not found")
    prices = repos["stock"].get_prices(snapshot["id"], days=252)
    snapshot["prices"] = prices
    prob = repos["probability"].get_by_symbol(symbol.upper())
    snapshot["probability"] = prob
    signal = repos["signal"].get_signal(symbol.upper())
    snapshot["signal"] = signal
    return snapshot


@app.get("/api/domain/signals")
def get_domain_signals(limit: int = 50, repos=Depends(get_repos)):
    return repos["signal"].get_signals(limit=limit)


@app.get("/api/domain/portfolio/summary")
def get_domain_portfolio(portfolio_id: str = "default", repos=Depends(get_repos)):
    return repos["portfolio"].get_portfolio_summary(portfolio_id)


@app.get("/api/domain/watchlist")
def get_domain_watchlist(watchlist_id: str = "default", repos=Depends(get_repos)):
    return repos["portfolio"].get_watchlist(watchlist_id)


@app.get("/api/domain/probability/{symbol}")
def get_domain_probability(symbol: str, repos=Depends(get_repos)):
    prob = repos["probability"].get_by_symbol(symbol.upper())
    if not prob:
        raise HTTPException(status_code=404, detail="Probability data not found")
    return prob


@app.get("/api/market/indices")
def get_market_indices(repos=Depends(get_repos)):
    return repos["market"].get_indices()


@app.get("/api/market/movers")
def get_market_movers(repos=Depends(get_repos)):
    return {
        "gainers": repos["market"].get_top_gainers(limit=6),
        "losers": repos["market"].get_top_losers(limit=6),
    }


@app.get("/api/market/status")
def get_market_status():
    return {"open": True, "asOf": datetime.utcnow().isoformat()}
print("ROUTES LOADED:", len(app.routes))


@app.get("/api/volume-profile")
def get_volume_profile(
    date: Optional[str] = Query(None, description="Snapshot date (last_modified)"),
    hierarchyLevel: Optional[str] = Query(None, description="sector | industry | industrySubGroup | company"),
    level: Optional[str] = Query(None, description="Alias for hierarchyLevel (back-compat)"),
    parent: Optional[str] = Query(None, description="Drill-down parent (ancestor name)"),
    sector: Optional[str] = Query(None),
    industry: Optional[str] = Query(None),
    industrySubGroup: Optional[str] = Query(None),
    marketCap: Optional[str] = Query(None, description="large | mid | small"),
    marketCapBucket: Optional[str] = Query(None, description="Exact cap_class value"),
    rank: Optional[int] = Query(None, description="Reserved (rank is computed server-side)"),
    company: Optional[str] = Query(None, description="nse_code or company_id"),
    companyName: Optional[str] = Query(None, description="Case-insensitive prefix match on company name"),
    sortMetric: str = Query("volSortPct", description="volume | avgVol1W | avgVol1M | avgVol1Y | volSortPct"),
    sortDirection: str = Query("desc", description="asc | desc"),
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    repos=Depends(get_repos),
):
    """Volume Profiling (Averages).

    Drill-down hierarchy: Sector -> Industry -> IndustrySubGroup -> Company.
    Filtering, aggregation, sorting and pagination are performed in SQL.
    """
    result = repos["volume_profile"].get_volume_profile(
        hierarchy_level=hierarchyLevel or level or "sector",
        parent=parent,
        sector=sector,
        industry=industry,
        industry_sub_group=industrySubGroup,
        market_cap=marketCap,
        market_cap_bucket=marketCapBucket,
        company=company,
        company_name=companyName,
        date=date,
        sort_metric=sortMetric,
        sort_direction=sortDirection,
        limit=limit,
        offset=offset,
    )
    return result


@app.get("/api/domain/volume-profile")
def get_domain_volume_profile(
    level: str = "company",
    sector: str = None,
    industry: str = None,
    market_cap: str = None,
    limit: int = 50,
    repos=Depends(get_repos),
):
    if limit > 500:
        limit = 500
    result = repos["volume_profile"].get_volume_profile(
        hierarchy_level=level,
        sector=sector,
        industry=industry,
        market_cap=market_cap,
        limit=limit,
    )
    return result


@app.get("/api/volume-profile/latest-date")
def get_latest_volume_profile_date(db: Session = Depends(get_db), repos=Depends(get_repos)):
    table = repos["volume_profile"].table
    result = db.query(table.c.last_modified).order_by(table.c.last_modified.desc()).limit(1).first()
    return {"date": result[0].isoformat() if result and result[0] else None}


@app.get("/api/volume-profile-v2")
def get_volume_profile_v2(
    date: Optional[str] = Query(None, description="Snapshot date (last_modified)"),
    hierarchyLevel: Optional[str] = Query(None, description="sector | industry | industrySubGroup | company"),
    level: Optional[str] = Query(None, description="Alias for hierarchyLevel (back-compat)"),
    parent: Optional[str] = Query(None, description="Drill-down parent (ancestor name)"),
    sector: Optional[str] = Query(None),
    industry: Optional[str] = Query(None),
    industrySubGroup: Optional[str] = Query(None),
    marketCap: Optional[str] = Query(None, description="large | mid | small"),
    marketCapBucket: Optional[str] = Query(None, description="Exact cap_class value"),
    rank: Optional[int] = Query(None, description="Reserved (rank is computed server-side)"),
    company: Optional[str] = Query(None, description="nse_code or company_id"),
    companyName: Optional[str] = Query(None, description="Case-insensitive prefix match on company name"),
    sortMetric: str = Query("relative1Y", description="volume | avgVol1W | avgVol1M | avgVol1Y | relative1W | relative1M | relative1Y"),
    sortDirection: str = Query("desc", description="asc | desc"),
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    repos=Depends(get_repos),
):
    """Volume Profiling V2 — Relative Volume.

    Compares today's volume against the entity's own historical averages:
      relative1Week  = todayVolume / average1WeekVolume
      relative1Month = todayVolume / average1MonthVolume
      relative1Year  = todayVolume / average1YearVolume

    Drill-down hierarchy: Sector -> Industry -> IndustrySubGroup -> Company.
    Filtering, aggregation, sorting and pagination are performed in SQL.
    """
    result = repos["volume_profile_v2"].get_volume_profile(
        hierarchy_level=hierarchyLevel or level or "sector",
        parent=parent,
        sector=sector,
        industry=industry,
        industry_sub_group=industrySubGroup,
        market_cap=marketCap,
        market_cap_bucket=marketCapBucket,
        company=company,
        company_name=companyName,
        date=date,
        sort_metric=sortMetric,
        sort_direction=sortDirection,
        limit=limit,
        offset=offset,
    )
    return result


@app.get("/api/volume-profile-v2/latest-date")
def get_latest_volume_profile_v2_date(db: Session = Depends(get_db), repos=Depends(get_repos)):
    table = repos["volume_profile_v2"].table
    result = db.query(table.c.last_modified).order_by(table.c.last_modified.desc()).limit(1).first()
    return {"date": result[0].isoformat() if result and result[0] else None}


@app.get("/api/price-trends")
def get_price_trends(
    selectedPeriods: List[str] = Query(default=[]),
    sector: Optional[str] = Query(None),
    industry: Optional[str] = Query(None),
    industrySubGroup: Optional[str] = Query(None),
    marketCap: Optional[str] = Query(None, description="large | mid | small"),
    marketCapBucket: Optional[str] = Query(None, description="Exact cap_class value"),
    rank: Optional[str] = Query(None, description="Reserved (rank is computed server-side)"),
    company: Optional[str] = Query(None, description="nse_code or company_id"),
    companyName: Optional[str] = Query(None, description="Case-insensitive prefix match on company name"),
    date: Optional[str] = Query(None, description="Snapshot date (last_modified)"),
    sortMetric: str = Query("252d", description="1d | 2d | 3d | 4d | 5d | 21d | 63d | 126d | 252d | 504d | 756d | 1260d | 2520d | name | marketCap"),
    sortDirection: str = Query("desc", description="asc | desc"),
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    repos=Depends(get_repos),
):
    """Price Trends.

    Returns company price performance across selected lookback periods.
    Filtering, sorting and pagination are performed in SQL.
    """
    result = repos["price_trend"].get_price_trends(
        selected_periods=selectedPeriods,
        sector=sector,
        industry=industry,
        industry_sub_group=industrySubGroup,
        market_cap=marketCap,
        market_cap_bucket=marketCapBucket,
        rank=rank,
        company=company,
        company_name=companyName,
        date=date,
        sort_metric=sortMetric,
        sort_direction=sortDirection,
        limit=limit,
        offset=offset,
    )
    return result


@app.get("/api/price-trends/latest-date")
def get_latest_price_trends_date(db: Session = Depends(get_db), repos=Depends(get_repos)):
    table = repos["price_trend"].table
    result = db.query(table.c.last_modified).order_by(table.c.last_modified.desc()).limit(1).first()
    return {"date": result[0].isoformat() if result and result[0] else None}


@app.get("/api/price-trends-v2")
def get_price_trends_v2(
    selectedPeriods: List[str] = Query(default=[]),
    sector: Optional[str] = Query(None),
    industry: Optional[str] = Query(None),
    industrySubGroup: Optional[str] = Query(None),
    marketCap: Optional[str] = Query(None, description="large | mid | small"),
    marketCapBucket: Optional[str] = Query(None, description="Exact cap_class value"),
    rank: Optional[str] = Query(None, description="Reserved (rank is computed server-side)"),
    company: Optional[str] = Query(None, description="nse_code or company_id"),
    companyName: Optional[str] = Query(None, description="Case-insensitive prefix match on company name"),
    date: Optional[str] = Query(None, description="Snapshot date (last_modified)"),
    hierarchyLevel: Optional[str] = Query("company", description="sector | industry | industrySubGroup | company"),
    level: Optional[str] = Query(None, description="Alias for hierarchyLevel"),
    sortMetric: str = Query("252d", description="1d | 2d | 3d | 4d | 5d | 21d | 63d | 126d | 252d | 504d | 756d | 1260d | 2520d | name | marketCap | weightedMarketCap"),
    sortDirection: str = Query("desc", description="asc | desc"),
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    repos=Depends(get_repos),
):
    """Price Trends V2 — Market-Cap Weighted.

    At sector/industry/sub-group level, returns are market-cap weighted:
      weighted_return = SUM(return * market_cap) / SUM(market_cap)

    At company level, individual company returns are returned unchanged.
    """
    result = repos["price_trend_v2"].get_price_trends(
        selected_periods=selectedPeriods,
        sector=sector,
        industry=industry,
        industry_sub_group=industrySubGroup,
        market_cap=marketCap,
        market_cap_bucket=marketCapBucket,
        rank=rank,
        company=company,
        company_name=companyName,
        date=date,
        hierarchy_level=hierarchyLevel or level or "company",
        sort_metric=sortMetric,
        sort_direction=sortDirection,
        limit=limit,
        offset=offset,
    )
    return result


@app.get("/api/price-trends-v2/latest-date")
def get_latest_price_trends_v2_date(db: Session = Depends(get_db), repos=Depends(get_repos)):
    table = repos["price_trend_v2"].table
    result = db.query(table.c.last_modified).order_by(table.c.last_modified.desc()).limit(1).first()
    return {"date": result[0].isoformat() if result and result[0] else None}
