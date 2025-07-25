
"""drop earnings table

Revision ID: de904ac0b6a4
Revises: fba59c283a78
Create Date: 2025-07-10 11:01:57.231808

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'de904ac0b6a4'
down_revision: Union[str, Sequence[str], None] = 'fba59c283a78'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_index(op.f('idx_earnings_company_code_date'), table_name='earnings')
    op.drop_index(op.f('idx_earnings_company_code_quarter'), table_name='earnings')
    op.drop_table('earnings')
    # ### end Alembic commands ###


def downgrade() -> None:
    """Downgrade schema."""
    # ### commands auto generated by Alembic - please adjust! ###
    op.create_table('earnings',
    sa.Column('id', sa.INTEGER(), autoincrement=True, nullable=False),
    sa.Column('company_id', sa.INTEGER(), autoincrement=False, nullable=True),
    sa.Column('company_code', sa.VARCHAR(), autoincrement=False, nullable=True),
    sa.Column('company_name', sa.VARCHAR(), autoincrement=False, nullable=True),
    sa.Column('date', sa.DATE(), autoincrement=False, nullable=True),
    sa.Column('quarter', sa.VARCHAR(), autoincrement=False, nullable=True),
    sa.Column('year', sa.INTEGER(), autoincrement=False, nullable=True),
    sa.Column('quarter_number', sa.INTEGER(), autoincrement=False, nullable=True),
    sa.Column('revenue', sa.NUMERIC(), autoincrement=False, nullable=True),
    sa.Column('earnings', sa.NUMERIC(), autoincrement=False, nullable=True),
    sa.Column('earnings_per_share', sa.NUMERIC(), autoincrement=False, nullable=True),
    sa.Column('revenue_estimate', sa.NUMERIC(), autoincrement=False, nullable=True),
    sa.Column('earnings_estimate', sa.NUMERIC(), autoincrement=False, nullable=True),
    sa.Column('revenue_surprise', sa.NUMERIC(), autoincrement=False, nullable=True),
    sa.Column('earnings_surprise', sa.NUMERIC(), autoincrement=False, nullable=True),
    sa.Column('last_modified', sa.DATE(), autoincrement=False, nullable=True),
    sa.ForeignKeyConstraint(['company_id'], ['companies.id'], name=op.f('earnings_company_id_fkey')),
    sa.PrimaryKeyConstraint('id', name=op.f('earnings_pkey'))
    )
    op.create_index(op.f('idx_earnings_company_code_quarter'), 'earnings', ['company_code', 'quarter'], unique=False)
    op.create_index(op.f('idx_earnings_company_code_date'), 'earnings', ['company_code', 'date'], unique=False)
    # ### end Alembic commands ###
