"""
VolumeProfileRepository — Volume Profiling (Averages) analytics.

Authoritative source: merged_price_baseline_probabilities_wide (single table,
no joins, no duplicate tables/calculations). All filtering, aggregation,
sorting and pagination is performed in SQL; the frontend only renders.

Hierarchy (drill-down):  Sector -> Industry -> IndustrySubGroup -> Company

Column mapping (logical -> physical):
  Company           -> name / nse_code
  Sector            -> "Sector.Name_bse"
  Industry          -> "Industry.New.Name_bse"
  IndustrySubGroup  -> "ISubgroup.Name_bse"
  MarketCap         -> market_capitalization
  MarketCapBucket   -> cap_class
  Volume            -> volume
  AvgVol_1W         -> volume_1week_average
  AvgVol_1M         -> volume_1month_average
  AvgVol_1Y         -> volume_1year_average
  VolSortPct        -> volume_vs_1year_avg   (multiple of 1Y avg, e.g. 27.1x)
  Rank              -> computed (1-based, by sortMetric within filtered set)
"""

from sqlalchemy.orm import Session
from sqlalchemy import Table, MetaData, func, literal, or_
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

# Market-cap tier -> cap_class bucket values.
CAP_TIER_BUCKET = {
    "large": "top 10perc by mcap",
    "mid": "50-90% by mcap",
    "small": "bottom 50% by mcap",
}

SORT_METRICS = {"volume", "avgVol1W", "avgVol1M", "avgVol1Y", "volSortPct"}


