"""
Financial Statement Builder
Builds standardized financial statements from raw XBRL facts using a data-driven concept catalog.
"""

import logging
import pandas as pd
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime

logger = logging.getLogger(__name__)

STATEMENTS_OUTPUT_DIR = Path("xbrl_pipeline/financial_statements")
STATEMENTS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

CONCEPT_CATALOG_PATH = Path("xbrl_pipeline/concept_catalog.csv")
STABLE_CORE_CONCEPTS_PATH = Path("xbrl_pipeline/stable_core_concepts_sample10.csv")


def _load_concept_catalog() -> pd.DataFrame:
    """Load concept catalog from CSV."""
    if not CONCEPT_CATALOG_PATH.exists():
        logger.warning(f"Concept catalog not found at {CONCEPT_CATALOG_PATH}")
        return pd.DataFrame(columns=['concept', 'statement', 'line_item', 'display_order', 'priority'])
    
    try:
        catalog_df = pd.read_csv(CONCEPT_CATALOG_PATH)
        required_columns = ['concept', 'statement', 'line_item', 'display_order', 'priority']
        if not all(col in catalog_df.columns for col in required_columns):
            logger.error(f"Concept catalog missing required columns: {required_columns}")
            return pd.DataFrame(columns=required_columns)
        
        # Sort by display_order
        catalog_df = catalog_df.sort_values('display_order')
        return catalog_df
    except Exception as e:
        logger.error(f"Error loading concept catalog: {e}")
        return pd.DataFrame(columns=['concept', 'statement', 'line_item', 'display_order', 'priority'])


def _load_stable_core_concepts() -> set[str]:
    """Load stable core concepts for filtering."""
    if not STABLE_CORE_CONCEPTS_PATH.exists():
        return set()

    try:
        stable_core_df = pd.read_csv(STABLE_CORE_CONCEPTS_PATH)
    except Exception:
        return set()

    if "concept" not in stable_core_df.columns:
        return set()

    return {str(value).strip() for value in stable_core_df["concept"].dropna() if str(value).strip()}


CONCEPT_CATALOG = _load_concept_catalog()
STABLE_CORE_CONCEPTS = _load_stable_core_concepts()

# Fields that should NOT be converted to crores (per-share, ratios, percentages)
NO_CONVERSION_FIELDS = {'eps'}


