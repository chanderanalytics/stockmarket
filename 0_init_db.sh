#!/bin/bash
cd "$(dirname "$0")"

set -e

echo "=== Initializing database schema with Alembic ==="
# Uncomment the next line if you need to activate a virtual environment
# source .venv/bin/activate

echo "=== Autogenerating Alembic migration for current models ==="
alembic revision --autogenerate -m "autogenerated migration for all tables"

alembic upgrade head

echo "✅ Database schema initialized successfully." 