# Volume Profiling - Averages Visual Specification

> **Status**: Specification only. No code changes. No SQL changes.
> **Purpose**: Implementation contract for recreating the Power BI "Volume Profiling - Averages" visual in Next.js.

---

## 1. Purpose

**Business Question Answered:**
"How is today's trading volume distributed relative to recent averages for each company, and how does that compare across sectors and industries?"

**Use Case:**
Traders and analysts use this visual to identify:
- Unusual volume spikes or drops vs. 1-week, 1-month, and 1-year averages
- Sector/industry-wide volume patterns
- Individual stocks with abnormal volume activity
- Ranking of stocks by volume activity (VolSortPct)

---

## 2. Visual Type

**Primary Type:** 100% Stacked Horizontal Bar Chart

**Alternative Names:**
- Percentage Stacked Bar Chart
- Normalized Stacked Bar Chart
- Volume Profile Chart

**Implementation Notes:**
- Each bar represents one entity (company, industry, or sector)
- Bar segments represent 4 volume metrics
- All segments sum to exactly 100%
- Length of each segment = that metric's percentage share of the total

---

## 3. Measures (X-Axis / Legend)

The chart displays 4 volume metrics. Each metric becomes a colored segment in the stacked bar.

| Measure | Display Name | Definition | Calculation |
|---|---|---|---|
| `Volume` | Volume | Today's trading volume | `latest_volume` or `volume_1d` from database |
| `AvgVol_1W` | 1-Week Average | Average daily volume over last 5 trading days | `volume_1week_average` from database |
| `AvgVol_1M` | 1-Month Average | Average daily volume over last ~22 trading days | `volume_1month_average` from database |
| `AvgVol_1Y` | 1-Year Average | Average daily volume over last ~252 trading days | `volume_1year_average` from database |
| `VolSortPct` | Volume Sort % | Calculated ranking/percentile metric | **Derived in backend** |

### VolSortPct Calculation

**Definition:** A ranking field used for sorting entities by volume activity.

**Clarification:** VolSortPct is not a separate calculated metric. It represents sorting based on the volume average columns (`volume_1week_average`, `volume_1month_average`, `volume_1year_average`). The backend should return a `volSortPct` field that enables sorting by volume intensity, computed as:

```
volSortPct = (latest_volume - volume_1year_average) / NULLIF(volume_1year_average, 0) * 100
```

OR as a percentile rank across all companies. The exact formula can be adjusted, but it must enable meaningful sorting from highest to lowest volume activity.

---

## 4. Hierarchy (Y-Axis)

Drill-down hierarchy from broad to specific:

| Level | Field | Example Values |
|---|---|---|
| 1 | Sector | "Technology", "Financials", "Healthcare" |
| 2 | Industry | "IT Services", "Banks", "Pharmaceuticals" |
| 3 | Industry Sub Group | "Large Cap IT", "Private Banks" (if available) |
| 4 | Company | "TCS", "INFY", "HDFCBANK" |

**Drill-Down Behavior:**
- Default view: Company level (most detailed)
- User can drill up to Industry, then Sector
- Each level aggregates child entities' volume metrics
- Drill-down indicator (chevron/down arrow) visible on Y-axis labels

**Note:** The screenshot shows company names on Y-axis (PPLPHARMACEUTICALS, etc.), indicating the default view is at Company level.

---

## 5. Legend

**Legend Title:** "Volume Metrics"

**Color Mapping:**
| Color | Measure | Description |
|---|---|---|
| Blue | Volume | Today's actual volume |
| Orange | AvgVol_1W | 1-week average |
| Purple | AvgVol_1M | 1-month average |
| Dark Blue/Purple | AvgVol_1Y | 1-year average |

**Legend Position:** Right side of chart (standard Power BI placement)

**Legend Behavior:**
- Clickable to show/hide individual metrics
- All 4 metrics visible by default

---

## 6. Calculations

### Normalization to 100%

Each bar is normalized so all segments sum to 100%.

