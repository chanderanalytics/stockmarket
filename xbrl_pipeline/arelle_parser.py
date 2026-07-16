"""
XBRL Parser using Arelle.
Extracts raw facts from XBRL files and outputs to CSV.
"""

import logging
import pandas as pd
from pathlib import Path
from typing import List, Dict, Optional
from datetime import datetime

try:
    from arelle import Cntlr, ModelManager
    ARELLE_AVAILABLE = True
except ImportError:
    ARELLE_AVAILABLE = False
    logging.warning("Arelle not installed. Install with: pip install arelle-release")

logger = logging.getLogger(__name__)

FACTS_OUTPUT_DIR = Path("xbrl_pipeline/raw_facts")
FACTS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


class ArelleXBRLParser:
    """Parse XBRL files using Arelle and extract facts."""
    
    def __init__(self):
        if not ARELLE_AVAILABLE:
            raise ImportError("Arelle is required. Install with: pip install arelle-release")

        self.controller = Cntlr.Cntlr(logFileName="logToPrint")
        self.model_manager = self.controller.modelManager
    
    def parse_xbrl(self, xbrl_file_path: str) -> Optional[Dict]:
        """
        Parse XBRL file with Arelle and extract facts.
        Returns dict with structure:
        {
            'facts': [
                {
                    'tag': 'in-capmkt:RevenueFromOperations',
                    'context': 'OneD',
                    'unit': 'INR',
                    'value': '35570100000',
                    'decimals': '-5'
                },
                ...
            ],
            'contexts': {...},
            'units': {...},
            'metadata': {
                'audited_status': 'audited' | 'unaudited' | 'unknown',
                'variant': 'standalone' | 'consolidated' | 'unknown',
                'reporting_period': 'YYYY-MM-DD',
                'statement_type': 'annual' | 'quarterly' | 'unknown'
            }
        }
        """
        try:
            logger.info(f"Parsing XBRL: {xbrl_file_path}")

            # Recommended Arelle usage: load returns ModelXbrl
            model_xbrl = self.model_manager.load(xbrl_file_path)

            if not model_xbrl:
                logger.error(f"Failed to load XBRL: {xbrl_file_path}")
                return None

            # Extract facts.
            # If taxonomy schema imports are unresolved, Arelle keeps items in
            # undefinedFacts (still Arelle-native objects) instead of facts.
            fact_objects = list(model_xbrl.facts)
            if not fact_objects and getattr(model_xbrl, "undefinedFacts", None):
                fact_objects = list(model_xbrl.undefinedFacts)
                logger.warning(
                    "Arelle facts are empty; using undefinedFacts (schemaImportMissing likely)."
                )

            facts = []
            for fact in fact_objects:
                try:
                    qname = getattr(fact, "qname", None)
                    if qname is not None:
                        tag = f"{qname.prefix}:{qname.localName}" if qname.prefix else qname.localName
                        concept_name = qname.localName
                    else:
                        tag = getattr(fact, "prefixedName", None) or getattr(fact, "localName", None)
                        concept_name = getattr(fact, "localName", None)

                    context_id = getattr(fact, "contextID", None) or (fact.get("contextRef") if hasattr(fact, "get") else None)
                    unit_id = getattr(fact, "unitID", None) or (fact.get("unitRef") if hasattr(fact, "get") else None)
                    value = getattr(fact, "value", None)
                    if value is None:
                        value = getattr(fact, "text", None)

                    concept_obj = getattr(fact, "concept", None)
                    label = None
                    balance = None
                    period_type = None
                    if concept_obj is not None:
                        try:
                            label = concept_obj.label(lang="en")
                        except Exception:
                            label = None
                        balance = getattr(concept_obj, "balance", None)
                        period_type = getattr(concept_obj, "periodType", None)

                    dimensions = []
                    context_obj = getattr(fact, "context", None)
                    if context_obj is not None:
                        try:
                            for dim_qname, mem_obj in context_obj.qnameDims.items():
                                mem_qname = getattr(mem_obj, "memberQname", None)
                                dimensions.append({
                                    "dimension": str(dim_qname),
                                    "member": str(mem_qname) if mem_qname is not None else None,
                                })
                        except Exception:
                            pass

                    fact_dict = {
                        'tag': tag,
                        'concept': concept_name,
                        'label': label,
                        'namespace': str(qname.namespaceURI) if qname is not None else getattr(fact, "namespaceURI", None),
                        'context': context_id,
                        'unit': unit_id,
                        'value': str(value) if value is not None else None,
                        'decimals': str(getattr(fact, "decimals", None)) if getattr(fact, "decimals", None) is not None else None,
                        'balance': balance,
                        'period_type_concept': period_type,
                        'is_numeric': bool(getattr(fact, "isNumeric", False)),
                        'dimensions': str(dimensions) if dimensions else None,
                        'language': getattr(fact, "xmlLang", None),
                        'xml_id': getattr(fact, "id", None),
                    }
                    facts.append(fact_dict)
                except Exception as e:
                    logger.debug(f"Error extracting fact details: {e}")
                    continue

            
            # Extract contexts with period information
            contexts = {}
            for context_id, context in model_xbrl.contexts.items():
                try:
                    period_type = 'instant'
                    start_date = None
                    end_date = None
                    
                    if hasattr(context, 'isInstant') and context.isInstant:
                        period_type = 'instant'
                        if hasattr(context, 'instantDatetime'):
                            end_date = str(context.instantDatetime)
                    elif hasattr(context, 'isStartEndDatetime') and context.isStartEndDatetime:
                        period_type = 'duration'
                        if hasattr(context, 'startDatetime'):
                            start_date = str(context.startDatetime)
                        if hasattr(context, 'endDatetime'):
                            end_date = str(context.endDatetime)
                    
                    entity_id = None
                    if hasattr(context, 'entityIdentifier') and context.entityIdentifier:
                        entity_id = context.entityIdentifier[1]
                    
                    contexts[context_id] = {
                        'period_type': period_type,
                        'start_date': start_date,
                        'end_date': end_date,
                        'entity_id': entity_id,
                    }
                except Exception as e:
                    logger.debug(f"Error extracting context {context_id}: {e}")
                    contexts[context_id] = {'period_type': 'unknown'}
            
            # Extract units
            units = {}
            for unit_id, unit in model_xbrl.units.items():
                try:
                    measure_list = []
                    if hasattr(unit, 'measures'):
                        for measure_tuple in unit.measures:
                            if isinstance(measure_tuple, tuple):
                                measure_list.append(str(measure_tuple[1]))
                            else:
                                measure_list.append(str(measure_tuple))
                    
                    units[unit_id] = {
                        'measures': ', '.join(measure_list) if measure_list else None,
                    }
                except Exception as e:
                    logger.debug(f"Error extracting unit {unit_id}: {e}")
                    units[unit_id] = {'measures': None}
            
            # Extract metadata from facts
            metadata = self._extract_metadata(facts)
            
            result = {
                'facts': facts,
                'contexts': contexts,
                'units': units,
                'metadata': metadata,
                'fact_count': len(facts),
                'parsed_at': datetime.now().isoformat(),
            }
            
            logger.info(f"✓ Extracted {len(facts)} facts from {xbrl_file_path}")
            logger.info(f"  Metadata: audited={metadata.get('audited_status')}, variant={metadata.get('variant')}, period={metadata.get('reporting_period')}")
            return result
            
        except Exception as e:
            logger.error(f"Error parsing XBRL {xbrl_file_path}: {e}")
            import traceback
            traceback.print_exc()
            return None

    def facts_to_dataframe(self, parsed_xbrl: Dict) -> pd.DataFrame:
        """Convert parsed XBRL facts to DataFrame."""
        if not parsed_xbrl or 'facts' not in parsed_xbrl:
            return pd.DataFrame()
        
        facts_list = parsed_xbrl['facts']
        df = pd.DataFrame(facts_list)
        
        # Add context metadata
        if 'contexts' in parsed_xbrl:
            context_map = parsed_xbrl['contexts']
            df['period_type'] = df['context'].map(
                lambda x: context_map.get(x, {}).get('period_type') if x in context_map else None
            )
            df['end_date'] = df['context'].map(
                lambda x: context_map.get(x, {}).get('end_date') if x in context_map else None
            )
            df['start_date'] = df['context'].map(
                lambda x: context_map.get(x, {}).get('start_date') if x in context_map else None
            )
            df['entity_id'] = df['context'].map(
                lambda x: context_map.get(x, {}).get('entity_id') if x in context_map else None
            )
        
        # Add unit info
        if 'units' in parsed_xbrl:
            unit_map = parsed_xbrl['units']
            df['unit_measure'] = df['unit'].map(
                lambda x: unit_map.get(x, {}).get('measures') if x in unit_map else None
            )
        
        return df
    
    def save_facts_csv(
        self,
        parsed_xbrl: Dict,
        bse_code: str,
        period: str,
        exchange: str,
        variant: Optional[str] = None,
        filing_type: Optional[str] = None,
        audited_status: Optional[str] = None,
    ) -> str:
        """Save extracted facts to CSV."""
        df = self.facts_to_dataframe(parsed_xbrl)

        filename = f"{period}"
        if variant:
            filename += f"_{variant}"
        if filing_type:
            filename += f"_{filing_type}"
        if audited_status:
            filename += f"_{audited_status}"
        filename += "_facts.csv"

        output_file = FACTS_OUTPUT_DIR / exchange / bse_code / filename
        output_file.parent.mkdir(parents=True, exist_ok=True)
        
        df.to_csv(output_file, index=False)
        logger.info(f"Saved facts CSV: {output_file}")
        
        return str(output_file)
    
    def _extract_metadata(self, facts: List[Dict]) -> Dict:
        """Extract metadata from XBRL facts using Arelle's taxonomy resolution."""
        metadata = {
            'audited_status': 'unknown',
            'variant': 'unknown',
            'reporting_period': None,
            'statement_type': 'unknown',
        }
        
        # Create a lookup dict for facts by concept name
        facts_by_concept = {f.get('concept', '').lower(): f for f in facts}
        
        # Extract audited status - check all facts with audited concepts
        audited_concepts = [
            'whetherresultsareauditedorunaudited',
            'whetherresultsareauditedorunauditedorprovisional',
        ]
        audited_values = []
        for fact in facts:
            concept_lower = fact.get('concept', '').lower()
            if concept_lower in audited_concepts:
                value = fact.get('value', '').strip().lower()
                if value:
                    audited_values.append(value)
        
        # Use the most common audited status, or prioritize 'unaudited' if present
        if audited_values:
            if 'unaudited' in audited_values or 'provisional' in audited_values:
                metadata['audited_status'] = 'unaudited'
            elif 'audited' in audited_values:
                metadata['audited_status'] = 'audited'
            else:
                # Use the first value if neither audited nor unaudited
                metadata['audited_status'] = audited_values[0]
        
        # Extract standalone/consolidated variant
        variant_concepts = [
            'natureofreportstandaloneconsolidated',
        ]
        for concept in variant_concepts:
            if concept in facts_by_concept:
                value = facts_by_concept[concept].get('value', '').strip().lower()
                if 'standalone' in value:
                    metadata['variant'] = 'standalone'
                    break
                elif 'consolidated' in value:
                    metadata['variant'] = 'consolidated'
                    break
        
        # Extract reporting period end date
        period_concepts = [
            'dateofendofreportingperiod',
            'reportingperiodenddate',
        ]
        for concept in period_concepts:
            if concept in facts_by_concept:
                value = facts_by_concept[concept].get('value', '').strip()
                if value:
                    # Try to parse and normalize the date
                    try:
                        # Handle various date formats
                        if '-' in value:
                            # Already in ISO format or similar
                            parsed_date = datetime.strptime(value.split('T')[0], '%Y-%m-%d')
                            metadata['reporting_period'] = parsed_date.strftime('%Y-%m')
                        else:
                            # Try other formats
                            for fmt in ['%d-%m-%Y', '%d/%m/%Y', '%m/%d/%Y']:
                                try:
                                    parsed_date = datetime.strptime(value, fmt)
                                    metadata['reporting_period'] = parsed_date.strftime('%Y-%m')
                                    break
                                except ValueError:
                                    continue
                    except Exception as e:
                        logger.debug(f"Could not parse reporting period '{value}': {e}")
                break
        
        # Infer statement type from period if not explicit
        if metadata['reporting_period']:
            # Check ReportingQuarter concept for explicit statement type
            reporting_quarter_concepts = [
                'reportingquarter',
            ]
            for concept in reporting_quarter_concepts:
                if concept in facts_by_concept:
                    value = facts_by_concept[concept].get('value', '').strip().lower()
                    if value in ('yearly', 'annual', 'year'):
                        metadata['statement_type'] = 'annual'
                        break
                    elif value in ('quarterly', 'quarter', 'half yearly', 'first quarter', 'second quarter', 'third quarter', 'fourth quarter'):
                        metadata['statement_type'] = 'quarterly'
                        break
            
            # If still unknown, infer from month
            if metadata['statement_type'] == 'unknown':
                month = int(metadata['reporting_period'].split('-')[1])
                # Indian companies typically have year-end in March
                # March could be either annual (year-end) or quarterly (Q4)
                # Default to quarterly for now as it's more common
                metadata['statement_type'] = 'quarterly'
        
        return metadata
    
    def rename_xbrl_file(self, temp_file_path: str, metadata: Dict, company_code: str, exchange: str) -> str:
        """Rename temp XBRL file to proper name based on extracted metadata.
        
        Format: {period}_{variant}_{statement_type}_{audited_status}.xbrl
        Example: 2025-03_standalone_quarterly_unaudited.xbrl
        """
        temp_path = Path(temp_file_path)
        if not temp_path.exists():
            logger.warning(f"Temp file does not exist: {temp_file_path}")
            return temp_file_path
        
        # Build new filename
        period = metadata.get('reporting_period', 'unknown')
        variant = metadata.get('variant', 'unknown')
        stmt_type = metadata.get('statement_type', 'unknown')
        audited = metadata.get('audited_status', 'unknown')
        
        new_filename = f"{period}_{variant}_{stmt_type}_{audited}.xbrl"
        new_path = temp_path.parent / new_filename
        
        # Rename file
        try:
            temp_path.rename(new_path)
            logger.info(f"Renamed: {temp_path.name} → {new_filename}")
            return str(new_path)
        except Exception as e:
            logger.error(f"Failed to rename {temp_path}: {e}")
            return temp_file_path


