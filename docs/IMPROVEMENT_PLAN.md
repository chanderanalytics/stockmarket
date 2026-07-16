# Momentum Trading System Improvement Plan

**Project:** Momentum Trading Pipeline (s1-s4.2)  
**Date:** 2026-01-18  
**Scope:** Transform 23 fragmented scenarios into coherent, maintainable strategies  
**Status:** Ready for Implementation  

---

## Executive Summary

Current momentum pipeline has 23 scenarios with significant redundancy, unclear semantics, and fragile consolidation. This plan transforms it into 6-8 strategy families with proper state machines, adaptive thresholds, and robust validation.

**Key Issues Identified:**
- Scenarios are filter sets, not true strategies
- Trade logic uses legacy stage-based entry/exit
- Many scenarios are threshold variations of same core idea
- Missing dependency validation for rule variables
- Consolidation mixes reference dates dangerously
- No market regime awareness

**Expected Benefits:**
- 70% reduction in scenario count (23 → 6-8)
- Elimination of silent rule failures
- Clear strategy lifecycle (setup → trigger → management → exit)
- Adaptive behavior to market conditions
- Reproducible, date-specific consolidation

---

## Phase 1: Critical Infrastructure Fixes (Week 1)

### 1.1 Rule Variable Dependency Validator
**Priority:** Critical  
**Files:** `s3.3_rule_evaluator.R`, `s3_mmtm_runscenarios.R`  
**Effort:** 2 days

**Steps:**
1. Create `validate_rule_dependencies()` function in `s3.3_rule_evaluator.R`
2. Extract all variables from rule expressions using `all.vars(parse(text=rule_expr))`
3. Check each variable exists in prepared data column names
4. Validate variable types (numeric, logical, character)
5. Test rule evaluation on sample data to catch degenerate cases
6. Add validation call in `s3_mmtm_runscenarios.R` before scenario evaluation

**Acceptance Criteria:**
- All scenarios fail fast if any rule variable is missing
- Warning log shows which variables are missing
- No silent NA-only rule evaluations
- Validation runs in < 5 seconds for 23 scenarios

### 1.2 Fix Stage Assignment Logic
**Priority:** Critical  
**Files:** `s3_mmtm_runscenarios.R`  
**Effort:** 3 days

**Current Problem:** Stage assignment uses "highest stage wins" causing stage jumping

**Steps:**
1. Implement proper state machine per company:
   ```r
   # Only allow stage progression, not jumping
   dt[, stage := {
     prev_stage <- shift(stage, 1)
     if (is.na(prev_stage)) current_stage
     else if (current_stage > prev_stage) current_stage
     else prev_stage
   }, by = company_id]
   ```
2. Add stage persistence requirements:
   - Stage 3 (trigger) only valid if stage 1/2 occurred in last 10 days
   - Stage 4 (hold) only valid if stage 3 occurred in last 5 days
   - Stage 5 (warning) only valid if stage 4 occurred in last 3 days
3. Add stage cooldown periods to prevent rapid oscillation
4. Log stage transitions for debugging

**Acceptance Criteria:**
- No stage jumping backwards
- Clear progression path documented
- Stage history tracking for analysis
- Backward compatibility with existing trade logic

### 1.3 Fix Consolidation Reference Date Handling
**Priority:** Critical  
**Files:** `s4.2_consolidate_scenarios.R`  
**Effort:** 1 day

**Current Problem:** Mixes different reference dates in same output

**Steps:**
1. Add `--ref_date` parameter to `s4.2_consolidate_scenarios.R`
2. Only process files matching specified reference date
3. Fail with clear error if multiple dates found
4. Update `s1_mmtm.R` to pass reference date to consolidation
5. Create run-specific output directories: `output/mmtm/runs/<ref_date>/`

**Acceptance Criteria:**
- Each consolidation run processes only one reference date
- Clear error message for date mismatches
- Output files reference correct date in filename
- No data mixing across dates

---

## Phase 2: Strategy Consolidation (Week 2-3)

### 2.1 Define Strategy Families
**Priority:** High  
**Files:** `s3.2_rule_sets.R` (new version)  
**Effort:** 3 days

**Strategy Families to Create:**

