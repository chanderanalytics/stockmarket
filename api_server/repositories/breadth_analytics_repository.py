"""
BreadthAnalyticsRepository — three-layer market breadth analytics engine.

Layer 1 - Raw Indicators (computed on demand from price history)
    DMA20/50/100/200 at offset 0 (today) and at each horizon H.

Layer 2 - Signals (binary 0/1)
    above20dma / above50dma / above100dma / above200dma at each horizon.
    advance / decline at each horizon.

Layer 3 - Breadth Metrics (aggregated across companies / groups)
    SUM(signal) / COUNT(companies) = percentage.
    Composite Breadth Score, Trend Strength, Advance/Decline ratio.

Horizons: 1d, 5d, 21d, 63d, 126d, 256d represent the breadth snapshot
that many trading days ago (history of breadth, used as grid columns).
"""

from sqlalchemy.orm import Session
from sqlalchemy import Table, MetaData, func, case, and_, desc
from fastapi import HTTPException
from typing import List, Dict, Any, Optional
import os
import pickle
import statistics
import time

COL_SECTOR = "Sector.Name_bse"
COL_INDUSTRY = "Industry.New.Name_bse"
COL_SUBGROUP = "ISubgroup.Name_bse"
COL_GROUP = "Igroup.Name_bse"

DEFAULT_DMA_PERIODS = [20, 50, 100, 200]
DEFAULT_HORIZONS = [1, 5, 21, 63, 126, 256]
TREND_WEIGHTS = {20: 20, 50: 30, 100: 20, 200: 30}
DEFAULT_DMA_WEIGHTS = {20: 0.15, 50: 0.25, 100: 0.25, 200: 0.35}

TREND_THRESHOLDS = {
    20: {"accelerating": 3.0, "improving": 1.0, "stable": 1.0, "cooling": -1.0, "weakening": -3.0},
    50: {"accelerating": 4.5, "improving": 1.5, "stable": 1.5, "cooling": -1.5, "weakening": -4.5},
    100: {"accelerating": 6.0, "improving": 2.5, "stable": 2.5, "cooling": -2.5, "weakening": -6.0},
    200: {"accelerating": 8.0, "improving": 3.5, "stable": 3.5, "cooling": -3.5, "weakening": -8.0},
}

SIGNAL_CHOICES = ["above20dma", "above50dma", "above100dma", "above200dma"]

CAP_TIER_BUCKET = {
    "large": "top 10perc by mcap",
    "mid": "50-90% by mcap",
    "small": "bottom 50% by mcap",
}

_CACHE_FILE = "/var/tmp/breadth_signals_cache.pkl"
_CACHE_TTL = 86400  # 24 hours


def _load_persistent_cache() -> dict:
    if not os.path.exists(_CACHE_FILE):
        return {}
    try:
        with open(_CACHE_FILE, "rb") as f:
            data = pickle.load(f)
        if not isinstance(data, dict) or data.get("version") != 1:
            return {}
        cache = data.get("cache", {})
        ts = data.get("ts", 0)
        if time.time() - ts > _CACHE_TTL:
            return {}
        return cache
    except Exception:
        return {}


def _save_persistent_cache(cache: dict) -> None:
    try:
        with open(_CACHE_FILE, "wb") as f:
            pickle.dump({"version": 1, "cache": cache, "ts": time.time()}, f)
    except Exception:
        pass


_ALL_SIGNALS_CACHE = _load_persistent_cache()
_ALL_SIGNALS_TS = time.time()
_ALL_SIGNALS_TTL = _CACHE_TTL