**Formula:**
```
For each entity (company/industry/sector):
  Total = Volume + AvgVol_1W + AvgVol_1M + AvgVol_1Y
  
  Volume % = (Volume / Total) * 100
  AvgVol_1W % = (AvgVol_1W / Total) * 100
  AvgVol_1M % = (AvgVol_1M / Total) * 100
  AvgVol_1Y % = (AvgVol_1Y / Total) * 100
```

**Example:**
```
Company: RELIANCE
  Volume = 5,000,000
  AvgVol_1W = 4,500,000
  AvgVol_1M = 4,200,000
  AvgVol_1Y = 3,800,000
  
  Total = 17,500,000
  
  Volume % = (5,000,000 / 17,500,000) * 100 = 28.57%
  AvgVol_1W % = (4,500,000 / 17,500,000) * 100 = 25.71%
  AvgVol_1M % = (4,200,000 / 17,500,000) * 100 = 24.00%
  AvgVol_1Y % = (3,800,000 / 17,500,000) * 100 = 21.71%
  
  Sum = 28.57 + 25.71 + 24.00 + 21.71 = 100%
```

### VolSortPct Calculation

**Purpose:** Enable sorting by volume activity intensity.

**Likely Formula:**
```
VolSortPct = (Today's Volume - 1Y Average) / (1Y Average) * 100
```

OR

```
VolSortPct = Percentile rank of (Volume / AvgVol_1Y) across all companies
```

**Display:** Not shown in stacked bar; used for sorting/filtering.

---

## 7. Sorting

**Default Sort:** VolSortPct (descending) - highest volume activity first

**Alternative Sorts:**
- Company Name (A-Z)
- Sector
- Industry
- Today's Volume (absolute)
- Volume % (largest segment first)

**Sorting UI:** Dropdown in chart toolbar (reuse existing ChartToolbar)

---

## 8. Filters

The visual reacts to global application filters:

| Filter | Type | Example Values | Impact |
|---|---|---|---|
| **Date** | Date picker | "05 June 2026" | Changes "today's volume" |
| **Sector** | Multi-select dropdown | "Technology", "Financials" | Filters entities |
| **Industry** | Multi-select dropdown | "IT Services", "Banks" | Filters entities |
| **Market Cap** | Range/Segment | Large Cap, Mid Cap, Small Cap | Filters entities |
| **Rank** | Numeric/Text | "Top 50", "Top 100" | Limits entities shown |
| **Signal** | Multi-select | "Buy", "Sell", "Hold" | Filters by trading signal |
| **Watchlist** | Multi-select | "My Watchlist", "Favorites" | Filters entities |

**Implementation:**
- Filter state managed at application level
- Pass filtered entity list to volume profile endpoint
- Endpoint returns only matching entities

---

## 9. Interactions

### Hover Tooltip

**Trigger:** Mouse hover on any bar segment

**Tooltip Content:**
```
Company: PPLPHARMACEUTICALS
Sector: Pharmaceuticals
Industry: Pharma

Volume: 1,21,76,918 (12.18%)
AvgVol_1W: 1,09,82,384 (10.98%)
AvgVol_1M: 1,15,43,210 (11.54%)
AvgVol_1Y: 98,45,231 (9.85%)

Total Volume: 1,00,00,00,000
VolSortPct: 75.4

Company Count: 45 (in sector)
```

**Fields:**
- Hierarchy name (Company, Sector, Industry)
- Volume value
- Volume % (segment percentage)
- Actual volume (absolute number)
- Company count (if aggregated view)
- Return bucket (if available from backend)
- Additional metrics already in backend

### Drill-Down

**Interaction:** Click on sector/industry label to drill down

**Behavior:**
- Sector view → shows industries within sector
- Industry view → shows companies within industry
- Company view → shows individual company (default)
- Breadcrumb or "Drill Up" button to go back

### Sorting

**Interaction:** Click column headers or use toolbar dropdown

**Behavior:**
- Toggle ascending/descending
- Maintains 100% stacked normalization