#### A. CORE_MOMENTUM (merge momentum_1-4)
- **Setup:** Price above MA21 + volume confirmation
- **Trigger:** RSI 50-70 + momentum surge
- **Management:** Trailing stop with ATR multiplier
- **Exit:** RSI overbought or trend weakness

#### B. BREAKOUT_MASTERY (merge momentum_5,6,7,12)
- **Setup:** Range compression (NR4/NR7/tight_range)
- **Trigger:** Breakout with volume expansion
- **Management:** Volatility-adjusted position sizing
- **Exit:** Climax volume or failed breakout

#### C. PULLBACK_PROFIT (merge momentum_10,11)
- **Setup:** Pullback to MA21/50 with dry volume
- **Trigger:** Trend resumption with volume thrust
- **Management:** MA-based trailing stops
- **Exit:** Trend failure or target reached

#### D. INSTITUTIONAL_FLOW (merge momentum_19-21)
- **Setup:** Smart money accumulation patterns
- **Trigger:** VWAP reclaim + institutional support
- **Management:** Volume delta monitoring
- **Exit:** Distribution signals or smart money exit

#### E. PATTERN_RECOGNITION (keep momentum_8,9,13,14)
- **Setup:** 52w high proximity + gap patterns
- **Trigger:** Pattern completion confirmation
- **Management:** Pattern-specific stop levels
- **Exit:** Pattern failure or completion

#### F. VOLATILITY_EDGE (keep momentum_15,16)
- **Setup:** Low volatility compression
- **Trigger:** Volatility expansion breakout
- **Management:** ATR-based dynamic stops
- **Exit:** Volatility normalization

#### G. RISK_ADJUSTED (keep momentum_17,18)
- **Setup:** High Sharpe + trend strength
- **Trigger:** Risk-adjusted momentum signal
- **Management:** Risk score monitoring
- **Exit:** Risk deterioration

#### H. PMPS_PREMIUM (keep momentum_22)
- **Setup:** Pre-move probability buildup
- **Trigger:** PMPS score threshold breach
- **Management:** Pressure monitoring
- **Exit:** Pressure release or target

### 2.2 Parameterized Strategy Generator
**Priority:** High  
**Files:** `s3.2_rule_sets.R` (new functions)  
**Effort:** 4 days

**Steps:**
1. Create `generate_strategy_variants()` function
2. Define parameter grids for each strategy family:
   ```r
   breakout_params <- list(
     compression_window = c(4, 7),
     breakout_level = c("21d_high", "52w_high"),
     volume_multiplier = c(1.5, 1.8, 2.2),
     trend_filter = c("ma_stack", "adx", "risk_score")
   )
   ```
3. Generate all combinations programmatically
4. Create variant names: `BREAKOUT_MASTERY_NR4_21D_1.8X_MA`
5. Maintain backward compatibility with existing scenario names
6. Add parameter documentation for each variant

**Acceptance Criteria:**
- Generate 50+ variants from 8 base strategies
- Clear naming convention
- Parameter tracking for each variant
- Easy to add new parameters

---

## Phase 3: Adaptive Thresholds & Market Regime (Week 4)

### 3.1 Replace Static Thresholds with Adaptive Ones
**Priority:** High  
**Files:** `s2.2_calculate_indicators_module.R`, `s3.2_rule_sets.R`  
**Effort:** 3 days

**Static → Adaptive Mapping:**
- `rsi > 72` → `rsi > quantile(rsi, 0.8, na.rm=TRUE)`
- `volume > 1.7 * vol_ma_20` → `volume > quantile(volume, 0.8, na.rm=TRUE)`
- `atr_pct < 5` → `atr_pct < quantile(atr_pct, 0.3, na.rm=TRUE)`
- `return_5d > 0.03` → `return_5d > quantile(return_5d, 0.7, na.rm=TRUE)`

**Implementation Steps:**
1. Add rolling percentile calculations in `s2.2_calculate_indicators_module.R`
2. Create adaptive threshold functions:
   ```r
   adaptive_volume_threshold <- function(volume, lookback = 60, percentile = 0.8) {
     rollapply(volume, lookback, function(x) quantile(x, percentile, na.rm=TRUE), align="right")
   }
   ```
3. Update rule definitions to use adaptive thresholds
4. Add fallback to static thresholds for insufficient history
5. Document adaptive behavior for each threshold

### 3.2 Market Regime Classifier
**Priority:** High  
**Files:** `s2.2_calculate_indicators_module.R` (new section)  
**Effort:** 3 days

