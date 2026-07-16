"""
Financial Statement Mapper
Maps raw XBRL facts to standardized income statements, balance sheets, and cash flow statements.
Handles both NSE and BSE XBRL formats and extracts consolidated/standalone statements.
"""

import logging
import pandas as pd
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime

logger = logging.getLogger(__name__)

STATEMENTS_OUTPUT_DIR = Path("xbrl_pipeline/financial_statements")
STATEMENTS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

STABLE_CORE_CONCEPTS_PATH = Path("xbrl_pipeline/stable_core_concepts_sample10.csv")


def _load_stable_core_concepts() -> set[str]:
    if not STABLE_CORE_CONCEPTS_PATH.exists():
        return set()

    try:
        stable_core_df = pd.read_csv(STABLE_CORE_CONCEPTS_PATH)
    except Exception:
        return set()

    if "concept" not in stable_core_df.columns:
        return set()

    return {str(value).strip() for value in stable_core_df["concept"].dropna() if str(value).strip()}


STABLE_CORE_CONCEPTS = _load_stable_core_concepts()

# XBRL tag mappings for Indian companies.
# These are intentionally restricted to the stable core concepts observed in the
# expanded sample so the mapper stays focused on repeatable line items.
INCOME_STATEMENT_MAPPING = {
    'revenue_from_operations': ['RevenueFromOperations'],
    'other_income': ['OtherIncome'],
    'total_income': ['Income'],
    'cost_of_materials': ['CostOfMaterialsConsumed', 'PurchasesOfStockInTrade', 'ChangesInInventoriesOfFinishedGoodsWorkInProgressAndStockInTrade'],
    'employee_costs': ['EmployeeBenefitExpense'],
    'depreciation': ['DepreciationDepletionAndAmortisationExpense'],
    'other_expenses': ['OtherExpenses'],
    'operating_profit': ['ProfitBeforeExceptionalItemsAndTax'],
    'finance_costs': ['FinanceCosts'],
    'profit_before_tax': ['ProfitBeforeTax'],
    'tax_expense': ['TaxExpense', 'CurrentTax', 'DeferredTax'],
    'net_profit': ['ProfitLossForPeriod', 'ProfitLossForPeriodFromContinuingOperations', 'ProfitLossFromDiscontinuedOperationsAfterTax'],
    'eps_basic': ['BasicEarningsLossPerShareFromContinuingAndDiscontinuedOperations', 'BasicEarningsLossPerShareFromContinuingOperations'],
    'eps_diluted': ['DilutedEarningsLossPerShareFromContinuingAndDiscontinuedOperations', 'DilutedEarningsLossPerShareFromContinuingOperations'],
    'comprehensive_income': ['ComprehensiveIncomeForThePeriod', 'ComprehensiveIncomeForThePeriodAttributableToOwnersOfParent'],
    'comprehensive_income_attributable_to_parent': ['ComprehensiveIncomeForThePeriodAttributableToOwnersOfParent'],
    'comprehensive_income_nci': ['ComprehensiveIncomeForThePeriodAttributableToOwnersOfParentNonControllingInterests'],
    'share_of_profit_associates': ['ShareOfProfitLossOfAssociatesAndJointVenturesAccountedForUsingEquityMethod'],
    'exceptional_items': ['ExceptionalItemsBeforeTax'],
    'expenses': ['Expenses'],
    'profit_from_continuing_operations': ['ProfitLossForPeriodFromContinuingOperations'],
    'profit_from_discontinued_operations_before_tax': ['ProfitLossFromDiscontinuedOperationsBeforeTax'],
    'profit_from_discontinued_operations_after_tax': ['ProfitLossFromDiscontinuedOperationsAfterTax'],
}

# Fields that should NOT be converted to crores (per-share, ratios, percentages)
NO_CONVERSION_FIELDS = {'eps_basic', 'eps_diluted'}