def parse_all_xbrl_files(xbrl_dir: str = "xbrl_pipeline/xbrl_files") -> List[Dict]:
    """Parse all XBRL files in directory."""
    parser = ArelleXBRLParser()
    results = []
    
    xbrl_path = Path(xbrl_dir)
    for xbrl_file in xbrl_path.rglob("*.xbrl"):
        logger.info(f"Processing {xbrl_file}")
        parsed = parser.parse_xbrl(str(xbrl_file))
        
        if parsed:
            # Extract metadata from file path
            parts = xbrl_file.relative_to(xbrl_path).parts
            if len(parts) >= 3:
                exchange, bse_code, filename = parts[0], parts[1], parts[2]
                period = filename.replace('_annual.xbrl', '').replace('_quarterly.xbrl', '')
                
                # Save to CSV
                csv_path = parser.save_facts_csv(parsed, bse_code, period, exchange)
                
                results.append({
                    'xbrl_file': str(xbrl_file),
                    'exchange': exchange,
                    'bse_code': bse_code,
                    'period': period,
                    'facts_csv': csv_path,
                    'fact_count': parsed['fact_count'],
                })
    
    return results


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    # Example: Parse all XBRL files
    results = parse_all_xbrl_files()
    
    for result in results:
        print(f"✓ {result['bse_code']} ({result['period']}): {result['fact_count']} facts")
        print(f"  CSV: {result['facts_csv']}")