class FinancialStatementBuilder:
    """Builds financial statements from XBRL facts using concept catalog."""
    
    def __init__(self):
        self.concept_catalog = CONCEPT_CATALOG
        self.stable_core_concepts = STABLE_CORE_CONCEPTS
        
        if self.concept_catalog.empty:
            logger.warning("Concept catalog is empty - statement builder will not function correctly")
    
    def _is_stable_core_concept(self, tag_name: str) -> bool:
        """Check if a concept is in the stable core set."""
        concept_name = str(tag_name).split(":")[-1].strip()
        return not self.stable_core_concepts or concept_name in self.stable_core_concepts
    
    def _score_context(self, fact: pd.Series) -> int:
        """
        Score context for priority selection.
        Higher score = more preferred context.
        
        Priority order:
        1. CurrentYearDuration (score: 100)
        2. CurrentQuarterDuration (score: 80)
        3. PreviousYearDuration (score: 60)
        4. Other contexts (score: 0)
        """
        context_str = str(fact.get('context', '')).lower()
        
        if 'currentyearduration' in context_str or 'currentyear' in context_str:
            return 100
        elif 'currentquarterduration' in context_str or 'currentquarter' in context_str:
            return 80
        elif 'previousyearduration' in context_str or 'previousyear' in context_str:
            return 60
        else:
            return 0
    
    def _extract_value_from_facts(self, facts_df: pd.DataFrame, 
                                  concept_name: str,
                                  line_item: Optional[str] = None) -> Optional[float]:
        """
        Extract a numeric value from facts matching a concept name.
        Uses context scoring to select the best context.
        """
        if facts_df.empty:
            return None
        
        # Filter by concept
        normalized_tags = facts_df['tag'].astype(str).str.split(":").str[-1]
        mask = normalized_tags.eq(concept_name)
        
        matching_facts = facts_df[mask]
        
        if matching_facts.empty:
            return None
        
        # Score contexts and select the best one
        matching_facts = matching_facts.copy()
        matching_facts['context_score'] = matching_facts.apply(self._score_context, axis=1)
        
        # Sort by score descending, then take the first (highest score)
        best_fact = matching_facts.sort_values('context_score', ascending=False).iloc[0]
        
        try:
            value = float(best_fact['value']) if pd.notna(best_fact['value']) else None
            
            # Convert all monetary values to crores (standard for Indian financial data)
            if value is not None and line_item not in NO_CONVERSION_FIELDS:
                value = value / 10_000_000  # Convert to Crores
            
            return value
        except (ValueError, TypeError):
            return None
    
    def map_statement(self, facts_df: pd.DataFrame, 
                      statement_type: str,
                      period_end_date: str) -> Dict:
        """
        Map facts to a statement type (income, balance, cash_flow) using concept catalog.
        
        Args:
            facts_df: DataFrame of XBRL facts
            statement_type: 'Income', 'Balance', or 'CashFlow' (must match catalog)
            period_end_date: End date of the reporting period
        
        Returns:
            Dictionary with line items as keys and values as values
        """
        statement = {
            'period_end_date': period_end_date,
            'statement_type': statement_type.lower(),
        }
        
        # Filter catalog for this statement type
        statement_catalog = self.concept_catalog[
            self.concept_catalog['statement'].eq(statement_type)
        ]
        
        if statement_catalog.empty:
            logger.warning(f"No concepts found in catalog for statement type: {statement_type}")
            return statement
        
        # Get unique line items in display order
        line_items = statement_catalog.sort_values('display_order')['line_item'].unique().tolist()
        
        # Initialize all line items to None to ensure consistent keys
        for line_item in line_items:
            statement[line_item] = None
        
        # Group by line_item and process by priority
        for line_item, group in statement_catalog.groupby('line_item'):
            # Sort by priority (lower value = higher priority)
            group_sorted = group.sort_values('priority')
            
            # Try concepts in priority order, take first that has a value
            value = None
            for _, row in group_sorted.iterrows():
                concept = row['concept']
                priority = row['priority']
                
                extracted_value = self._extract_value_from_facts(facts_df, concept, line_item)
                if extracted_value is not None:
                    value = extracted_value
                    break
            
            statement[line_item] = value
        
        return statement
    
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
                variant_contexts = [ctx for ctx, ctx_variant in context_variant_map.items() if ctx_variant == variant]
                if variant_contexts:
                    variant_facts = facts_df[facts_df['context'].astype(str).isin(variant_contexts)].copy()
                else:
                    variant_facts = facts_df.iloc[0:0].copy()
                
                if variant_facts.empty:
                    continue
                
                # Map to each statement type using generic method
                income_dict = self.map_statement(variant_facts, 'Income', period_end_date)
                income_dict.update({
                    'bse_code': bse_code,
                    'exchange': exchange,
                    'period': period,
                    'filing_type': filing_type,
                    'variant': variant,
                    'audited_status': audited_status or 'unknown',
                })
                income_stmts.append(income_dict)
                
                balance_dict = self.map_statement(variant_facts, 'Balance', period_end_date)
                balance_dict.update({
                    'bse_code': bse_code,
                    'exchange': exchange,
                    'period': period,
                    'filing_type': filing_type,
                    'variant': variant,
                    'audited_status': audited_status or 'unknown',
                })
                balance_stmts.append(balance_dict)
                
                cash_flow_dict = self.map_statement(variant_facts, 'CashFlow', period_end_date)
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
        """
        Save mapped statements to single CSV files per statement type.
        Each row includes metadata columns (period, variant, filing_type, audited_status).
        """
        output_dir = STATEMENTS_OUTPUT_DIR / exchange / company_code
        output_dir.mkdir(parents=True, exist_ok=True)
        
        def _write_statement_csv(rows: List[Dict], file_path: Path, column_order: List[str]) -> str:
            """Write statement rows to CSV with deduplication and column ordering."""
            if not rows:
                # If no new rows, keep existing file or create empty
                if file_path.exists():
                    return str(file_path)
                else:
                    new_df = pd.DataFrame(columns=column_order)
                    new_df.to_csv(file_path, index=False)
                    return str(file_path)
            
            new_df = pd.DataFrame(rows)
            
            # If file exists, check if schemas match before merging
            if file_path.exists():
                try:
                    old_df = pd.read_csv(file_path)
                    # Check if column sets match
                    old_cols = set(old_df.columns)
                    new_cols = set(new_df.columns)
                    
                    # If schemas are different, delete old file and write new
                    if old_cols != new_cols:
                        file_path.unlink()  # Delete old file
                        merged = new_df
                    else:
                        # Schemas match, merge and deduplicate
                        merged = pd.concat([old_df, new_df], ignore_index=True)
                        dedupe_keys = [k for k in ["bse_code", "exchange", "period", "filing_type", "variant", "audited_status"] if k in merged.columns]
                        if dedupe_keys:
                            merged = merged.drop_duplicates(subset=dedupe_keys, keep="last")
                except Exception:
                    merged = new_df
            else:
                merged = new_df
            
            # Reorder columns according to specified order
            if not merged.empty:
                # Filter to only columns that exist in the DataFrame
                existing_columns = [col for col in column_order if col in merged.columns]
                # Add any extra columns not in the order list at the end
                extra_columns = [col for col in merged.columns if col not in existing_columns]
                final_column_order = existing_columns + extra_columns
                merged = merged[final_column_order]
                merged.to_csv(file_path, index=False)
            return str(file_path)
        
        # Get all line items from catalog for column ordering (unique only)
        income_columns = ['period_end_date', 'statement_type', 'bse_code', 'exchange', 'period', 'filing_type', 'variant', 'audited_status']
        balance_columns = ['period_end_date', 'statement_type', 'bse_code', 'exchange', 'period', 'filing_type', 'variant', 'audited_status']
        cash_flow_columns = ['period_end_date', 'statement_type', 'bse_code', 'exchange', 'period', 'filing_type', 'variant', 'audited_status']
        
        if not self.concept_catalog.empty:
            # Sort by display_order, then get unique line items
            income_catalog = self.concept_catalog[self.concept_catalog['statement'].eq('Income')].sort_values('display_order')
            balance_catalog = self.concept_catalog[self.concept_catalog['statement'].eq('Balance')].sort_values('display_order')
            cash_flow_catalog = self.concept_catalog[self.concept_catalog['statement'].eq('CashFlow')].sort_values('display_order')
            
            income_items = income_catalog['line_item'].unique().tolist()
            balance_items = balance_catalog['line_item'].unique().tolist()
            cash_flow_items = cash_flow_catalog['line_item'].unique().tolist()
            
            income_columns.extend(income_items)
            balance_columns.extend(balance_items)
            cash_flow_columns.extend(cash_flow_items)
        
        # Save to single files per statement type
        income_file = _write_statement_csv(
            income_stmts,
            output_dir / "income_statement.csv",
            income_columns
        )
        balance_file = _write_statement_csv(
            balance_stmts,
            output_dir / "balance_sheet.csv",
            balance_columns
        )
        cash_flow_file = _write_statement_csv(
            cash_flow_stmts,
            output_dir / "cash_flow.csv",
            cash_flow_columns
        )
        
        logger.info(f"Saved income statement: {income_file}")
        logger.info(f"Saved balance sheet: {balance_file}")
        logger.info(f"Saved cash flow statement: {cash_flow_file}")
        
        return income_file, balance_file, cash_flow_file


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    builder = FinancialStatementBuilder()
    logger.info("Financial Statement Builder initialized")
    logger.info(f"Loaded {len(builder.concept_catalog)} concepts from catalog")
