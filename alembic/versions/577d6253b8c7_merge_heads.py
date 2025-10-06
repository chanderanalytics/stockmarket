
"""merge heads

Revision ID: 577d6253b8c7
Revises: 20250909_2232, 4d6baaf7b96b
Create Date: 2025-09-09 23:32:13.087619

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '577d6253b8c7'
down_revision: Union[str, Sequence[str], None] = ('20250909_2232', '4d6baaf7b96b')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    pass


def downgrade() -> None:
    """Downgrade schema."""
    pass