BALANCE_SHEET_MAPPING = {
    'equity_capital': ['PaidUpValueOfEquityShareCapital', 'FaceValueOfEquityShareCapital', 'EquityShareCapital'],
    'reserves': ['OtherComprehensiveIncomeNetOfTaxes', 'OtherEquity', 'ReserveExcludingRevaluationReserves'],
    'other_comprehensive_income': ['OtherComprehensiveIncomeNetOfTaxes'],
    'net_movement_regulatory_deferral': ['NetMovementInRegulatoryDeferralAccountBalancesRelatedToProfitOrLossAndTheRelatedDeferredTaxMovement'],
    'total_assets': ['Assets'],
    'total_liabilities': ['Liabilities'],
    'total_equity': ['Equity', 'EquityAndLiabilities'],
    'equity_attributable_to_parent': ['EquityAttributableToOwnersOfParent'],
    'non_controlling_interests': ['NonControllingInterest'],
    'property_plant_equipment': ['PropertyPlantAndEquipment'],
    'capital_work_in_progress': ['CapitalWorkInProgress'],
    'goodwill': ['Goodwill'],
    'intangible_assets': ['OtherIntangibleAssets', 'IntangibleAssetsUnderDevelopment'],
    'inventories': ['Inventories'],
    'investments': ['Investments', 'InvestmentsAccountedForUsingEquityMethod', 'CurrentInvestments', 'NoncurrentInvestments', 'InvestmentProperty'],
    'borrowings_current': ['BorrowingsCurrent'],
    'borrowings_noncurrent': ['BorrowingsNoncurrent'],
    'total_borrowings': ['Borrowings'],
    'current_assets': ['CurrentAssets'],
    'noncurrent_assets': ['NoncurrentAssets'],
    'current_liabilities': ['CurrentLiabilities'],
    'noncurrent_liabilities': ['NoncurrentLiabilities'],
    'trade_receivables_current': ['TradeReceivablesCurrent'],
    'trade_receivables_noncurrent': ['TradeReceivablesNoncurrent'],
    'trade_payables_current': ['TradePayablesCurrent'],
    'trade_payables_noncurrent': ['TradePayablesNoncurrent'],
    'cash_and_equivalents': ['CashAndCashEquivalents', 'BankBalanceOtherThanCashAndCashEquivalents'],
    'deferred_tax_assets': ['DeferredTaxAssetsNet'],
    'deferred_tax_liabilities': ['DeferredTaxLiabilitiesNet'],
    'provisions_current': ['ProvisionsCurrent'],
    'provisions_noncurrent': ['ProvisionsNoncurrent'],
}

CASH_FLOW_MAPPING = {
    'operating_activities': ['CashFlowsFromUsedInOperatingActivities', 'CashFlowsFromUsedInOperations'],
    'investing_activities': ['CashFlowsFromUsedInInvestingActivities'],
    'financing_activities': ['CashFlowsFromUsedInFinancingActivities'],
    'net_cash_flow': ['IncreaseDecreaseInCashAndCashEquivalents', 'IncreaseDecreaseInCashAndCashEquivalentsBeforeEffectOfExchangeRateChanges'],
    'cash_opening': ['CashAndCashEquivalentsCashFlowStatement'],
    'cash_closing': ['CashAndCashEquivalentsCashFlowStatement'],
    'purchase_of_ppe': ['PurchaseOfPropertyPlantAndEquipment'],
    'purchase_of_intangible_assets': ['PurchaseOfIntangibleAssets', 'PurchaseOfIntangibleAssetsUnderDevelopment'],
    'purchase_of_investments': ['OtherCashPaymentsToAcquireEquityOrDebtInstrumentsOfOtherEntitiesClassifiedAsInvestingActivities', 'OtherCashPaymentsToAcquireInterestsInJointVenturesClassifiedAsInvestingActivities'],
    'proceeds_from_sale_of_ppe': ['ProceedsFromSalesOfPropertyPlantAndEquipmentClassifiedAsInvestingActivities'],
    'proceeds_from_sale_of_investments': ['OtherCashReceiptsFromSalesOfEquityOrDebtInstrumentsOfOtherEntitiesClassifiedAsInvestingActivities', 'OtherCashReceiptsFromSalesOfInterestsInJointVenturesClassifiedAsInvestingActivities'],
    'proceeds_from_borrowings': ['ProceedsFromBorrowingsClassifiedAsFinancingActivities'],
    'repayment_of_borrowings': ['RepaymentsOfBorrowingsClassifiedAsFinancingActivities'],
    'dividends_paid': ['DividendsPaidClassifiedAsFinancingActivities'],
    'dividends_received': ['DividendsReceivedClassifiedAsInvestingActivities', 'DividendsReceivedClassifiedAsOperatingActivities'],
    'interest_paid': ['InterestPaidClassifiedAsFinancingActivities', 'InterestPaidClassifiedAsOperatingActivities'],
    'interest_received': ['InterestReceivedClassifiedAsInvestingActivities', 'InterestReceivedClassifiedAsOperatingActivities'],
    'tax_paid': ['IncomeTaxesPaidRefundClassifiedAsOperatingActivities', 'IncomeTaxesPaidRefundClassifiedAsFinancingActivities', 'IncomeTaxesPaidRefundClassifiedAsInvestingActivities'],
    'effect_of_exchange_rate_changes': ['EffectOfExchangeRateChangesOnCashAndCashEquivalents'],
}