### Selection

**Interaction:** Click on bar segment or entity row

**Behavior:**
- Highlights selected entity
- Cross-filters other visuals on page
- Maintains selection state

### Cross-Filtering

**Interaction:** Select entity in another visual (e.g., sector heatmap)

**Behavior:**
- Filters volume profile to selected entity
- Maintains drill level
- Clears selection on click outside

---

## 10. Backend Requirements

### Required Fields

For each entity (company, industry, or sector), the backend must return:

| Field | Type | Description | Source Column |
|---|---|---|---|
| `id` | string | Unique identifier | `nse_code` or composite |
| `name` | string | Entity name | `name` or `industry` or `sector` |
| `sector` | string | Sector name | `companies.industry` or `sector` column |
| `industry` | string | Industry name | `companies.industry` |
| `industrySubGroup` | string | Industry sub-group | `ISubgroup.Name_bse` (if available) |
| `volume` | number | Today's volume | `latest_volume` or `volume_1d` |
| `avgVol1W` | number | 1-week average volume | `volume_1week_average` |
| `avgVol1M` | number | 1-month average volume | `volume_1month_average` |
| `avgVol1Y` | number | 1-year average volume | `volume_1year_average` |
| `volSortPct` | number | Volume sort percentile | **Calculated** |
| `marketCap` | number | Market capitalization | `market_capitalization` |
| `companyCount` | number | Number of companies (if aggregated) | COUNT(*) |

### Request Parameters

```
GET /api/volume-profile

Query Parameters:
  level: "sector" | "industry" | "company" (default: "company")
  sector?: string (filter by sector)
  industry?: string (filter by industry)
  marketCap?: "large" | "mid" | "small"
  signal?: string[]
  watchlist?: string[]
  date?: string (YYYY-MM-DD)
  limit?: number (default: 50, max: 500)
  offset?: number (default: 0)
```

### Response Shape

```json
{
  "level": "company",
  "total": 5000,
  "rows": [
    {
      "id": "RELIANCE",
      "name": "Reliance Industries",
      "sector": "Energy",
      "industry": "Refineries & Marketing",
      "industrySubGroup": "Large Cap Refineries",
      "volume": 5000000,
      "avgVol1W": 4500000,
      "avgVol1M": 4200000,
      "avgVol1Y": 3800000,
      "volSortPct": 75.4,
      "marketCap": 1772018.67,
      "companyCount": null
    }
  ],
  "normalized": [
    {
      "id": "RELIANCE",
      "volumePct": 28.57,
      "avgVol1WPct": 25.71,
      "avgVol1MPct": 24.00,
      "avgVol1YPct": 21.71
    }
  ]
}
```

**Note:** Backend should compute both absolute values AND normalized percentages (summing to 100%).

---

## 11. PostgreSQL Mapping

### Primary Source Table

**`merged_price_baseline_probabilities_wide`**

**Rationale:**
- Contains all 4 volume metrics needed: `latest_volume`, `volume_1week_average`, `volume_1month_average`, `volume_1year_average`
- Contains `nse_code`, `name`, `industry` for hierarchy
- Contains `market_capitalization` for market cap filtering
- Already contains computed volume spike flags and comparisons

**Required Columns:**
- `nse_code` → `id`
- `name` → `name`
- `industry` → `industry`
- `latest_volume` → `volume`
- `volume_1week_average` → `avgVol1W`
- `volume_1month_average` → `avgVol1M`
- `volume_1year_average` → `avgVol1Y`
- `market_capitalization` → `marketCap`
- `company_code` → for joining with other tables if needed

### Secondary Source Table (for hierarchy)

**`companies`** or **`companies_powerbi`** (if sector/industry sub-group needed)

| Level | Source Column | Notes |
|---|---|---|
| Sector | `companies.industry` (mapped) or `companies_powerbi.Sector.Name_bse` | May need mapping |
| Industry | `companies.industry` | Direct mapping |
| Industry Sub Group | `companies_powerbi.ISubgroup.Name_bse` | Optional, if needed |
| Company | `nse_code` / `company_code` | Direct mapping |