**Regime Dimensions:**
1. **Trend Regime:** Index above/below MA200, MA slope
2. **Volatility Regime:** VIX-like proxy, ATR percentiles
3. **Breadth Regime:** % stocks above MA50, advance/decline ratio
4. **Risk Regime:** Risk score distribution, correlation levels

**Implementation:**
```r
calculate_market_regime <- function(dt) {
  # Use NIFTY or equal-weight index as proxy
  dt[, index_trend := {
    index_ma200 <- frollmean(index_close, 200)
    fifelse(index_close > index_ma200, "BULL", "BEAR")
  }]
  
  dt[, volatility_regime := {
    index_vol <- frollapply(index_return, 20, sd) * sqrt(252)
    fifelse(index_vol > quantile(index_vol, 0.7), "HIGH", 
           fifelse(index_vol < quantile(index_vol, 0.3), "LOW", "NORMAL"))
  }]
  
  dt[, regime := paste(index_trend, volatility_regime, sep="_")]
}
```

### 3.3 Regime-Aware Strategy Selection
**Priority:** Medium  
**Files:** `s3_mmtm_runscenarios.R`  
**Effort:** 2 days

**Strategy-Regime Mapping:**
- BREAKOUT strategies: BULL_NORMAL, BULL_HIGH
- PULLBACK strategies: BULL_NORMAL (dips in bull market)
- VOLATILITY_EDGE: HIGH volatility regimes
- RISK_ADJUSTED: All regimes with position sizing adjustment
- PMPS_PREMIUM: Transition regimes (BULL_NORMAL → BEAR_HIGH)

---

## Phase 4: Trade Logic Enhancement (Week 5)

### 4.1 Separate Signal Types
**Priority:** High  
**Files:** `s3_mmtm_runscenarios.R`, `s4_mmtm_clean_trade_tracker_fixed.R`  
**Effort:** 4 days

**Signal Types to Implement:**
1. `universe_filter` - Basic eligibility (liquidity, risk_score)
2. `setup_filter` - Pattern recognition (compression, pullback)
3. `trigger_signal` - Entry confirmation (breakout, volume thrust)
4. `management_signal` - In-trade adjustments (stops, targets)
5. `exit_signal` - Trade termination (distribution, failure)

**Implementation:**
```r
# Replace stage-based with signal-based
dt[, entry_signal := (universe_filter == 1) & (setup_filter == 1) & (trigger_signal == 1)]
dt[, exit_signal := (exit_condition == 1)]
dt[, hold_signal := (entry_signal == 1) & (exit_signal == 0)]
```

### 4.2 Fix Entry/Exit Logic
**Priority:** Critical  
**Files:** `s4_mmtm_clean_trade_tracker_fixed.R`  
**Effort:** 3 days

**Current Issues:**
- Entry on any stage change
- No explicit trigger requirement
- Mixed exit conditions

**New Logic:**
1. **Entry only on trigger_signal == 1**
2. **Position management while hold_signal == 1**
3. **Exit when exit_signal == 1**
4. **Force exit after maximum holding period**
5. **Partial exits on target achievement**

---

## Phase 5: Advanced Features (Week 6-7)

### 5.1 Backtesting Framework
**Priority:** Medium  
**Files:** New: `s5_backtest_framework.R`  
**Effort:** 5 days

**Components:**
1. Walk-forward optimization
2. Cross-validation by time periods
3. Performance attribution by regime
4. Strategy comparison metrics
5. Overfitting detection

### 5.2 Performance Dashboard
**Priority:** Low  
**Files:** New: `dashboard/strategy_performance.R`  
**Effort:** 3 days

**Features:**
1. Real-time strategy performance
2. Regime-specific performance
3. Correlation matrix between strategies
4. Risk metrics (drawdown, VaR, Sharpe)
5. Interactive parameter tuning

### 5.3 Machine Learning Enhancement
**Priority:** Low  
**Files:** New: `ml_strategy_optimizer.R`  
**Effort:** 7 days

**Capabilities:**
1. Automatic parameter optimization
2. Feature importance for rule selection
3. Ensemble strategy generation
4. Adaptive regime detection

---

## Implementation Timeline

