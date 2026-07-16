from pathlib import Path
import pandas as pd

raw_fact_files = list(Path('xbrl_pipeline/raw_facts').rglob('*_facts.csv'))
if not raw_fact_files:
    raise SystemExit('No raw facts files found')

frames = []
for file_path in raw_fact_files:
    frame = pd.read_csv(file_path)
    if 'concept' not in frame.columns:
        continue
    subset = frame[['concept']].dropna().copy()
    subset['file'] = str(file_path)
    frames.append(subset)

if not frames:
    raise SystemExit('No concept data found in raw facts files')

all_concepts = pd.concat(frames, ignore_index=True)
summary = (
    all_concepts.groupby('concept', as_index=False)
    .agg(total_facts=('concept', 'size'), filings=('file', 'nunique'))
    .sort_values(['filings', 'total_facts'], ascending=[False, False])
)

output_dir = Path('xbrl_pipeline')
summary_path = output_dir / 'concept_frequency_sample10.csv'
summary.to_csv(summary_path, index=False)

filing_count = all_concepts['file'].nunique()
threshold = max(5, int(round(filing_count * 0.8)))
stable_core = summary[summary['filings'] >= threshold].copy()
stable_core_path = output_dir / 'stable_core_concepts_sample10.csv'
stable_core.to_csv(stable_core_path, index=False)

print(f'filings={filing_count}')
print(f'unique_concepts={len(summary)}')
print(f'stable_core_threshold={threshold}')
print(f'stable_core_concepts={len(stable_core)}')
print('\nTOP 30 CONCEPTS')
print(summary.head(30).to_string(index=False))
print('\nSTABLE CORE CONCEPTS')
print(stable_core.head(30).to_string(index=False))