class VolumeProfileRepository:
    def __init__(self, db: Session):
        self.db = db
        engine = db.get_bind()
        metadata = MetaData()
        self.table = Table(
            "merged_price_baseline_probabilities_wide",
            metadata,
            autoload_with=engine,
        )

    # ------------------------------------------------------------------ #
    # Public API
    # ------------------------------------------------------------------ #
    def get_volume_profile(
        self,
        *,
        hierarchy_level: str = "sector",
        parent: Optional[str] = None,
        sector: Optional[str] = None,
        industry: Optional[str] = None,
        industry_sub_group: Optional[str] = None,
        market_cap: Optional[str] = None,
        market_cap_bucket: Optional[str] = None,
        company: Optional[str] = None,
        company_name: Optional[str] = None,
        date: Optional[str] = None,
        sort_metric: str = "volSortPct",
        sort_direction: str = "desc",
        limit: int = 50,
        offset: int = 0,
    ) -> Dict[str, Any]:
        level = hierarchy_level if hierarchy_level in LEVEL_GROUP_COLUMN else "sector"
        if sort_metric not in SORT_METRICS:
            sort_metric = "volSortPct"
        direction = "desc" if sort_direction != "asc" else "asc"
        limit = max(1, min(int(limit or 50), 1000))
        offset = max(0, int(offset or 0))

        filters = self._build_filters(
            level=level,
            parent=parent,
            sector=sector,
            industry=industry,
            industry_sub_group=industry_sub_group,
            market_cap=market_cap,
            market_cap_bucket=market_cap_bucket,
            company=company,
            company_name=company_name,
            date=date,
        )

        if level == "company":
            return self._company_level(filters, sort_metric, direction, limit, offset)
        return self._aggregate_level(
            level, filters, sort_metric, direction, limit, offset
        )

    # ------------------------------------------------------------------ #
    # Filtering
    # ------------------------------------------------------------------ #
    def _build_filters(
        self,
        *,
        level: str,
        parent: Optional[str],
        sector: Optional[str],
        industry: Optional[str],
        industry_sub_group: Optional[str],
        market_cap: Optional[str],
        market_cap_bucket: Optional[str],
        company: Optional[str],
        company_name: Optional[str],
        date: Optional[str],
    ) -> List[Any]:
        c = self.table.c
        filters: List[Any] = []

        # Explicit hierarchy filters (independent of drill-based `parent`).
        if sector:
            filters.append(c[COL_SECTOR] == sector)
        if industry:
            filters.append(c[COL_INDUSTRY] == industry)
        if industry_sub_group:
            filters.append(c[COL_SUBGROUP] == industry_sub_group)

        # Drill-based parent: restrict to children of the selected ancestor.
        if parent:
            if level == "industry":
                filters.append(c[COL_SECTOR] == parent)
            elif level == "industrySubGroup":
                filters.append(c[COL_INDUSTRY] == parent)
            elif level == "company":
                filters.append(c[COL_SUBGROUP] == parent)

        # Market cap tier -> cap_class buckets.
        if market_cap and market_cap in CAP_TIER_BUCKET:
            filters.append(c.cap_class == CAP_TIER_BUCKET[market_cap])
        # Market cap bucket (exact cap_class string).
        if market_cap_bucket:
            filters.append(c.cap_class == market_cap_bucket)

        # Company filter (symbol or id).
        if company:
            filters.append(
                or_(c.nse_code == company, c.company_id == company)
            )

        # Company name search (prefix, case-insensitive) across the full universe.
        if company_name:
            filters.append(c.name.ilike(f"{company_name}%"))

        # Snapshot date.
        if date:
            filters.append(c.last_modified == date)

        return filters

    # ------------------------------------------------------------------ #
    # Ordering is by normalised percentage: each metric's share of the
    # 100% stacked bar (metric / (volume + avgVol1W + avgVol1M + avgVol1Y)),
    # so the visual's segment widths sort top-to-bottom as expected.
    def _sort_ratio(self, metric: str, v, w, m, y, volsort_expr):
        denom = v + w + m + y
        if metric == "volSortPct":
            return volsort_expr
        metric_col = {"volume": v, "avgVol1W": w, "avgVol1M": m, "avgVol1Y": y}[metric]
        return metric_col / func.nullif(denom, 0)

    # ------------------------------------------------------------------ #
    # Aggregated levels (sector / industry / industrySubGroup)
    # ------------------------------------------------------------------ #
    def _aggregate_level(
        self,
        level: str,
        filters: List[Any],
        sort_metric: str,
        direction: str,
        limit: int,
        offset: int,
    ) -> Dict[str, Any]:
        c = self.table.c
        group_col = self.table.c[LEVEL_GROUP_COLUMN[level]]

        # Exclude empty/unnamed groups so they don't appear as a blank category.
        filters = filters + [group_col.isnot(None), group_col != ""]

        # Parent labels (constant within the group, so MAX is safe).
        if level == "sector":
            sector_label = group_col
            industry_label = literal("")
            subgroup_label = literal("")
        elif level == "industry":
            sector_label = func.max(c[COL_SECTOR])
            industry_label = group_col
            subgroup_label = literal("")
        else:  # industrySubGroup
            sector_label = func.max(c[COL_SECTOR])
            industry_label = func.max(c[COL_INDUSTRY])
            subgroup_label = group_col

        volume_expr = func.sum(c.volume)
        avg1w_expr = func.sum(c.volume_1week_average)
        avg1m_expr = func.sum(c.volume_1month_average)
        avg1y_expr = func.sum(c.volume_1year_average)
        volsort_expr = func.avg(c.volume_vs_1year_avg)
        mcap_expr = func.sum(c.market_capitalization)
        count_expr = func.count(c.company_id)

        query = self.db.query(
            group_col.label("id"),
            group_col.label("name"),
            sector_label.label("sector"),
            industry_label.label("industry"),
            subgroup_label.label("industrySubGroup"),
            volume_expr.label("volume"),
            avg1w_expr.label("avgVol1W"),
            avg1m_expr.label("avgVol1M"),
            avg1y_expr.label("avgVol1Y"),
            volsort_expr.label("volSortPct"),
            mcap_expr.label("marketCap"),
            count_expr.label("companyCount"),
        ).filter(*filters).group_by(group_col)

        # Total distinct groups (for pagination metadata).
        total = self.db.query(group_col).filter(*filters).distinct().count()

        order_expr = self._sort_ratio(sort_metric, volume_expr, avg1w_expr, avg1m_expr, avg1y_expr, volsort_expr)
        query = query.order_by(
            order_expr.desc().nullslast() if direction == "desc" else order_expr.asc().nullslast()
        )

        rows = query.limit(limit).offset(offset).all()
        result = self._rows_to_result(level, rows, offset)
        return {"level": level, "total": total, "rows": result}


    # ------------------------------------------------------------------ #
    # Company level (no aggregation)
    # ------------------------------------------------------------------ #
    def _company_level(
        self,
        filters: List[Any],
        sort_metric: str,
        direction: str,
        limit: int,
        offset: int,
    ) -> Dict[str, Any]:
        c = self.table.c
        v = c.volume
        w = c.volume_1week_average
        m = c.volume_1month_average
        y = c.volume_1year_average
        volsort_expr = c.volume_vs_1year_avg

        # NOTE: do NOT filter on nse_code here. nse_code is only populated for
        # ~2,972 of the 5,332 rows; the remaining companies (BSE-only / no NSE
        # symbol) must still appear. Use company_id as the universal identifier.
        query = self.db.query(
            c.company_id.label("id"),
            c.name.label("name"),
            c[COL_SECTOR].label("sector"),
            c[COL_INDUSTRY].label("industry"),
            c[COL_SUBGROUP].label("industrySubGroup"),
            v.label("volume"),
            w.label("avgVol1W"),
            m.label("avgVol1M"),
            y.label("avgVol1Y"),
            volsort_expr.label("volSortPct"),
            c.market_capitalization.label("marketCap"),
            c.cap_class.label("marketCapBucket"),
            literal(None).label("companyCount"),
        ).filter(*filters)

        total = self.db.query(c.company_id).filter(*filters).count()

        order_expr = self._sort_ratio(sort_metric, v, w, m, y, volsort_expr)
        query = query.order_by(
            order_expr.desc().nullslast() if direction == "desc" else order_expr.asc().nullslast()
        )

        rows = query.limit(limit).offset(offset).all()
        result = self._rows_to_result("company", rows, offset)
        return {"level": "company", "total": total, "rows": result}

    # ------------------------------------------------------------------ #
    # Row mapping
    # ------------------------------------------------------------------ #
    def _rows_to_result(self, level: str, rows, offset: int) -> List[Dict[str, Any]]:
        result: List[Dict[str, Any]] = []
        for i, row in enumerate(rows):
            result.append({
                "id": row.id,
                "name": row.name,
                "sector": row.sector or "",
                "industry": row.industry or "",
                "industrySubGroup": row.industrySubGroup or "",
                "volume": _f(row.volume),
                "avgVol1W": _f(row.avgVol1W),
                "avgVol1M": _f(row.avgVol1M),
                "avgVol1Y": _f(row.avgVol1Y),
                "volSortPct": _f(row.volSortPct),
                "marketCap": _f(row.marketCap),
                "marketCapBucket": getattr(row, "marketCapBucket", "") or "",
                "companyCount": int(row.companyCount) if row.companyCount is not None else None,
                "rank": offset + i + 1,
                "total": _f(row.volume),
            })
        return result


def _f(value) -> float:
    try:
        if value is None:
            return 0.0
        return float(value)
    except (TypeError, ValueError):
        return 0.0
