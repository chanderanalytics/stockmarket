"""Create prices_adjusted table

Revision ID: 2025-09-09_2232
Revises: 
Create Date: 2025-09-09 22:32:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '20250909_2232'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    """Create the prices_adjusted table."""
    op.create_table(
        'prices_adjusted',
        sa.Column('id', sa.Integer, primary_key=True),
        sa.Column('price_id', sa.Integer, sa.ForeignKey('prices.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('company_id', sa.Integer, sa.ForeignKey('companies.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('company_code', sa.String, nullable=True, index=True),
        sa.Column('date', sa.Date, nullable=False, index=True),
        sa.Column('open', sa.Numeric(20, 6), nullable=True),
        sa.Column('high', sa.Numeric(20, 6), nullable=True),
        sa.Column('low', sa.Numeric(20, 6), nullable=True),
        sa.Column('close', sa.Numeric(20, 6), nullable=True),
        sa.Column('volume', sa.BigInteger, nullable=True),
        sa.Column('adj_close', sa.Numeric(20, 6), nullable=True),
        sa.Column('adjustment_factor', sa.Numeric(20, 6), nullable=True, comment='Cumulative adjustment factor applied'),
        sa.Column('last_updated', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.UniqueConstraint('price_id', name='uix_price_adjusted_id'),
        sa.Index('idx_prices_adj_company_date', 'company_id', 'date'),
        sa.Index('idx_prices_adj_company_code_date', 'company_code', 'date')
    )
    
    # Add comment to the table
    op.execute("COMMENT ON TABLE prices_adjusted IS 'Adjusted prices for corporate actions (splits, bonuses, etc.)'")

def downgrade() -> None:
    """Drop the prices_adjusted table."""
    op.drop_table('prices_adjusted')
