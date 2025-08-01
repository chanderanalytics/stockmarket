
"""Add listing_date to Company

Revision ID: a28894364a81
Revises: 12938e42496f
Create Date: 2025-07-02 22:03:14.768814

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a28894364a81'
down_revision: Union[str, Sequence[str], None] = '12938e42496f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # ### commands auto generated by Alembic - please adjust! ###
    op.add_column('companies', sa.Column('listing_date', sa.Date(), nullable=True))
    # ### end Alembic commands ###


def downgrade() -> None:
    """Downgrade schema."""
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_column('companies', 'listing_date')
    # ### end Alembic commands ###
