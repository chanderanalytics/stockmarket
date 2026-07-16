# Copilot Instructions for `stockmarket`

- This repository is a data pipeline + analytics platform for Indian stock market data.
- The pipeline is split into two main domains:
  - `Python` ingestion under `data_ingestion/` (one-time imports + daily updates)
  - `R` feature engineering under `data_ingestion/Rscripts/`
- The database schema is defined in `backend/models.py`; schema changes must also be reflected in `alembic/` migrations.

## Key workflows

- Use `pip install -r requirements.txt` and activate `.venv/bin/activate` before running Python scripts.
- The main daily orchestration is `run_daily_pipeline.sh`. It expects a screener export CSV like `data/screener_export/screener_export_YYYYMMDD.csv`.
- One-time import sequence is:
  1. `python3 data_ingestion/onetime/1.1_import_screener_companies.py <csv>`
  2. `python3 data_ingestion/onetime/2.1_onetime_prices.py`
  3. `python3 data_ingestion/onetime/3.1_onetime_corporate_actions.py`
  4. `python3 data_ingestion/onetime/4.1_onetime_indices.py`
- R feature-engineering sequence is:
  - `Rscript data_ingestion/Rscripts/2_companies_insights.R`
  - `Rscript data_ingestion/Rscripts/3_companies_prices_features.R`
  - `Rscript data_ingestion/Rscripts/4_corporate_action_flags.R`
  - `Rscript data_ingestion/Rscripts/5_price_volume_probabilities_vectorized.R`

## Important conventions

- Database tables follow a unified code/key pattern: `company_code`, `company_id`, `date`.
- Batch results are stored in `output/batch_*.csv`; the R pipeline recombines these with `5b_recombine_batches_and_merge.R`.
- Logs live in `log/`; many scripts use `tail -f log/<script>_*.log` for progress checks.
- The project expects PostgreSQL and uses `psql` checks in README examples.

## What to preserve

- Do not change pipeline file naming or the date-extraction convention in `run_daily_pipeline.sh` without verifying the downstream scripts.
- Keep the separation between Python ingestion and R analytics; most changes should remain in the layer that owns the data behavior.
- When editing DB schema, check `backend/models.py` and `alembic/env.py` plus relevant `alembic/versions/*.py` files.

## What is not present

- There is no dedicated automated test suite discovered in the repository.
- There is no existing `AGENT.md` or `.github/copilot-instructions.md`; use `README.md`, `run_daily_pipeline.sh`, and `backend/models.py` as primary sources.

## Best immediate tasks for an AI coding agent