class FinancialStatementMapper:
    """Maps raw XBRL facts to standardized financial statements."""
    
    def __init__(self):
        self.stable_core_concepts = STABLE_CORE_CONCEPTS
        self.income_mapping = INCOME_STATEMENT_MAPPING
        self.balance_mapping = BALANCE_SHEET_MAPPING
        self.cash_flow_mapping = CASH_FLOW_MAPPING

    def _is_stable_core_concept(self, tag_name: str) -> bool:
        concept_name = str(tag_name).split(":")[-1].strip()
        return not self.stable_core_concepts or concept_name in self.stable_core_concepts
    
    def _extract_value_from_facts(self, facts_df: pd.DataFrame, 
                                  tag_names: List[str],
                                  context_filter: Optional[str] = None,
                                  line_item: Optional[str] = None) -> Optional[float]:
        """Extract a numeric value from facts matching tag names."""
        if facts_df.empty:
            return None

        tag_names = [tag_name for tag_name in tag_names if self._is_stable_core_concept(tag_name)]
        if not tag_names:
            return None
        
        # Filter by tag
        normalized_tags = facts_df['tag'].astype(str).str.split(":").str[-1]
        mask = normalized_tags.isin([str(tag_name).split(":")[-1] for tag_name in tag_names])
        if context_filter:
            mask = mask & (facts_df['context'].str.contains(context_filter, na=False))
        
        matching_facts = facts_df[mask]
        
        if matching_facts.empty:
            return None
        
        # Take the most recent/relevant fact
        # Priority: pick last row (most recently filed context)
        last_fact = matching_facts.iloc[-1]
        
        try:
            value = float(last_fact['value']) if pd.notna(last_fact['value']) else None
            
            # Convert to Crores only if:
            # 1. Value is not None
            # 2. Line item is not a per-share/ratio field
            # 3. Unit indicates millions (mn) or the value is large enough to suggest millions
            if value is not None and line_item not in NO_CONVERSION_FIELDS:
                # Check unit information if available
                unit_measure = last_fact.get('unit_measure', '')
                unit_id = last_fact.get('unit', '')
                
                # Convert if unit indicates millions or if value is very large (suggesting raw INR)
                # Common XBRL units for Indian companies: INR, INR millions, INR thousands
                should_convert = False
                
                if unit_measure:
                    unit_lower = str(unit_measure).lower()
                    if 'million' in unit_lower or 'mn' in unit_lower or 'mio' in unit_lower:
                        should_convert = True
                elif unit_id:
                    # Some XBRL uses unit IDs like 'INR', 'INR-millions', etc.
                    unit_id_lower = str(unit_id).lower()
                    if 'million' in unit_id_lower or 'mn' in unit_id_lower:
                        should_convert = True
                
                # If unit info is unclear, use heuristic: if value > 1 million, assume it's in INR
                if not should_convert and abs(value) > 1_000_000:
                    should_convert = True
                
                if should_convert:
                    value = value / 10_000_000  # Convert to Crores
            
            return value
        except (ValueError, TypeError):
            return None
    
    def map_income_statement(self, facts_df: pd.DataFrame, 
                            period_end_date: str) -> Dict:
        """Map facts to income statement line items."""
        income_stmt = {
            'period_end_date': period_end_date,
            'statement_type': 'income_statement',
        }
        
        for line_item, tag_names in self.income_mapping.items():
            value = self._extract_value_from_facts(facts_df, tag_names, line_item=line_item)
            income_stmt[line_item] = value
        
        return income_stmt
    
    def map_balance_sheet(self, facts_df: pd.DataFrame, 
                         period_end_date: str) -> Dict:
        """Map facts to balance sheet line items."""
        balance_sheet = {
            'period_end_date': period_end_date,
            'statement_type': 'balance_sheet',
        }
        
        for line_item, tag_names in self.balance_mapping.items():
            value = self._extract_value_from_facts(facts_df, tag_names)
            balance_sheet[line_item] = value
        
        return balance_sheet
    
    def map_cash_flow(self, facts_df: pd.DataFrame, 
                     period_end_date: str) -> Dict:
        """Map facts to cash flow statement line items."""
        cash_flow = {
            'period_end_date': period_end_date,
            'statement_type': 'cash_flow',
        }
        
        for line_item, tag_names in self.cash_flow_mapping.items():
            value = self._extract_value_from_facts(facts_df, tag_names)
            cash_flow[line_item] = value
        
        return cash_flow
    
    def process_facts_file(self, facts_csv: str, bse_code: str, 
                          exchange: str, period: str,
                          filing_type: Optional[str] = None,
                          audited_status: Optional[str] = None) -> Tuple[List[Dict], List[Dict], List[Dict]]:
        """Process a raw facts CSV and extract all three statements."""
        try:
            facts_df = pd.read_csv(facts_csv)
            
            if facts_df.empty:
                logger.warning(f"Empty facts file: {facts_csv}")
                return [], [], []
            
            # Determine period end date from context
            end_dates = facts_df['end_date'].dropna().unique()
            if len(end_dates) > 0:
                period_end_date = str(end_dates[0])
            else:
                period_end_date = period

            # Build a context -> report variant map from the filing itself.
            # BSE/NSE facts commonly repeat the report nature fact per context.
            variant_fact_rows = facts_df[
                facts_df['concept'].astype(str).eq('NatureOfReportStandaloneConsolidated')
            ][['context', 'value']].dropna(subset=['context', 'value'])
            context_variant_map = {}
            for _, row in variant_fact_rows.iterrows():
                context_id = str(row['context']).strip()
                variant_value = str(row['value']).strip().lower()
                if variant_value.startswith('consolidated'):
                    context_variant_map[context_id] = 'consolidated'
                elif variant_value.startswith('standalone'):
                    context_variant_map[context_id] = 'standalone'
            
            # Map to statements
            income_stmts = []
            balance_stmts = []
            cash_flow_stmts = []
            
            # Extract statements for consolidated and standalone (if both present)
            for variant in ['consolidated', 'standalone']:
                # Filter facts by context -> variant mapping if available.
                # If no mapping exists for a context, keep it only when its facts
                # are explicitly tagged with the variant in the report nature fact.
                variant_contexts = [ctx for ctx, ctx_variant in context_variant_map.items() if ctx_variant == variant]
                if variant_contexts:
                    variant_facts = facts_df[facts_df['context'].astype(str).isin(variant_contexts)].copy()
                else:
                    variant_facts = facts_df.iloc[0:0].copy()
                
                if variant_facts.empty:
                    continue
                
                # Map to each statement type
                income_dict = self.map_income_statement(variant_facts, period_end_date)
                income_dict.update({
                    'bse_code': bse_code,
                    'exchange': exchange,
                    'period': period,
                    'filing_type': filing_type,
                    'variant': variant,
                    'audited_status': audited_status or 'unknown',
                })
                income_stmts.append(income_dict)
                
                balance_dict = self.map_balance_sheet(variant_facts, period_end_date)
                balance_dict.update({
                    'bse_code': bse_code,
                    'exchange': exchange,
                    'period': period,
                    'filing_type': filing_type,
                    'variant': variant,
                    'audited_status': audited_status or 'unknown',
                })
                balance_stmts.append(balance_dict)
                
                cash_flow_dict = self.map_cash_flow(variant_facts, period_end_date)
                cash_flow_dict.update({
                    'bse_code': bse_code,
                    'exchange': exchange,
                    'period': period,
                    'filing_type': filing_type,
                    'variant': variant,
                    'audited_status': audited_status or 'unknown',
                })
                cash_flow_stmts.append(cash_flow_dict)
            
            return income_stmts, balance_stmts, cash_flow_stmts
            
        except Exception as e:
            logger.error(f"Error processing facts file {facts_csv}: {e}")
            return [], [], []
    
    def save_statements(self, company_code: str, exchange: str,
                       income_stmts: List[Dict],
                       balance_stmts: List[Dict],
                       cash_flow_stmts: List[Dict]) -> Tuple[str, str, str]:
        """Save mapped statements to variant-specific CSV files (consolidated/standalone)."""
        output_paths = {}

        def _write_variant_csv(rows: List[Dict], file_path: Path, columns: List[str]) -> str:
            file_path.parent.mkdir(parents=True, exist_ok=True)

            if rows:
                new_df = pd.DataFrame(rows)
                for column in columns:
                    if column not in new_df.columns:
                        new_df[column] = None

                if file_path.exists():
                    try:
                        old_df = pd.read_csv(file_path)
                        merged = pd.concat([old_df, new_df], ignore_index=True)
                    except Exception:
                        merged = new_df
                else:
                    merged = new_df

                dedupe_keys = [k for k in ["bse_code", "exchange", "period", "filing_type", "variant", "statement_type", "audited_status"] if k in merged.columns]
                if dedupe_keys:
                    merged = merged.drop_duplicates(subset=dedupe_keys, keep="last")
            else:
                if file_path.exists():
                    try:
                        merged = pd.read_csv(file_path)
                    except Exception:
                        merged = pd.DataFrame(columns=columns)
                else:
                    merged = pd.DataFrame(columns=columns)

            merged.to_csv(file_path, index=False)
            return str(file_path)
        
        output_dir = STATEMENTS_OUTPUT_DIR / exchange / company_code
        output_dir.mkdir(parents=True, exist_ok=True)
        
        variant_list = ["consolidated", "standalone"]

        income_files = []
        balance_files = []
        cash_flow_files = []

        income_columns = ["period_end_date", "statement_type", "bse_code", "exchange", "period", "filing_type", "variant", "audited_status"] + list(self.income_mapping.keys())
        balance_columns = ["period_end_date", "statement_type", "bse_code", "exchange", "period", "filing_type", "variant", "audited_status"] + list(self.balance_mapping.keys())
        cash_flow_columns = ["period_end_date", "statement_type", "bse_code", "exchange", "period", "filing_type", "variant", "audited_status"] + list(self.cash_flow_mapping.keys())

        filing_types = ["annual", "quarterly"]

        # Get unique audited statuses present in the data
        unique_audited_statuses = set()
        for stmt in income_stmts + balance_stmts + cash_flow_stmts:
            unique_audited_statuses.add((stmt.get("audited_status") or "unknown").lower())
        unique_audited_statuses = sorted(unique_audited_statuses)

        for variant in variant_list:
            for filing_type in filing_types:
                for audited_status in unique_audited_statuses:
                    v_income = [
                        r for r in income_stmts
                        if r.get("variant") == variant 
                        and (r.get("filing_type") or "").lower() == filing_type
                        and (r.get("audited_status") or "unknown").lower() == audited_status
                    ]
                    v_balance = [
                        r for r in balance_stmts
                        if r.get("variant") == variant 
                        and (r.get("filing_type") or "").lower() == filing_type
                        and (r.get("audited_status") or "unknown").lower() == audited_status
                    ]
                    v_cash = [
                        r for r in cash_flow_stmts
                        if r.get("variant") == variant 
                        and (r.get("filing_type") or "").lower() == filing_type
                        and (r.get("audited_status") or "unknown").lower() == audited_status
                    ]

                    # Only create files if there's data
                    if v_income or v_balance or v_cash:
                        income_file = _write_variant_csv(
                            v_income,
                            output_dir / f"income_statement_{variant}_{filing_type}_{audited_status}.csv",
                            income_columns,
                        )
                        balance_file = _write_variant_csv(
                            v_balance,
                            output_dir / f"balance_sheet_{variant}_{filing_type}_{audited_status}.csv",
                            balance_columns,
                        )
                        cash_file = _write_variant_csv(
                            v_cash,
                            output_dir / f"cash_flow_{variant}_{filing_type}_{audited_status}.csv",
                            cash_flow_columns,
                        )

                        income_files.append(income_file)
                        balance_files.append(balance_file)
                        cash_flow_files.append(cash_file)

                        logger.info(f"Saved income statement ({variant}, {filing_type}, {audited_status}): {income_file}")
                        logger.info(f"Saved balance sheet ({variant}, {filing_type}, {audited_status}): {balance_file}")
                        logger.info(f"Saved cash flow statement ({variant}, {filing_type}, {audited_status}): {cash_file}")

        output_paths['income'] = ";".join(income_files) if income_files else None
        output_paths['balance'] = ";".join(balance_files) if balance_files else None
        output_paths['cash_flow'] = ";".join(cash_flow_files) if cash_flow_files else None
        
        return tuple(output_paths.get(k) for k in ['income', 'balance', 'cash_flow'])


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    mapper = FinancialStatementMapper()
    logger.info("Financial Statement Mapper initialized")
