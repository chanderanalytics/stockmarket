"""
PriceTrendV2Repository — Price Trends analytics with market-cap weighted aggregation.

Authoritative source: merged_price_baseline_probabilities_wide (single table,
no joins, no duplicate tables/calculations). All filtering, aggregation,
sorting and pagination is performed in SQL; the frontend only renders.

Hierarchy (drill-down):  Sector -> Industry -> IndustrySubGroup -> Company

At sector/industry/sub-group level, returns are market-cap weighted:
  weighted_return = SUM(return * market_cap) / SUM(market_cap)

At company level, individual company returns are returned unchanged.

Column mapping (logical -> physical):
  Company           -> name / company_id
  Sector            -> "Sector.Name_bse"
  Industry          -> "Industry.New.Name_bse"
  IndustrySubGroup  -> "ISubgroup.Name_bse"
  MarketCap         -> market_capitalization
  MarketCapBucket   -> cap_class
  1D/2D/... returns -> pchg_1d / pchg_2d / ...
"""

from sqlalchemy.orm import Session
from sqlalchemy import Table, MetaData, func, literal, or_, desc, asc, case, nullslast
from typing import List, Dict, Any, Optional

# Quoted/dotted physical column names in the wide table.
COL_SECTOR = "Sector.Name_bse"
COL_INDUSTRY = "Industry.New.Name_bse"
COL_SUBGROUP = "ISubgroup.Name_bse"

LEVEL_GROUP_COLUMN = {
    "sector": COL_SECTOR,
    "industry": COL_INDUSTRY,
    "industrySubGroup": COL_SUBGROUP,
    "company": None,
}

# Available lookback periods.
PERIOD_COLUMNS = {
    "1d": "pchg_1d",
    "2d": "pchg_2d",
    "3d": "pchg_3d",
    "4d": "pchg_4d",
    "5d": "pchg_5d",
    "21d": "pchg_21d",
    "63d": "pchg_63d",
    "126d": "pchg_126d",
    "252d": "pchg_252d",
    "504d": "pchg_504d",
    "756d": "pchg_756d",
    "1260d": "pchg_1260d",
    "2520d": "pchg_2520d",
}

SORT_METRICS = set(PERIOD_COLUMNS.keys()) | {"name", "marketCap", "weightedMarketCap"}

# Market-cap tier -> cap_class bucket values.
CAP_TIER_BUCKET = {
    "large": "top 10perc by mcap",
    "mid": "50-90% by mcap",
    "small": "bottom 50% by mcap",
}