class BreadthAnalyticsRepository:
    def __init__(self, db: Session):
        self.db = db
        engine = db.get_bind()
        metadata = MetaData()
        self.wide_table = Table(
            "merged_price_baseline_probabilities_wide", metadata, autoload_with=engine
        )
        self.prices_table = Table(
            "prices_bhavcopy_2", metadata, autoload_with=engine
        )
        self.signals_table = Table(
            "company_breadth_signals", metadata, autoload_with=engine
        )

    # ------------------------------------------------------------------ #
    # Public API
    # ------------------------------------------------------------------ #
    def get_breadth_summary(
        self,
        date: Optional[str] = None,
        dma_periods: Optional[List[int]] = None,
        dma_weights: Optional[Dict[int, float]] = None,
        horizons: Optional[List[int]] = None,
        signal_type: str = "above50dma",
        market_cap=None, market_cap_bucket=None, company_name=None,
    ) -> Dict[str, Any]:
        if signal_type not in SIGNAL_CHOICES:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid signalType '{signal_type}'. Must be one of: {', '.join(SIGNAL_CHOICES)}.",
            )
        dma_periods = dma_periods or DEFAULT_DMA_PERIODS
        dma_weights = dma_weights or DEFAULT_DMA_WEIGHTS
        horizons = horizons or DEFAULT_HORIZONS

        companies = self._get_company_metrics(dma_periods, horizons, market_cap=market_cap, market_cap_bucket=market_cap_bucket, company_name=company_name)
        total = len(companies)
        if total == 0:
            return self._empty_summary(horizons, dma_periods, signal_type)

        breadth_by_horizon = {
            str(h): self._aggregate_companies_for_horizon(companies, h, dma_periods, dma_weights, total, signal_type=signal_type)
            for h in horizons
        }

        summary = self._aggregate_companies(companies, dma_periods, dma_weights, total, signal_type)
        summary["totalCompanies"] = total
        summary["breadthByHorizon"] = breadth_by_horizon

        period = int(signal_type.replace("above", "").replace("dma", "")) if signal_type else 50
        dists = []
        for h in horizons:
            h_data = breadth_by_horizon.get(str(h), {})
            d_data = h_data.get("dmaDistance", {}).get(f"dma{period}")
            dists.append(float(d_data["distance"]) if d_data and d_data.get("distance") is not None else 0)

        trend_score, trend_classification, _ = self._compute_trend_score(dists, period)
        summary["trendScore"] = trend_score
        summary["trendClassification"] = trend_classification

        trend_score_by_dma = {}
        for p in dma_periods:
            p_dists = []
            for h in horizons:
                h_data = breadth_by_horizon.get(str(h), {})
                d_data = h_data.get("dmaDistance", {}).get(f"dma{p}")
                p_dists.append(float(d_data["distance"]) if d_data and d_data.get("distance") is not None else 0)
            p_score, p_classification, _ = self._compute_trend_score(p_dists, p)
            trend_score_by_dma[f"dma{p}"] = {"score": p_score, "classification": p_classification}
        summary["trendScoreByDMA"] = trend_score_by_dma
        return summary

    def get_sector_breadth(
        self, sector=None, industry=None, industry_sub_group=None,
        dma_periods=None, dma_weights=None, horizons=None,
        sort_by="breadthScore", sort_dir="desc", limit=50, offset=0,
        signal_type="above50dma",
        market_cap=None, market_cap_bucket=None, company_name=None,
    ):
        return self._grouped_breadth(
            COL_SECTOR, sector, industry, industry_sub_group, None,
            dma_periods, dma_weights, horizons, sort_by, sort_dir, limit, offset, "sector", signal_type,
            market_cap=market_cap, market_cap_bucket=market_cap_bucket, company_name=company_name,
        )

    def get_industry_breadth(
        self, sector=None, industry_group=None, industry_sub_group=None,
        dma_periods=None, dma_weights=None, horizons=None,
        sort_by="breadthScore", sort_dir="desc", limit=50, offset=0,
        signal_type="above50dma",
        market_cap=None, market_cap_bucket=None, company_name=None,
    ):
        return self._grouped_breadth(
            COL_INDUSTRY, sector, None, industry_sub_group, industry_group,
            dma_periods, dma_weights, horizons, sort_by, sort_dir, limit, offset, "industry", signal_type,
            market_cap=market_cap, market_cap_bucket=market_cap_bucket, company_name=company_name,
        )

    def get_company_breadth(
        self, sector=None, industry=None, industry_sub_group=None,
        dma_periods=None, dma_weights=None, horizons=None,
        sort_by="breadthScore", sort_dir="desc", limit=50, offset=0,
        signal_type="above50dma",
        market_cap=None, market_cap_bucket=None, company_name=None,
    ):
        if signal_type not in SIGNAL_CHOICES:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid signalType '{signal_type}'. Must be one of: {', '.join(SIGNAL_CHOICES)}.",
            )
        dma_periods = dma_periods or DEFAULT_DMA_PERIODS
        dma_weights = dma_weights or DEFAULT_DMA_WEIGHTS
        horizons = horizons or DEFAULT_HORIZONS

        companies = self._get_company_metrics(dma_periods, horizons, sector, industry, industry_sub_group, None, market_cap, market_cap_bucket, company_name)
        rows = []
        for c in companies:
            row = self._company_row(c, dma_periods, dma_weights, horizons, signal_type)

            period = int(signal_type.replace("above", "").replace("dma", "")) if signal_type else 50
            dists = []
            for h in horizons:
                h_data = row.get("horizons", {}).get(str(h), {})
                d_data = h_data.get("dmaDistance", {}).get(f"dma{period}")
                dists.append(float(d_data["distance"]) if d_data and d_data.get("distance") is not None else 0)
            trend_score, trend_classification, _ = self._compute_trend_score(dists, period)
            row["trendScore"] = trend_score
            row["trendClassification"] = trend_classification

            trend_score_by_dma = {}
            for p in dma_periods:
                p_dists = []
                for h in horizons:
                    h_data = row.get("horizons", {}).get(str(h), {})
                    d_data = h_data.get("dmaDistance", {}).get(f"dma{p}")
                    p_dists.append(float(d_data["distance"]) if d_data and d_data.get("distance") is not None else 0)
                p_score, p_classification, _ = self._compute_trend_score(p_dists, p)
                trend_score_by_dma[f"dma{p}"] = {"score": p_score, "classification": p_classification}
            row["trendScoreByDMA"] = trend_score_by_dma
            rows.append(row)

        rows.sort(key=lambda x: x.get(sort_by, 0), reverse=(sort_dir != "asc"))
        total = len(rows)
        return {"level": "company", "total": total, "rows": rows[offset:offset + limit]}

    def get_subgroup_breadth(
        self, sector=None, industry=None, industry_sub_group=None,
        dma_periods=None, dma_weights=None, horizons=None,
        sort_by="breadthScore", sort_dir="desc", limit=50, offset=0,
        signal_type="above50dma",
        market_cap=None, market_cap_bucket=None, company_name=None,
    ):
        return self._grouped_breadth(
            COL_SUBGROUP, sector, industry, industry_sub_group, None,
            dma_periods, dma_weights, horizons, sort_by, sort_dir, limit, offset, "industrySubGroup", signal_type,
            market_cap=market_cap, market_cap_bucket=market_cap_bucket, company_name=company_name,
        )

    def get_breadth_distribution(self, dma_periods=None, horizons=None, market_cap=None, market_cap_bucket=None, company_name=None):
        dma_periods = dma_periods or DEFAULT_DMA_PERIODS
        horizons = horizons or DEFAULT_HORIZONS
        companies = self._get_company_metrics(dma_periods, horizons, market_cap=market_cap, market_cap_bucket=market_cap_bucket, company_name=company_name)
        total = len(companies)
        if total == 0:
            return {"total": 0, "distribution": {}}
        distribution = {}
        for period in dma_periods:
            col = f"sig_above_{period}dma_0"
            above = sum(c[col] for c in companies)
            distribution[f"dma{period}"] = {
                "above": {"count": above, "percentage": round(above / total * 100, 1)},
                "below": {"count": total - above, "percentage": round((total - above) / total * 100, 1)},
            }
        return {"total": total, "distribution": distribution}

    def get_breadth_history(self, period="1y", dma_periods=None, horizons=None):
        dma_periods = dma_periods or [20, 50, 200]
        days = {"1m": 30, "3m": 90, "6m": 180, "1y": 365}.get(period, 365)
        import random
        from datetime import datetime, timedelta
        base = datetime.now()
        dates = [(base - timedelta(days=days - i)).isoformat() for i in range(days)]
        history = []
        for d in dates:
            history.append({
                "date": d,
                "compositeBreadth": 40 + random.random() * 30,
                **{f"dma{p}": 35 + random.random() * 35 for p in dma_periods},
            })
        return {
            "period": period,
            "dates": [h["date"] for h in history],
            "series": {
                "compositeBreadth": [h["compositeBreadth"] for h in history],
                **{f"dma{p}": [h[f"dma{p}"] for h in history] for p in dma_periods},
            },
        }

    # ------------------------------------------------------------------ #
    # Internals
    # ------------------------------------------------------------------ #
    def _grouped_breadth(
        self, group_col, sector, industry, industry_sub_group, industry_group,
        dma_periods, dma_weights, horizons, sort_by, sort_dir, limit, offset, level,
        signal_type="above50dma",
        market_cap=None, market_cap_bucket=None, company_name=None,
    ):
        if signal_type not in SIGNAL_CHOICES:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid signalType '{signal_type}'. Must be one of: {', '.join(SIGNAL_CHOICES)}.",
            )
        dma_periods = dma_periods or DEFAULT_DMA_PERIODS
        dma_weights = dma_weights or DEFAULT_DMA_WEIGHTS
        horizons = horizons or DEFAULT_HORIZONS

        companies = self._get_company_metrics(
            dma_periods, horizons, sector, industry, industry_sub_group, industry_group,
            market_cap=market_cap, market_cap_bucket=market_cap_bucket, company_name=company_name,
        )
        if not companies:
            return {"level": level, "total": 0, "rows": []}

        from collections import defaultdict
        groups = defaultdict(list)
        for c in companies:
            name = c.get(group_col, "") or ""
            if name:
                groups[name].append(c)

        rows = []
        total_all = len(companies)
        for name, group in groups.items():
            row = self._aggregate_companies(group, dma_periods, dma_weights, len(group), signal_type)
            row["id"] = ""
            row["name"] = name
            row["companyCount"] = len(group)
            first = group[0]
            row["sector"] = first.get(COL_SECTOR) or ""
            row["industry"] = first.get(COL_INDUSTRY) or ""
            row["industrySubGroup"] = first.get(COL_SUBGROUP) or ""
            row["horizons"] = {
                str(h): self._aggregate_companies_for_horizon(group, h, dma_periods, dma_weights, len(group), signal_type=signal_type)
                for h in horizons
            }

            period = int(signal_type.replace("above", "").replace("dma", "")) if signal_type else 50
            dists = []
            for h in horizons:
                h_data = row["horizons"].get(str(h), {})
                d_data = h_data.get("dmaDistance", {}).get(f"dma{period}")
                dists.append(float(d_data["distance"]) if d_data and d_data.get("distance") is not None else 0)
            trend_score, trend_classification, _ = self._compute_trend_score(dists, period)
            row["trendScore"] = trend_score
            row["trendClassification"] = trend_classification

            trend_score_by_dma = {}
            for p in dma_periods:
                p_dists = []
                for h in horizons:
                    h_data = row["horizons"].get(str(h), {})
                    d_data = h_data.get("dmaDistance", {}).get(f"dma{p}")
                    p_dists.append(float(d_data["distance"]) if d_data and d_data.get("distance") is not None else 0)
                p_score, p_classification, _ = self._compute_trend_score(p_dists, p)
                trend_score_by_dma[f"dma{p}"] = {"score": p_score, "classification": p_classification}
            row["trendScoreByDMA"] = trend_score_by_dma
            rows.append(row)

        rows.sort(key=lambda x: x.get(sort_by, 0), reverse=(sort_dir != "asc"))
        return {"level": level, "total": len(rows), "rows": rows[offset:offset + limit]}

    def refresh_cache(self, dma_periods=None, horizons=None):
        dma_periods = dma_periods or DEFAULT_DMA_PERIODS
        horizons = horizons or DEFAULT_HORIZONS
        self._populate_signals_table(dma_periods, horizons)
        key = (tuple(sorted(dma_periods)), tuple(sorted(horizons)))
        global _ALL_SIGNALS_CACHE, _ALL_SIGNALS_TS
        if key in _ALL_SIGNALS_CACHE:
            del _ALL_SIGNALS_CACHE[key]
        _ALL_SIGNALS_TS = 0.0
        return self._get_all_signals(dma_periods, horizons)

    def _populate_signals_table(self, dma_periods, horizons):
        c = self.wide_table.c
        company_cols = [
            c.company_id, c.name, c[COL_SECTOR], c[COL_INDUSTRY],
            c[COL_SUBGROUP], c[COL_GROUP], c.market_capitalization, c.cap_class,
            c.latest_close, c.pchg_252d,
            c.volume, c.volume_1year_average,
            c.high_price_all_time, c.low_price_all_time,
        ]
        companies = self.db.query(*company_cols).filter(c.market_capitalization.isnot(None), c.market_capitalization > 0).all()
        if not companies:
            return

        company_ids = [r.company_id for r in companies]
        price_map = self._fetch_price_series(company_ids, dma_periods, horizons)

        rows_to_upsert = []
        for r in companies:
            cid = str(r.company_id)
            series = price_map.get(cid)
            if not series:
                continue
            sig = self._build_company_signals(r, series, dma_periods, horizons)

            row = {
                "company_id": int(cid),
                "name": sig.get("name"),
                "sector": sig.get(COL_SECTOR) or "",
                "industry": sig.get(COL_INDUSTRY) or "",
                "industry_sub_group": sig.get(COL_SUBGROUP) or "",
                "industry_group": sig.get(COL_GROUP) or "",
                "market_cap": sig.get("market_cap"),
                "cap_class": sig.get("cap_class") or "",
                "latest_close": sig.get("latest_close"),
                "return_252d": sig.get("return_252d"),
                "volume": int(sig.get("volume", 0) or 0),
                "avg_volume_1y": int(sig.get("avg_volume_1y", 0) or 0),
                "high_price_all_time": sig.get("high_price_all_time"),
                "low_price_all_time": sig.get("low_price_all_time"),
                "sig_new_high_0": sig.get("sig_new_high_0"),
                "sig_new_low_0": sig.get("sig_new_low_0"),
                "dma_20_0": (sig.get("dma_0") or {}).get(20),
                "dma_50_0": (sig.get("dma_0") or {}).get(50),
                "dma_100_0": (sig.get("dma_0") or {}).get(100),
                "dma_200_0": (sig.get("dma_0") or {}).get(200),
            }
            for h in sorted(set(horizons)):
                for p in dma_periods:
                    row[f"sig_above_{p}dma_{h}"] = sig.get(f"sig_above_{p}dma_{h}", 0)
                    row[f"dma_dist_{p}_{h}"] = sig.get(f"dma_dist_{p}_{h}")
                row[f"sig_advance_{h}"] = sig.get(f"sig_advance_{h}", 0)
                row[f"sig_decline_{h}"] = sig.get(f"sig_decline_{h}", 0)

            rows_to_upsert.append(row)

        if not rows_to_upsert:
            return

        t = self.signals_table
        self.db.execute(t.delete())
        self.db.execute(t.insert(), rows_to_upsert)
        self.db.commit()

    def _get_all_signals(self, dma_periods, horizons):
        global _ALL_SIGNALS_CACHE, _ALL_SIGNALS_TS
        key = (tuple(sorted(dma_periods)), tuple(sorted(horizons)))
        now = time.time()
        if key in _ALL_SIGNALS_CACHE and (now - _ALL_SIGNALS_TS) < _ALL_SIGNALS_TTL:
            return _ALL_SIGNALS_CACHE[key]

        table_rows = self._load_from_signals_table()
        if table_rows:
            _ALL_SIGNALS_CACHE[key] = table_rows
            _ALL_SIGNALS_TS = now
            return table_rows

        c = self.wide_table.c
        filters = [c.market_capitalization.isnot(None), c.market_capitalization > 0]
        company_cols = [
            c.company_id, c.name, c[COL_SECTOR], c[COL_INDUSTRY],
            c[COL_SUBGROUP], c[COL_GROUP], c.market_capitalization, c.cap_class,
            c.latest_close, c.pchg_1d, c.pchg_252d,
            c.volume, c.volume_1year_average,
            c.high_price_all_time, c.low_price_all_time,
        ]
        companies = self.db.query(*company_cols).filter(*filters).all()
        if not companies:
            return []

        company_ids = [r.company_id for r in companies]
        price_map = self._fetch_price_series(company_ids, dma_periods, horizons)

        results = []
        for r in companies:
            cid = str(r.company_id)
            series = price_map.get(cid)
            if not series:
                continue
            results.append(self._build_company_signals(r, series, dma_periods, horizons))

        _ALL_SIGNALS_CACHE[key] = results
        _ALL_SIGNALS_TS = now
        _save_persistent_cache(_ALL_SIGNALS_CACHE)
        return results

    def _load_from_signals_table(self):
        try:
            t = self.signals_table
            count = self.db.query(func.count(t.c.company_id)).scalar()
            if not count:
                return []
            rows = self.db.query(t).all()
            results = []
            for r in rows:
                m = r._mapping
                sig = {
                    "company_id": str(m[t.c.company_id]),
                    "name": m[t.c.name],
                    COL_SECTOR: m[t.c.sector] or "",
                    COL_INDUSTRY: m[t.c.industry] or "",
                    COL_SUBGROUP: m[t.c.industry_sub_group] or "",
                    COL_GROUP: m[t.c.industry_group] or "",
                    "market_cap": float(m[t.c.market_cap] or 0),
                    "cap_class": m[t.c.cap_class] or "",
                    "latest_close": float(m[t.c.latest_close] or 0),
                    "return_252d": float(m[t.c.return_252d] or 0),
                    "volume": int(m[t.c.volume] or 0),
                    "avg_volume_1y": int(m[t.c.avg_volume_1y] or 0),
                    "high_price_all_time": float(m[t.c.high_price_all_time] or 0),
                    "low_price_all_time": float(m[t.c.low_price_all_time] or 0),
                    "sig_new_high_0": int(m[t.c.sig_new_high_0] or 0),
                    "sig_new_low_0": int(m[t.c.sig_new_low_0] or 0),
                    "dma_0": {
                        "20": float(m[t.c.dma_20_0] or 0),
                        "50": float(m[t.c.dma_50_0] or 0),
                        "100": float(m[t.c.dma_100_0] or 0),
                        "200": float(m[t.c.dma_200_0] or 0),
                    },
                }
                cols = list(m)
                for col in cols:
                    if str(col).startswith("sig_above_") or str(col).startswith("sig_advance_") or str(col).startswith("sig_decline_"):
                        sig[col] = int(m[col] or 0)
                    if str(col).startswith("dma_dist_"):
                        raw = m[col]
                        sig[col] = float(raw) if raw is not None else None
                results.append(sig)
            return results
        except Exception:
            return []

    def _get_company_metrics(
        self, dma_periods, horizons, sector=None, industry=None,
        industry_sub_group=None, industry_group=None,
        market_cap=None, market_cap_bucket=None, company_name=None,
    ):
        all_signals = self._get_all_signals(dma_periods, horizons)

        filtered = all_signals
        if sector:
            filtered = [c for c in filtered if c.get(COL_SECTOR) == sector]
        if industry:
            filtered = [c for c in filtered if c.get(COL_INDUSTRY) == industry]
        if industry_sub_group:
            filtered = [c for c in filtered if c.get(COL_SUBGROUP) == industry_sub_group]
        if industry_group:
            filtered = [c for c in filtered if c.get(COL_GROUP) == industry_group]
        if market_cap and market_cap in CAP_TIER_BUCKET:
            filtered = [c for c in filtered if c.get("cap_class") == CAP_TIER_BUCKET[market_cap]]
        if market_cap_bucket:
            filtered = [c for c in filtered if c.get("cap_class") == market_cap_bucket]
        if company_name:
            filtered = [c for c in filtered if c.get("name", "").lower().startswith(company_name.lower())]

        return filtered

    def _fetch_price_series(self, company_ids, dma_periods, horizons):
        """One query: for each company compute close and DMA at offset 0 and each horizon."""
        if not company_ids:
            return {}
        all_horizons = sorted(set([0] + list(horizons)))
        max_horizon = max(all_horizons)
        max_period = max(dma_periods)
        days_back = max_horizon + max_period + 10

        p = self.prices_table.c
        latest_date = self.db.query(func.max(p.timestamp)).scalar()
        if not latest_date:
            return {}
        from datetime import timedelta
        cutoff = latest_date - timedelta(days=days_back)

        # Compute price series keyed by OFFSET (0 = today, 1 = 1 day ago, ...).
        # Horizon "1" maps to offset 0 (today / end-of-day breadth).
        offsets = sorted(set([0] + [self._horizon_offset(h) for h in horizons]))
        max_offset = max(offsets)

        ranked = (
            self.db.query(
                p.company_id, p.close,
                func.row_number().over(partition_by=p.company_id, order_by=p.timestamp.desc()).label("rn"),
            )
            .filter(p.company_id.in_(company_ids))
            .filter(p.timestamp >= cutoff)
            .subquery()
        )

        exprs = [ranked.c.company_id]
        close_exprs = {}
        for off in offsets:
            lbl = f"close_{off}"
            close_exprs[off] = func.max(case((ranked.c.rn == off + 1, ranked.c.close), else_=None)).label(lbl)
            exprs.append(close_exprs[off])
        dma_exprs = {}
        for off in offsets:
            dma_exprs[off] = {}
            for P in dma_periods:
                lbl = f"dma{P}_{off}"
                cond = (ranked.c.rn >= off + 1) & (ranked.c.rn <= off + P)
                dma_exprs[off][P] = func.avg(case((cond, ranked.c.close), else_=None)).label(lbl)
                exprs.append(dma_exprs[off][P])

        query = self.db.query(*exprs).group_by(ranked.c.company_id)
        out = {}
        for row in query.all():
            m = row._mapping
            cid = str(m[ranked.c.company_id])
            closes = {off: float(m[close_exprs[off].name]) if m[close_exprs[off].name] is not None else None for off in offsets}
            dmas = {}
            for off in offsets:
                dmas[off] = {}
                for P in dma_periods:
                    v = m[dma_exprs[off][P].name]
                    dmas[off][P] = float(v) if v is not None else None
            out[cid] = {"closes": closes, "dmas": dmas}
        return out

    @staticmethod
    def _horizon_offset(h: int) -> int:
        # 1d column represents today (end-of-day) => offset 0.
        return 0 if h == 1 else h

    def _build_company_signals(self, r, series, dma_periods, horizons):
        cid = str(r.company_id)
        latest_close = float(r.latest_close or 0)
        market_cap = float(r.market_capitalization or 0)

        out = {
            "company_id": cid,
            "name": r.name,
            COL_SECTOR: getattr(r, COL_SECTOR, ""),
            COL_INDUSTRY: getattr(r, COL_INDUSTRY, ""),
            COL_SUBGROUP: getattr(r, COL_SUBGROUP, ""),
            COL_GROUP: getattr(r, COL_GROUP, ""),
            "market_cap": market_cap,
            "cap_class": getattr(r, "cap_class", "") or "",
            "latest_close": latest_close,
            "return_252d": float(r.pchg_252d or 0),
            "volume": float(r.volume or 0),
            "avg_volume_1y": float(r.volume_1year_average or 1),
            "high_price_all_time": float(r.high_price_all_time or 0),
            "low_price_all_time": float(r.low_price_all_time or 0),
        }

        for h in sorted(set(horizons)):
            off = 0 if h == 1 else h  # 1d == today (end-of-day)
            close_h = series["closes"].get(off)
            dmas_h = series["dmas"].get(off, {})
            for P in dma_periods:
                dma_val = dmas_h.get(P)
                sig = 1 if (close_h is not None and dma_val is not None and close_h > dma_val) else 0
                out[f"sig_above_{P}dma_{h}"] = sig
                if close_h is not None and dma_val is not None and dma_val != 0:
                    out[f"dma_dist_{P}_{h}"] = round((close_h - dma_val) / dma_val * 100, 2)
                else:
                    out[f"dma_dist_{P}_{h}"] = None
            close_next = series["closes"].get(off + 1)
            adv = 1 if (close_h is not None and close_next is not None and close_h > close_next) else 0
            out[f"sig_advance_{h}"] = adv
            out[f"sig_decline_{h}"] = 1 - adv

        # Current extras (offset 0)
        out["sig_new_high_0"] = 1 if (latest_close >= float(r.high_price_all_time or 0) and latest_close > 0) else 0
        out["sig_new_low_0"] = 1 if (latest_close <= float(r.low_price_all_time or 0) and latest_close > 0) else 0
        out["dma_0"] = series["dmas"].get(0, {})
        return out

    def _aggregate_companies(self, companies, dma_periods, dma_weights, total, signal_type="above50dma"):
        return self._aggregate_companies_for_horizon(companies, 1, dma_periods, dma_weights, total, is_current=True, signal_type=signal_type)

    def _aggregate_companies_for_horizon(self, companies, horizon, dma_periods, dma_weights, total, is_current=False, signal_type="above50dma"):
        sig_cols = {P: f"sig_above_{P}dma_{horizon}" for P in dma_periods}
        above_counts = {P: sum(c.get(sig_cols[P], 0) for c in companies) for P in dma_periods}
        above_pcts = {P: above_counts[P] / total * 100 if total else 0 for P in dma_periods}

        wsum = sum(dma_weights.get(P, 0.0) for P in dma_periods)
        composite = sum(above_pcts[P] * dma_weights.get(P, 0.0) for P in dma_periods) / wsum if wsum else 0.0
        trend = sum(above_pcts[P] / 100 * TREND_WEIGHTS.get(P, 0) for P in dma_periods)

        advances = sum(c.get(f"sig_advance_{horizon}", 0) for c in companies)
        declines = sum(c.get(f"sig_decline_{horizon}", 0) for c in companies)
        ad = round(advances / declines, 2) if declines else 1.0

        primary = self._primary_signal(companies, horizon, signal_type, total)

        dist_vals = {P: [float(v) for c in companies for v in [c.get(f"dma_dist_{P}_{horizon}")] if v is not None] for P in dma_periods}
        median_dist = {P: round(statistics.median(dist_vals[P]), 1) if dist_vals[P] else None for P in dma_periods}

        res = {
            "breadthScore": round(primary, 1),
            "trendStrength": round(trend, 1),
            "advanceDeclineRatio": ad,
            "aboveDMA": {f"dma{P}": {"count": above_counts[P], "percentage": round(above_pcts[P], 1)} for P in dma_periods},
            "signalType": signal_type,
            "compositeBreadth": round(composite, 1),
            "dmaDistance": {f"dma{P}": {"distance": median_dist[P]} for P in dma_periods},
        }
        if is_current:
            total_cap = sum(c["market_cap"] for c in companies)
            weighted_return = sum(c["return_252d"] * c["market_cap"] for c in companies) / total_cap if total_cap else 0.0
            tv = sum(c["volume"] for c in companies)
            tav = sum(c["avg_volume_1y"] for c in companies)
            rel_vol = tv / tav if tav else 1.0
            new_high = sum(c.get("sig_new_high_0", 0) for c in companies) / total * 100 if total else 0.0
            new_low = sum(c.get("sig_new_low_0", 0) for c in companies) / total * 100 if total else 0.0
            res.update({
                "weightedReturn": round(weighted_return, 2),
                "relativeVolume": round(rel_vol, 2),
                "newHighPct": round(new_high, 1),
                "newLowPct": round(new_low, 1),
                "marketCap": round(total_cap, 2),
            })
        return res

    def _company_row(self, c, dma_periods, dma_weights, horizons, signal_type="above50dma"):
        sig_cols = {P: f"sig_above_{P}dma_1" for P in dma_periods}  # 1 == today
        wsum = sum(dma_weights.get(P, 0.0) for P in dma_periods)
        breadth = sum(c[sig_cols[P]] * dma_weights.get(P, 0.0) for P in dma_periods) / wsum * 100 if wsum else 0.0
        trend = sum(c[sig_cols[P]] * TREND_WEIGHTS.get(P, 0) for P in dma_periods)
        primary = self._primary_signal([c], 1, signal_type, 1)
        row = {
            "id": c["company_id"],
            "name": c["name"],
            "companyCount": 1,
            "sector": c.get(COL_SECTOR, ""),
            "industry": c.get(COL_INDUSTRY, ""),
            "industrySubGroup": c.get(COL_SUBGROUP, ""),
            "marketCap": round(c["market_cap"], 2),
            "close": round(c["latest_close"], 2),
            "return252d": round(c["return_252d"], 2),
            "volume": c["volume"],
            "avgVolume1Y": c["avg_volume_1y"],
            "breadthScore": round(primary, 1),
            "trendStrength": round(trend, 1),
            "relativeVolume": round(c["volume"] / c["avg_volume_1y"], 2) if c["avg_volume_1y"] else 0.0,
            "aboveDMA": {f"dma{P}": {"flag": bool(c[sig_cols[P]]), "dmaValue": round(float(c["dma_0"].get(P) or 0), 2)} for P in dma_periods},
            "compositeBreadth": round(breadth, 1),
            "dmaDistance": {f"dma{P}": {"distance": round(float(c.get(f"dma_dist_{P}_1") or 0), 1)} for P in dma_periods},
            "horizons": {},
            "signalType": signal_type,
        }
        for h in horizons:
            hsig = {P: f"sig_above_{P}dma_{h}" for P in dma_periods}
            hbreadth = sum(c[hsig[P]] * dma_weights.get(P, 0.0) for P in dma_periods) / wsum * 100 if wsum else 0.0
            htrend = sum(c[hsig[P]] * TREND_WEIGHTS.get(P, 0) for P in dma_periods)
            adv = c.get(f"sig_advance_{h}", 0)
            dec = c.get(f"sig_decline_{h}", 0)
            hprimary = self._primary_signal([c], h, signal_type, 1)
            row["horizons"][str(h)] = {
                "breadthScore": round(hprimary, 1),
                "trendStrength": round(htrend, 1),
                "advanceDeclineRatio": round(adv / dec, 2) if dec else 1.0,
                "compositeBreadth": round(hbreadth, 1),
                "aboveDMA": {f"dma{P}": {"percentage": round(c[hsig[P]] * 100, 1)} for P in dma_periods},
                "dmaDistance": {f"dma{P}": {"distance": round(float(c.get(f"dma_dist_{P}_{h}") or 0), 1)} for P in dma_periods},
                "signalType": signal_type,
            }
        return row

    @staticmethod
    def _primary_signal(companies, horizon, signal_type, total):
        if total == 0:
            return 0.0
        if not signal_type or not signal_type.startswith("above") or "dma" not in signal_type:
            return 0.0
        # DMA signals only: above20dma, above50dma, above100dma, above200dma
        period = int(signal_type.replace("above", "").replace("dma", ""))
        col = f"sig_above_{period}dma_{horizon}"
        return sum(c.get(col, 0) for c in companies) / total * 100

    @staticmethod
    def _compute_trend_score(distances, dma_period=50):
        """
        distances: ordered list of median distances across consecutive horizons.
        Returns (score, classification, direction).
        """
        if not distances or len(distances) < 2:
            return 0, "Stable", None

        slopes = [distances[i] - distances[i - 1] for i in range(1, len(distances))]

        def _score_slope(s):
            if s > 2:
                return 2
            if s >= 0.5:
                return 1
            if s >= -0.5:
                return 0
            if s >= -2:
                return -1
            return -2

        scores = [_score_slope(s) for s in slopes]
        total = sum(scores)

        direction = None
        if len(slopes) >= 2:
            def _sign(v):
                return 1 if v > 0 else (-1 if v < 0 else 0)
            prev_sign = _sign(slopes[-2])
            curr_sign = _sign(slopes[-1])
            if prev_sign < 0 and curr_sign > 0:
                direction = "recovering"
            elif prev_sign > 0 and curr_sign < 0:
                direction = "breaking_down"

        thresholds = TREND_THRESHOLDS.get(dma_period, TREND_THRESHOLDS[50])

        if direction == "recovering":
            classification = "Recovering"
        elif direction == "breaking_down":
            classification = "Breaking Down"
        elif total >= thresholds["accelerating"]:
            classification = "Accelerating"
        elif total >= thresholds["improving"]:
            classification = "Improving"
        elif total >= -thresholds["stable"]:
            classification = "Stable"
        elif total >= -thresholds["cooling"]:
            classification = "Cooling"
        else:
            classification = "Weakening"

        return total, classification, direction

    def _empty_summary(self, horizons, dma_periods, signal_type="above50dma"):
        empty = {
            "totalCompanies": 0,
            "aboveDMA": {},
            "compositeBreadth": 0.0,
            "trendStrength": 0.0,
            "trendScore": 0,
            "trendClassification": "Stable",
            "advanceDeclineRatio": 0.0,
            "newHighPct": 0.0,
            "newLowPct": 0.0,
            "relativeVolume": 0.0,
            "weightedReturn": 0.0,
            "signalType": signal_type,
        }
        empty["breadthByHorizon"] = {
            str(h): {
                "breadthScore": 0,
                "trendStrength": 0,
                "advanceDeclineRatio": 0,
                "aboveDMA": {f"dma{P}": {"count": 0, "percentage": 0} for P in dma_periods},
                "compositeBreadth": 0.0,
                "dmaDistance": {f"dma{P}": {"distance": None} for P in dma_periods},
                "signalType": signal_type,
            }
            for h in horizons
        }
        return empty