### Missing Data

**Industry Sub Group:**
- NOT available in `merged_price_baseline_probabilities_wide`
- Available in `companies_powerbi` (`ISubgroup.Name_bse`)
- **Decision:** Skip sub-group level for initial implementation. Can be added later if required.

**VolSortPct:**
- NOT pre-computed in database
- Must be calculated in backend endpoint
- Formula: `(latest_volume - volume_1year_average) / NULLIF(volume_1year_average, 0) * 100`

---

## 12. Performance Requirements

**Data Volume:**
- 4,660 companies in `companies_with_price_features_with_corp_action_flags`
- Must support filtering to top N (e.g., top 50, 100, 500)

**Performance Targets:**
- Sector view: <100ms (aggregates ~60 rows)
- Industry view: <200ms (aggregates ~200 rows)
- Company view: <500ms (top 500 companies)

**Optimization Strategy:**
- **Database aggregation:** Use SQL `GROUP BY` + `CASE` statements for sector/industry views
- **Limit results:** Default to top 50 companies, allow pagination
- **Index usage:** Filter on `nse_code IS NOT NULL AND latest_volume IS NOT NULL`
- **Cache results:** Use React Query cache for 5 minutes (volume data doesn't change intraday)

**SQL Pattern (for reference during implementation):**
```sql
-- Company level
SELECT 
  nse_code,
  name,
  industry,
  latest_volume,
  volume_1week_average,
  volume_1month_average,
  volume_1year_average,
  (latest_volume - volume_1year_average) / NULLIF(volume_1year_average, 0) * 100 AS vol_sort_pct
FROM companies_with_price_features_with_corp_action_flags
WHERE nse_code IS NOT NULL
  AND latest_volume IS NOT NULL
ORDER BY vol_sort_pct DESC
LIMIT 500;

-- Industry level
SELECT 
  industry,
  SUM(latest_volume) AS volume,
  AVG(volume_1week_average) AS avg_vol_1w,
  AVG(volume_1month_average) AS avg_vol_1m,
  AVG(volume_1year_average) AS avg_vol_1y,
  COUNT(*) AS company_count
FROM companies_with_price_features_with_corp_action_flags
WHERE nse_code IS NOT NULL
  AND latest_volume IS NOT NULL
GROUP BY industry
ORDER BY volume DESC;
```

---

## 13. Component Architecture

### Reusable Components

**VolumeProfileChart** (new component)
```
src/shared/charts/volume-profile-chart.tsx
```

**Props:**
```typescript
{
  data: VolumeProfileRow[];
  level: 'sector' | 'industry' | 'company';
  height?: number;
  title?: string;
  state?: 'loading' | 'error' | 'empty' | 'ready';
  error?: string;
  onDrillDown?: (level: string, id: string) => void;
  onDrillUp?: () => void;
  exportName?: string;
}
```

**Internal Structure:**
- Wraps `ChartFrame` for loading/error/empty states
- Uses `recharts` `BarChart` with `layout="horizontal"`
- Computes normalized percentages from absolute values
- Renders 4 `Bar` components (one per volume metric)
- Integrates with `ChartToolbar` for sorting
- Supports drill-down via Y-axis click handlers

### Integration Points

**Page:**
```
src/app/(app)/markets/page.tsx
```

**Or dedicated page:**
```
src/app/(app)/volume-profile/page.tsx
```

**API Route:**
```
src/app/api/volume-profile/route.ts
```

**FastAPI Endpoint:**
```
GET /api/domain/volume-profile
```

**Repository:**
```
api_server/repositories/volume_profile_repository.py
```

---

## 14. Validation Criteria

### Visual Parity with Power BI

| Check | Pass Criteria |
|---|---|
| **Chart Type** | 100% stacked horizontal bar chart |
| **Bar Count** | Matches entity count (e.g., 50 companies) |
| **Normalization** | Each bar sums to exactly 100% |
| **Colors** | Blue, Orange, Purple, Dark Blue/Purple |
| **Legend** | Shows all 4 metrics with correct labels |
| **Sorting** | Default sort by VolSortPct descending |
| **Tooltip** | Shows all 4 metrics with values and percentages |
| **Drill-Down** | Sector → Industry → Company hierarchy works |
| **Filters** | Reacts to global filters (sector, market cap, etc.) |
| **Performance** | Loads 500 companies in <500ms |

### Data Validation

| Check | Pass Criteria |
|---|---|
| **Volume Values** | Match `latest_volume` from database |
| **Averages** | Match `volume_1week_average`, `volume_1month_average`, `volume_1year_average` |
| **Percentages** | Sum to 100% for each bar |
| **VolSortPct** | Correctly calculated and sorts logically |
| **Hierarchy** | Sector → Industry → Company drill-down works |
| **Filtering** | Filtering by sector/industry reduces rows correctly |

---

## 15. Implementation Order

**Phase 1: Backend (No Frontend Changes)**
1. Create `volume_profile_repository.py`
2. Add `/api/domain/volume-profile` endpoint
3. Test endpoint with Postman/curl
4. Verify aggregation logic

**Phase 2: API Layer (No UI Changes)**
1. Create `/api/volume-profile` Next.js route
2. Proxy to FastAPI
3. Test response shape
4. Verify filtering parameters

**Phase 3: Component (No Page Changes)**
1. Create `VolumeProfileChart` component
2. Use mock data to verify rendering
3. Test drill-down behavior
4. Test sorting

**Phase 4: Integration (Full Feature)**
1. Add to `/markets` page or create dedicated page
2. Wire to real API
3. Add global filters
4. Test against Power BI screenshot

---

## 16. Open Questions

1. **Industry Sub Group:** Should we skip this level, or join with `companies_powerbi` to get `ISubgroup.Name_bse`?
2. **VolSortPct Formula:** Is it `(Volume - 1Y Avg) / 1Y Avg` or percentile rank? Need to verify with Power BI DAX.
3. **Return Buckets:** The spec mentions return buckets (Very Negative → Very Positive). Are these part of this visual, or a separate visual?
4. **Date Filtering:** Does "today's volume" change based on date picker, or is it always the latest available?
5. **Missing Volume Data:** Some companies have `latest_volume = NULL`. Should they be excluded or shown as 0?

---

## 17. Out of Scope

**Do NOT implement:**
- Return bucket color coding (separate visual)
- Actual volume bars (only percentages in stacked bar)
- Predictive volume forecasting
- Volume-based alerts/notifications
- Real-time streaming updates

**Focus:** Exact functional parity with the Power BI screenshot.

---

## 18. References

- **Power BI File:** Access to .pbix file required to extract exact DAX measures
- **Screenshot:** "Volume Profiling - Averages" dated 05 June 2026
- **Database:** `companies_with_price_features_with_corp_action_flags` (main source)
- **Existing Views:** `vw_stock_snapshot`, `vw_trading_opportunities`

---

## 19. Success Criteria

✅ Visual matches Power BI screenshot in:
- Chart type (100% stacked horizontal bar)
- Measures (Volume, AvgVol_1W, AvgVol_1M, AvgVol_1Y)
- Colors (blue, orange, purple)
- Hierarchy (Sector → Industry → Company)
- Normalization (each bar sums to 100%)
- Tooltip content
- Sorting (by VolSortPct)

✅ Backend:
- Returns correct data for all 3 hierarchy levels
- Computes VolSortPct correctly
- Supports filtering by sector, industry, market cap
- Performs aggregation in PostgreSQL (not React)
- Response time <500ms for 500 companies

✅ Frontend:
- Reuses existing ChartFrame, ChartToolbar, theme
- Supports drill-down/up
- Supports sorting
- Responsive layout
- Accessible (keyboard navigation, ARIA labels)