class PriceTrendV2Repository:
    def __init__(self, db: Session):
        self.db = db
        engine = db.get_bind()
        metadata = MetaData()
        self.table = Table(
            "merged_price_baseline_probabilities_wide",
            metadata,
            autoload_with=engine,
        )

    def get_price_trends(
        self,
        *,
        selected_periods: List[str] = None,
        sector: Optional[str] = None,
        industry: Optional[str] = None,
        industry_sub_group: Optional[str] = None,
        market_cap: Optional[str] = None,
        market_cap_bucket: Optional[str] = None,
        rank: Optional[str] = None,
        company: Optional[str] = None,
        company_name: Optional[str] = None,
        date: Optional[str] = None,
        hierarchy_level: str = "company",
        sort_metric: str = "252d",
        sort_direction: str = "desc",
        limit: int = 50,
        offset: int = 0,
    ) -> Dict[str, Any]:
        c = self.table.c
        level = hierarchy_level if hierarchy_level in LEVEL_GROUP_COLUMN else "company"

        # Normalize requested periods to known columns, preserving order.
        if not selected_periods:
            selected_periods = ["252d"]
        periods = [p for p in selected_periods if p in PERIOD_COLUMNS]
        if not periods:
            periods = ["252d"]

        # Build filters.
        filters: List[Any] = []
        if sector:
            filters.append(c[COL_SECTOR] == sector)
        if industry:
            filters.append(c[COL_INDUSTRY] == industry)
        if industry_sub_group:
            filters.append(c[COL_SUBGROUP] == industry_sub_group)
        if market_cap and market_cap in CAP_TIER_BUCKET:
            filters.append(c.cap_class == CAP_TIER_BUCKET[market_cap])
        if market_cap_bucket:
            filters.append(c.cap_class == market_cap_bucket)
        if company:
            filters.append(or_(c.nse_code == company, c.company_id == company))
        if company_name:
            filters.append(c.name.ilike(f"{company_name}%"))
        if date:
            filters.append(c.last_modified == date)

        # Rank filter (1-based rank within filtered/sorted set).
        if rank:
            try:
                rank_val = int(rank)
                if rank_val > 0:
                    filters.append(c.company_id.isnot(None))
            except ValueError:
                pass

        if level == "company":
            return self._company_level(
                c, filters, periods, sort_metric, sort_direction, limit, offset
            )
        return self._aggregate_level(
            level, c, filters, periods, sort_metric, sort_direction, limit, offset
        )

    def _company_level(
        self,
        c,
        filters: List[Any],
        periods: List[str],
        sort_metric: str,
        sort_direction: str,
        limit: int,
        offset: int,
    ) -> Dict[str, Any]:
        cols = [
            c.company_id.label("id"),
            c.name.label("name"),
            literal(1).label("companyCount"),
            c[COL_SECTOR].label("sector"),
            c[COL_INDUSTRY].label("industry"),
            c[COL_SUBGROUP].label("industrySubGroup"),
            c.market_capitalization.label("marketCap"),
            c.cap_class.label("marketCapBucket"),
        ]
        for period in periods:
            cols.append(c[PERIOD_COLUMNS[period]].label(period))

        total = self.db.query(c.company_id).filter(*filters).count()

        order_expr = self._build_order(
            c, sort_metric, periods, sort_direction
        )
        query = self.db.query(*cols).filter(*filters).order_by(nullslast(order_expr))
        rows = query.limit(limit).offset(offset).all()

        result = []
        for i, row in enumerate(rows):
            item: Dict[str, Any] = {
                "id": row.id,
                "name": row.name or "",
                "companyCount": int(row.companyCount) if getattr(row, "companyCount", None) is not None else None,
                "sector": row.sector or "",
                "industry": row.industry or "",
                "industrySubGroup": row.industrySubGroup or "",
                "marketCap": _f(row.marketCap),
                "marketCapBucket": getattr(row, "marketCapBucket", "") or "",
            }
            for period in periods:
                raw = getattr(row, period, None)
                item[period] = _f(raw)
            result.append(item)

        return {
            "level": "company",
            "periods": periods,
            "total": total,
            "rows": result,
        }

    def _aggregate_level(
        self,
        level: str,
        c,
        filters: List[Any],
        periods: List[str],
        sort_metric: str,
        sort_direction: str,
        limit: int,
        offset: int,
    ) -> Dict[str, Any]:
        group_col = c[LEVEL_GROUP_COLUMN[level]]

        # Exclude empty/unnamed groups.
        filters = filters + [group_col.isnot(None), group_col != ""]

        # Parent labels.
        if level == "sector":
            sector_label = group_col
            industry_label = literal("")
            subgroup_label = literal("")
        elif level == "industry":
            sector_label = func.max(c[COL_SECTOR])
            industry_label = group_col
            subgroup_label = literal("")
        else:
            sector_label = func.max(c[COL_SECTOR])
            industry_label = func.max(c[COL_INDUSTRY])
            subgroup_label = group_col

        # Market-cap weighted aggregation: SUM(return * market_cap) / SUM(market_cap)
        mcap_expr = func.sum(c.market_capitalization)

        select_cols = [
            group_col.label("id"),
            group_col.label("name"),
            func.count(c.company_id).label("companyCount"),
            sector_label.label("sector"),
            industry_label.label("industry"),
            subgroup_label.label("industrySubGroup"),
            mcap_expr.label("marketCap"),
            literal("").label("marketCapBucket"),
        ]

        for period in periods:
            col = c[PERIOD_COLUMNS[period]]
            # weighted_return = SUM(return * market_cap) / SUM(market_cap)
            weighted = func.sum(col * func.coalesce(c.market_capitalization, 0)) / func.nullif(mcap_expr, 0)
            select_cols.append(weighted.label(period))

        # Total distinct groups.
        total = self.db.query(group_col).filter(*filters).distinct().count()

        order_expr = self._build_aggregate_order(
            c, level, sort_metric, periods, sort_direction, mcap_expr
        )
        query = self.db.query(*select_cols).filter(*filters).group_by(group_col)
        query = query.order_by(nullslast(order_expr))
        rows = query.limit(limit).offset(offset).all()

        result = []
        for i, row in enumerate(rows):
            item: Dict[str, Any] = {
                "id": row.id or "",
                "name": row.name or "",
                "companyCount": int(row.companyCount) if getattr(row, "companyCount", None) is not None else None,
                "sector": row.sector or "",
                "industry": row.industry or "",
                "industrySubGroup": row.industrySubGroup or "",
                "marketCap": _f(row.marketCap),
                "marketCapBucket": getattr(row, "marketCapBucket", "") or "",
            }
            for period in periods:
                raw = getattr(row, period, None)
                item[period] = _f(raw)
            result.append(item)

        return {
            "level": level,
            "periods": periods,
            "total": total,
            "rows": result,
        }

    def _build_order(self, c, sort_metric: str, periods: List[str], sort_direction: str):
        direction = desc if sort_direction != "asc" else asc
        if sort_metric == "name":
            return direction(c.name)
        elif sort_metric == "marketCap":
            mc_sentinel = -1e18 if sort_direction != "asc" else 1e18
            return direction(
                case((c.market_capitalization.is_(None), mc_sentinel), else_=c.market_capitalization)
            )
        elif sort_metric in PERIOD_COLUMNS:
            col = c[PERIOD_COLUMNS[sort_metric]]
            blank_sentinel = -1e12 if sort_direction != "asc" else 1e12
            sort_col = case(
                (col.is_(None), blank_sentinel),
                (col == 9999, blank_sentinel),
                else_=col,
            )
            return direction(sort_col)
        else:
            return desc(c[PERIOD_COLUMNS[periods[0]]])

    def _build_aggregate_order(
        self, c, level: str, sort_metric: str, periods: List[str], sort_direction: str, mcap_expr
    ):
        direction = desc if sort_direction != "asc" else asc
        if sort_metric == "name":
            return direction(c[LEVEL_GROUP_COLUMN[level]])
        elif sort_metric == "marketCap" or sort_metric == "weightedMarketCap":
            return direction(mcap_expr)
        elif sort_metric in PERIOD_COLUMNS:
            blank_sentinel = -1e12 if sort_direction != "asc" else 1e12
            sort_col = case(
                (func.sum(c[PERIOD_COLUMNS[sort_metric]]).is_(None), blank_sentinel),
                else_=func.sum(c[PERIOD_COLUMNS[sort_metric]] * func.coalesce(c.market_capitalization, 0)) / func.nullif(mcap_expr, 0),
            )
            return direction(sort_col)
        else:
            return desc(func.sum(c[PERIOD_COLUMNS[periods[0]]] * func.coalesce(c.market_capitalization, 0)) / func.nullif(mcap_expr, 0))


def _f(value) -> float:
    try:
        if value is None:
            return None
        return float(value)
    except (TypeError, ValueError):
        return None