| Week | Phase | Key Deliverables | Risk Level |
|-------|--------|------------------|-------------|
| 1 | Critical Infrastructure | Rule validator, stage logic fix, consolidation fix | Low |
| 2-3 | Strategy Consolidation | 8 strategy families, parameter generator | Medium |
| 4 | Adaptive Thresholds | Market regime, adaptive rules | Medium |
| 5 | Trade Logic Enhancement | Signal-based entry/exit | Low |
| 6-7 | Advanced Features | Backtesting, dashboard, ML | High |

**Total Estimated Effort:** 6-7 weeks  
**Team Size:** 1-2 developers  
**Critical Path:** Phase 1 → Phase 2 → Phase 4

---

## Success Metrics

### Technical Metrics
- **Scenario Count:** 23 → 8 base strategies + 50+ variants
- **Rule Validation:** 100% coverage before execution
- **Stage Consistency:** 0 backward stage jumps
- **Consolidation Accuracy:** 0 date mixing incidents

### Performance Metrics
- **Backtest Sharpe Ratio:** > 1.0 for consolidated strategies
- **Max Drawdown:** < 25% during backtest period
- **Win Rate:** > 55% for trigger-based entries
- **Strategy Correlation:** < 0.6 between base strategies

### Operational Metrics
- **Runtime:** < 30 minutes for full pipeline (23 scenarios was ~45 min)
- **Memory Usage:** < 8GB peak (current ~12GB)
- **Error Rate:** < 1% failed scenario evaluations
- **Reproducibility:** 100% deterministic results for same inputs

---

## Risk Mitigation

### Technical Risks
1. **Backward Compatibility:** Keep legacy scenario names as aliases
2. **Data Quality:** Enhanced validation prevents silent failures
3. **Performance:** Parameter generation can be limited if runtime explodes
4. **Complexity:** Clear documentation and modular design

### Business Risks
1. **Strategy Performance:** Maintain existing strategies during transition
2. **Regime Changes:** Adaptive thresholds should auto-adjust
3. **Overfitting:** Cross-validation and walk-forward testing
4. **Operational:** Gradual rollout with monitoring

---

## Next Steps

1. **Immediate (This Week):**
   - Implement rule dependency validator
   - Fix consolidation reference date handling
   - Begin stage logic redesign

2. **Short Term (Next 2 Weeks):**
   - Define 8 strategy families
   - Create parameter generator
   - Test with historical data

3. **Medium Term (Next Month):**
   - Implement adaptive thresholds
   - Add market regime classifier
   - Deploy new trade logic

4. **Long Term (Next 2 Months):**
   - Build backtesting framework
   - Create performance dashboard
   - Consider ML enhancements

---

## Appendix: Code Examples

### Rule Validator Skeleton
```r
validate_rule_dependencies <- function(rule_sets, available_columns) {
  validation_results <- list()
  
  for (scenario_name in names(rule_sets)) {
    scenario <- rule_sets[[scenario_name]]
    missing_vars <- c()
    
    for (stage in scenario) {
      for (rule in stage$rules) {
        rule_vars <- all.vars(parse(text = rule))
        missing_vars <- c(missing_vars, setdiff(rule_vars, available_columns))
      }
    }
    
    validation_results[[scenario_name]] <- list(
      missing_vars = unique(missing_vars),
      is_valid = length(missing_vars) == 0
    )
  }
  
  return(validation_results)
}
```

### Parameter Generator Skeleton
```r
generate_strategy_variants <- function(base_strategy, params) {
  # Create all combinations
  param_grid <- expand.grid(params)
  variants <- list()
  
  for (i in 1:nrow(param_grid)) {
    variant_name <- paste0(base_strategy, "_", 
                         paste(names(param_grid[i,]), param_grid[i,], collapse="_"))
    variants[[variant_name]] <- generate_variant_rules(base_strategy, param_grid[i, ])
  }
  
  return(variants)
}
```

### Adaptive Threshold Example
```r
# Old: volume > 1.7 * vol_ma_20
# New: volume > adaptive_volume_threshold(volume, 60, 0.8)

adaptive_volume_threshold <- function(volume, lookback, percentile) {
  rollapply(volume, lookback, function(x) {
    if (all(is.na(x))) return(NA)
    quantile(x, percentile, na.rm = TRUE)
  }, align = "right", fill = NA)
}
```

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-18  
**Next Review:** 2026-01-25
