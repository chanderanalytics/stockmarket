
"""create_insider_trades_table

Revision ID: 4d6baaf7b96b
Revises: e66481ab222e
Create Date: 2025-08-12 12:26:45.245262

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '4d6baaf7b96b'
down_revision: Union[str, Sequence[str], None] = 'e66481ab222e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        'insidertrades',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('symbol', sa.String(), nullable=False),
        sa.Column('company', sa.String(), nullable=False),
        sa.Column('regulation', sa.String(), nullable=False),
        sa.Column('acquirer_disposer', sa.String(), nullable=False),
        sa.Column('category', sa.String(), nullable=False),
        sa.Column('date', sa.Date(), nullable=True),
        sa.Column('last_modified', sa.Date(), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index('idx_insidertrades_symbol', 'insidertrades', ['symbol'], unique=False)
    op.create_index('idx_insidertrades_company', 'insidertrades', ['company'], unique=False)
    op.create_index('idx_insidertrades_date', 'insidertrades', ['date'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('idx_insidertrades_symbol', table_name='insidertrades')
    op.drop_index('idx_insidertrades_company', table_name='insidertrades')
    op.drop_index('idx_insidertrades_date', table_name='insidertrades')
    op.drop_table('insidertrades')
