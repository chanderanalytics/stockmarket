"""Add historical_prices table

Revision ID: 20250911000000
Revises: 577d6253b8c7
Create Date: 2025-09-11 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '20250911000000'
down_revision = '577d6253b8c7'
branch_labels = None
depends_on = None

def upgrade():
    """Create the historical_prices table with all necessary columns and indexes."""
    op.create_table(
        'historical_prices',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('company_id', sa.Integer(), nullable=True),
        sa.Column('company_code', sa.String(length=50), nullable=False),
        sa.Column('company_name', sa.String(length=255), nullable=True),
        sa.Column('exchange', sa.String(length=10), nullable=False),
        sa.Column('date', sa.Date(), nullable=False),
        sa.Column('open', sa.Numeric(precision=20, scale=2), nullable=True),
        sa.Column('high', sa.Numeric(precision=20, scale=2), nullable=True),
        sa.Column('low', sa.Numeric(precision=20, scale=2), nullable=True),
        sa.Column('close', sa.Numeric(precision=20, scale=2), nullable=False),
        sa.Column('volume', sa.BigInteger(), nullable=True),
        sa.Column('last_price', sa.Numeric(precision=20, scale=2), nullable=True),
        sa.Column('prev_close', sa.Numeric(precision=20, scale=2), nullable=True),
        sa.Column('vwap', sa.Numeric(precision=20, scale=2), nullable=True),
        sa.Column('day_change', sa.Numeric(precision=10, scale=2), nullable=True),
        sa.Column('day_change_pct', sa.Numeric(precision=10, scale=4), nullable=True),
        sa.Column('sma_20', sa.Numeric(precision=20, scale=2), nullable=True),
        sa.Column('sma_50', sa.Numeric(precision=20, scale=2), nullable=True),
        sa.Column('sma_200', sa.Numeric(precision=20, scale=2), nullable=True),
        sa.Column('volume_20d_avg', sa.BigInteger(), nullable=True),
        sa.Column('is_adjusted', sa.Boolean(), server_default='false', nullable=False),
        sa.Column('data_source', sa.String(length=50), nullable=True),
        sa.Column('last_updated', sa.DateTime(), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['company_id'], ['companies.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('company_code', 'date', name='uq_historical_price_company_date')
    )
    
    # Create indexes for performance
    op.create_index('idx_historical_prices_company_date', 'historical_prices', ['company_code', 'date'], unique=True)
    op.create_index('idx_historical_prices_date', 'historical_prices', ['date'], unique=False)
    op.create_index('idx_historical_prices_exchange', 'historical_prices', ['exchange'], unique=False)

def downgrade():
    """Drop the historical_prices table and its indexes."""
    # Drop indexes first
    op.drop_index('idx_historical_prices_exchange', table_name='historical_prices')
    op.drop_index('idx_historical_prices_date', table_name='historical_prices')
    op.drop_index('idx_historical_prices_company_date', table_name='historical_prices')
    
    # Then drop the table
    op.drop_table('historical_prices')
