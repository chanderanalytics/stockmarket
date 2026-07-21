"""add_dma_distance_columns

Add per-horizon DMA distance columns to company_breadth_signals.
Distance = (close - dma) / dma * 100 for each DMA period and horizon.

Revision ID: 20260720_add_dma_distance
Revises: 20260720_0944
Create Date: 2026-07-20 22:30:00.000000
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = "20260720_add_dma_distance"
down_revision: Union[str, None] = "20260720_0944"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    horizons = [0, 1, 5, 21, 63, 126, 256]
    periods = [20, 50, 100, 200]
    for h in horizons:
        for p in periods:
            op.add_column(
                "company_breadth_signals",
                sa.Column(f"dma_dist_{p}_{h}", sa.Numeric(20, 6), nullable=True),
            )


def downgrade() -> None:
    horizons = [0, 1, 5, 21, 63, 126, 256]
    periods = [20, 50, 100, 200]
    for h in horizons:
        for p in periods:
            op.drop_column("company_breadth_signals", f"dma_dist_{p}_{h}")
