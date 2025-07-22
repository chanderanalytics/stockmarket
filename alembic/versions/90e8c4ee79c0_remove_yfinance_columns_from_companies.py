
"""remove yfinance columns from companies

Revision ID: 90e8c4ee79c0
Revises: de904ac0b6a4
Create Date: 2025-07-22 00:12:01.321434

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '90e8c4ee79c0'
down_revision: Union[str, Sequence[str], None] = 'de904ac0b6a4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.drop_column('companies', 'sector_yf')
    op.drop_column('companies', 'industry_yf')
    op.drop_column('companies', 'country_yf')
    op.drop_column('companies', 'website_yf')
    op.drop_column('companies', 'longBusinessSummary_yf')
    op.drop_column('companies', 'fullTimeEmployees_yf')
    op.drop_column('companies', 'city_yf')
    op.drop_column('companies', 'state_yf')
    op.drop_column('companies', 'address1_yf')
    op.drop_column('companies', 'zip_yf')
    op.drop_column('companies', 'phone_yf')
    op.drop_column('companies', 'marketCap_yf')
    op.drop_column('companies', 'sharesOutstanding_yf')
    op.drop_column('companies', 'logo_url_yf')
    op.drop_column('companies', 'exchange_yf')
    op.drop_column('companies', 'currency_yf')
    op.drop_column('companies', 'financialCurrency_yf')
    op.drop_column('companies', 'beta_yf')
    op.drop_column('companies', 'trailingPE_yf')
    op.drop_column('companies', 'forwardPE_yf')
    op.drop_column('companies', 'priceToBook_yf')
    op.drop_column('companies', 'bookValue_yf')
    op.drop_column('companies', 'payoutRatio_yf')
    op.drop_column('companies', 'ebitda_yf')
    op.drop_column('companies', 'revenueGrowth_yf')
    op.drop_column('companies', 'grossMargins_yf')
    op.drop_column('companies', 'operatingMargins_yf')
    op.drop_column('companies', 'profitMargins_yf')
    op.drop_column('companies', 'returnOnAssets_yf')
    op.drop_column('companies', 'returnOnEquity_yf')
    op.drop_column('companies', 'totalRevenue_yf')
    op.drop_column('companies', 'grossProfits_yf')
    op.drop_column('companies', 'freeCashflow_yf')
    op.drop_column('companies', 'operatingCashflow_yf')
    op.drop_column('companies', 'debtToEquity_yf')
    op.drop_column('companies', 'currentRatio_yf')
    op.drop_column('companies', 'quickRatio_yf')
    op.drop_column('companies', 'shortRatio_yf')
    op.drop_column('companies', 'pegRatio_yf')
    op.drop_column('companies', 'enterpriseValue_yf')
    op.drop_column('companies', 'enterpriseToRevenue_yf')
    op.drop_column('companies', 'enterpriseToEbitda_yf')


def downgrade() -> None:
    """Downgrade schema."""
    # Columns removed, downgrade not implemented
    pass
