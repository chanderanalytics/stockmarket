"""create_company_breadth_signals_table

Create company_breadth_signals table for precomputed breadth signals.

Revision ID: 20260720_0944
Revises: 
Create Date: 2025-07-20 09:44:00.000000
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


revision: str = "20260720_0944"
down_revision: Union[str, None] = "20250911000000"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "company_breadth_signals",
        sa.Column("company_id", sa.Integer, nullable=False),
        sa.Column("name", sa.Text, nullable=True),
        sa.Column("sector", sa.Text, nullable=True),
        sa.Column("industry", sa.Text, nullable=True),
        sa.Column("industry_sub_group", sa.Text, nullable=True),
        sa.Column("industry_group", sa.Text, nullable=True),
        sa.Column("market_cap", sa.Numeric(20, 2), nullable=True),
        sa.Column("cap_class", sa.Text, nullable=True),
        sa.Column("latest_close", sa.Numeric(20, 6), nullable=True),
        sa.Column("return_252d", sa.Numeric(20, 6), nullable=True),
        sa.Column("volume", sa.BigInteger, nullable=True),
        sa.Column("avg_volume_1y", sa.BigInteger(), nullable=True),
        sa.Column("high_price_all_time", sa.Numeric(20, 6), nullable=True),
        sa.Column("low_price_all_time", sa.Numeric(20, 6), nullable=True),
        sa.Column("sig_new_high_0", sa.SmallInteger(), nullable=True),
        sa.Column("sig_new_low_0", sa.SmallInteger(), nullable=True),
        sa.Column("dma_20_0", sa.Numeric(20, 6), nullable=True),
        sa.Column("dma_50_0", sa.Numeric(20, 6), nullable=True),
        sa.Column("dma_100_0", sa.Numeric(20, 6), nullable=True),
        sa.Column("dma_200_0", sa.Numeric(20, 6), nullable=True),
        sa.Column("computed_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("company_id", name="pk_company_breadth_signals"),
        sa.Index("idx_company_breadth_signals_sector", "sector"),
        sa.Index("idx_company_breadth_signals_industry", "industry"),
        sa.Index("idx_company_breadth_signals_subgroup", "industry_sub_group"),
        sa.Index("idx_company_breadth_signals_cap_class", "cap_class"),
    )

    horizons = [0, 1, 5, 21, 63, 126, 256]
    periods = [20, 50, 100, 200]
    for h in horizons:
        for p in periods:
            op.add_column(
                "company_breadth_signals",
                sa.Column(f"sig_above_{p}dma_{h}", sa.SmallInteger(), nullable=True),
            )
        op.add_column(
            "company_breadth_signals",
            sa.Column(f"sig_advance_{h}", sa.SmallInteger(), nullable=True),
        )
        op.add_column(
            "company_breadth_signals",
            sa.Column(f"sig_decline_{h}", sa.SmallInteger(), nullable=True),
        )

    op.execute(
        """
        COMMENT ON TABLE company_breadth_signals IS
        'Precomputed breadth signals per company, refreshed by market_breadth_signals refresh-cache.'
        """
    )


def downgrade() -> None:
    op.drop_table("company_breadth_signals")
