"""
Database models for the Stock Market Data Dashboard.

Defines SQLAlchemy ORM models for:
- Company: Basic company and financial info.
- Fundamental: Yearly fundamental data for companies.
- Price: Daily price data for companies.
- CorporateAction: Corporate actions (splits, dividends, etc.).
- ShareholdingPattern: Shareholding pattern data.
- Index: Metadata for indices.
- IndexPrice: Daily price data for indices.

These models are used by both the backend API and data ingestion scripts.
"""

from sqlalchemy import Column, Integer, String, Numeric, Date, Text, ForeignKey, BigInteger
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.schema import Index

Base = declarative_base()

class Company(Base):
    """
    Represents a company listed on NSE/BSE with various financial and market attributes.
    """
    __tablename__ = 'companies'
    __table_args__ = (
        # Ensure nse_code and bse_code are unique if present (allowing NULLs)
        {'sqlite_autoincrement': True},
    )
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=True)
    bse_code = Column(String, nullable=True)
    nse_code = Column(String, nullable=True)
    industry = Column(String, nullable=True)
    current_price = Column(Numeric, nullable=True)
    market_capitalization = Column(Numeric, nullable=True)
    sales = Column(Numeric, nullable=True)
    sales_growth_3years = Column(Numeric, nullable=True)
    profit_after_tax = Column(Numeric, nullable=True)
    profit_growth_3years = Column(Numeric, nullable=True)
    profit_growth_5years = Column(Numeric, nullable=True)
    operating_profit = Column(Numeric, nullable=True)
    opm = Column(Numeric, nullable=True)
    eps_growth_3years = Column(Numeric, nullable=True)
    eps = Column(Numeric, nullable=True)
    return_on_capital_employed = Column(Numeric, nullable=True)
    other_income = Column(Numeric, nullable=True)
    change_in_promoter_holding_3years = Column(Numeric, nullable=True)
    expected_quarterly_sales = Column(Numeric, nullable=True)
    expected_quarterly_eps = Column(Numeric, nullable=True)
    expected_quarterly_net_profit = Column(Numeric, nullable=True)
    debt = Column(Numeric, nullable=True)
    equity_capital = Column(Numeric, nullable=True)
    preference_capital = Column(Numeric, nullable=True)
    reserves = Column(Numeric, nullable=True)
    contingent_liabilities = Column(Numeric, nullable=True)
    free_cash_flow_3years = Column(Numeric, nullable=True)
    operating_cash_flow_3years = Column(Numeric, nullable=True)
    price_to_earning = Column(Numeric, nullable=True)
    dividend_yield = Column(Numeric, nullable=True)
    price_to_book_value = Column(Numeric, nullable=True)
    return_on_assets = Column(Numeric, nullable=True)
    debt_to_equity = Column(Numeric, nullable=True)
    return_on_equity = Column(Numeric, nullable=True)
    promoter_holding = Column(Numeric, nullable=True)
    earnings_yield = Column(Numeric, nullable=True)
    pledged_percentage = Column(Numeric, nullable=True)
    number_of_equity_shares = Column(Numeric, nullable=True)
    book_value = Column(Numeric, nullable=True)
    inventory_turnover_ratio = Column(Numeric, nullable=True)
    exports_percentage = Column(Numeric, nullable=True)
    asset_turnover_ratio = Column(Numeric, nullable=True)
    financial_leverage = Column(Numeric, nullable=True)
    number_of_shareholders = Column(Numeric, nullable=True)
    working_capital_days = Column(Numeric, nullable=True)
    public_holding = Column(Numeric, nullable=True)
    fii_holding = Column(Numeric, nullable=True)
    change_in_fii_holding = Column(Numeric, nullable=True)
    dii_holding = Column(Numeric, nullable=True)
    change_in_dii_holding = Column(Numeric, nullable=True)
    cash_conversion_cycle = Column(Numeric, nullable=True)
    volume = Column(Numeric, nullable=True)
    volume_1week_average = Column(Numeric, nullable=True)
    volume_1month_average = Column(Numeric, nullable=True)
    high_price_all_time = Column(Numeric, nullable=True)
    low_price_all_time = Column(Numeric, nullable=True)
    volume_1year_average = Column(Numeric, nullable=True)
    return_over_1year = Column(Numeric, nullable=True)
    return_over_3months = Column(Numeric, nullable=True)
    return_over_6months = Column(Numeric, nullable=True)
    yf_not_found = Column(Integer, nullable=True, default=0)  # 0=False, 1=True
    listing_date = Column(Date, nullable=True)  # Date the company was listed on the exchange
    # yfinance info fields (all nullable, with _yf suffix)
    sector_yf = Column(String, nullable=True)
    industry_yf = Column(String, nullable=True)
    country_yf = Column(String, nullable=True)
    website_yf = Column(String, nullable=True)
    longBusinessSummary_yf = Column(Text, nullable=True)
    fullTimeEmployees_yf = Column(Integer, nullable=True)
    city_yf = Column(String, nullable=True)
    state_yf = Column(String, nullable=True)
    address1_yf = Column(String, nullable=True)
    zip_yf = Column(String, nullable=True)
    phone_yf = Column(String, nullable=True)
    marketCap_yf = Column(Numeric, nullable=True)
    sharesOutstanding_yf = Column(Numeric, nullable=True)
    logo_url_yf = Column(String, nullable=True)
    exchange_yf = Column(String, nullable=True)
    currency_yf = Column(String, nullable=True)
    financialCurrency_yf = Column(String, nullable=True)
    beta_yf = Column(Numeric, nullable=True)
    trailingPE_yf = Column(Numeric, nullable=True)
    forwardPE_yf = Column(Numeric, nullable=True)
    priceToBook_yf = Column(Numeric, nullable=True)
    bookValue_yf = Column(Numeric, nullable=True)
    payoutRatio_yf = Column(Numeric, nullable=True)
    ebitda_yf = Column(Numeric, nullable=True)
    revenueGrowth_yf = Column(Numeric, nullable=True)
    grossMargins_yf = Column(Numeric, nullable=True)
    operatingMargins_yf = Column(Numeric, nullable=True)
    profitMargins_yf = Column(Numeric, nullable=True)
    returnOnAssets_yf = Column(Numeric, nullable=True)
    returnOnEquity_yf = Column(Numeric, nullable=True)
    totalRevenue_yf = Column(Numeric, nullable=True)
    grossProfits_yf = Column(Numeric, nullable=True)
    freeCashflow_yf = Column(Numeric, nullable=True)
    operatingCashflow_yf = Column(Numeric, nullable=True)
    debtToEquity_yf = Column(Numeric, nullable=True)
    currentRatio_yf = Column(Numeric, nullable=True)
    quickRatio_yf = Column(Numeric, nullable=True)
    shortRatio_yf = Column(Numeric, nullable=True)
    pegRatio_yf = Column(Numeric, nullable=True)
    enterpriseValue_yf = Column(Numeric, nullable=True)
    enterpriseToRevenue_yf = Column(Numeric, nullable=True)
    enterpriseToEbitda_yf = Column(Numeric, nullable=True)
    exchange = Column(String, nullable=True)  # Store preferred exchange (NSE or BSE)
    last_modified = Column(Date, nullable=True)

# Add partial unique indexes for nse_code and bse_code (PostgreSQL only)
Index('unique_nse_code', Company.nse_code, unique=True, postgresql_where=Company.nse_code != None)
Index('unique_bse_code', Company.bse_code, unique=True, postgresql_where=Company.bse_code != None)

class Fundamental(Base):
    """
    Yearly fundamental data for a company (revenue, profit, EPS, etc.).
    """
    __tablename__ = 'fundamentals'
    id = Column(Integer, primary_key=True)
    company_id = Column(Integer, ForeignKey('companies.id'))
    year = Column(Integer)
    revenue = Column(Numeric)
    net_profit = Column(Numeric)
    eps = Column(Numeric)

class Price(Base):
    """
    Daily price data for a company (OHLCV).
    """
    __tablename__ = 'prices'
    id = Column(Integer, primary_key=True)
    company_id = Column(Integer, ForeignKey('companies.id'))
    company_code = Column(String, nullable=True)  # Unified code (NSE or BSE code)
    company_name = Column(String, nullable=True)  # Store company name for convenience
    date = Column(Date)
    open = Column(Numeric)
    high = Column(Numeric)
    low = Column(Numeric)
    close = Column(Numeric)
    volume = Column(BigInteger)
    adj_close = Column(Numeric, nullable=True)
    last_modified = Column(Date, nullable=True)

# Add index for fast lookups and upserts by (company_id, date)
Index('idx_prices_company_id_date', Price.company_id, Price.date)
# Add index for unified code approach
Index('idx_prices_company_code_date', Price.company_code, Price.date)

class CorporateAction(Base):
    """
    Corporate actions such as splits, dividends, etc.
    """
    __tablename__ = 'corporate_actions'
    id = Column(Integer, primary_key=True)
    company_id = Column(Integer, ForeignKey('companies.id'))
    company_code = Column(String, nullable=True)  # Unified code (NSE or BSE code)
    company_name = Column(String, nullable=True)  # Store company name for convenience
    date = Column(Date)
    type = Column(String)
    details = Column(Text)
    last_modified = Column(Date, nullable=True)

# Add index for unified code approach
Index('idx_corporate_actions_company_code_date', CorporateAction.company_code, CorporateAction.date)
Index('idx_corporate_actions_company_code_date_type', CorporateAction.company_code, CorporateAction.date, CorporateAction.type)

class FinancialStatement(Base):
    """
    Financial statements data (income statement, balance sheet, cash flow).
    """
    __tablename__ = 'financial_statements'
    id = Column(Integer, primary_key=True)
    company_id = Column(Integer, ForeignKey('companies.id'))
    company_code = Column(String, nullable=True)  # Unified code (NSE or BSE code)
    company_name = Column(String, nullable=True)  # Store company name for convenience
    date = Column(Date)  # Statement date
    statement_type = Column(String)  # 'income', 'balance', 'cashflow'
    period = Column(String, nullable=True)  # 'annual' or 'quarterly'
    year = Column(Integer, nullable=True)
    quarter = Column(Integer, nullable=True)  # 1, 2, 3, 4 for quarterly
    # Income Statement fields
    total_revenue = Column(Numeric, nullable=True)
    gross_profit = Column(Numeric, nullable=True)
    operating_income = Column(Numeric, nullable=True)
    net_income = Column(Numeric, nullable=True)
    eps = Column(Numeric, nullable=True)
    # Balance Sheet fields
    total_assets = Column(Numeric, nullable=True)
    total_liabilities = Column(Numeric, nullable=True)
    total_equity = Column(Numeric, nullable=True)
    cash_and_equivalents = Column(Numeric, nullable=True)
    total_debt = Column(Numeric, nullable=True)
    # Cash Flow fields
    operating_cash_flow = Column(Numeric, nullable=True)
    investing_cash_flow = Column(Numeric, nullable=True)
    financing_cash_flow = Column(Numeric, nullable=True)
    free_cash_flow = Column(Numeric, nullable=True)
    last_modified = Column(Date, nullable=True)

# Add indexes for new tables
Index('idx_financial_statements_company_code_date', FinancialStatement.company_code, FinancialStatement.date)
Index('idx_financial_statements_company_code_type', FinancialStatement.company_code, FinancialStatement.statement_type)

class AnalystRecommendation(Base):
    """
    Analyst recommendations and ratings.
    """
    __tablename__ = 'analyst_recommendations'
    id = Column(Integer, primary_key=True)
    company_id = Column(Integer, ForeignKey('companies.id'))
    company_code = Column(String, nullable=True)  # Unified code (NSE or BSE code)
    company_name = Column(String, nullable=True)  # Store company name for convenience
    date = Column(Date)  # Recommendation date
    firm = Column(String, nullable=True)  # Analyst firm name
    analyst = Column(String, nullable=True)  # Analyst name
    action = Column(String, nullable=True)  # 'upgrade', 'downgrade', 'initiate', 'maintain'
    from_rating = Column(String, nullable=True)  # Previous rating
    to_rating = Column(String, nullable=True)  # New rating
    price_target = Column(Numeric, nullable=True)  # Price target
    price_target_currency = Column(String, nullable=True)
    recommendation = Column(String, nullable=True)  # 'buy', 'sell', 'hold', 'strong_buy', 'strong_sell'
    last_modified = Column(Date, nullable=True)

# Add indexes for new tables
Index('idx_analyst_recommendations_company_code_date', AnalystRecommendation.company_code, AnalystRecommendation.date)
Index('idx_analyst_recommendations_company_code_firm', AnalystRecommendation.company_code, AnalystRecommendation.firm)

class MajorHolder(Base):
    """
    Major shareholders/holders data.
    """
    __tablename__ = 'major_holders'
    id = Column(Integer, primary_key=True)
    company_id = Column(Integer, ForeignKey('companies.id'))
    company_code = Column(String, nullable=True)  # Unified code (NSE or BSE code)
    company_name = Column(String, nullable=True)  # Store company name for convenience
    date = Column(Date)  # Data date
    holder_name = Column(String, nullable=True)  # Holder name
    holder_type = Column(String, nullable=True)  # 'individual', 'institution', 'promoter', 'fii', 'dii'
    shares_held = Column(BigInteger, nullable=True)  # Number of shares held
    percentage_held = Column(Numeric, nullable=True)  # Percentage of total shares
    value = Column(Numeric, nullable=True)  # Value of holdings
    currency = Column(String, nullable=True)
    last_modified = Column(Date, nullable=True)

# Add indexes for new tables
Index('idx_major_holders_company_code_date', MajorHolder.company_code, MajorHolder.date)
Index('idx_major_holders_company_code_holder', MajorHolder.company_code, MajorHolder.holder_name)

class InstitutionalHolder(Base):
    """
    Institutional holders data.
    """
    __tablename__ = 'institutional_holders'
    id = Column(Integer, primary_key=True)
    company_id = Column(Integer, ForeignKey('companies.id'))
    company_code = Column(String, nullable=True)  # Unified code (NSE or BSE code)
    company_name = Column(String, nullable=True)  # Store company name for convenience
    date = Column(Date)  # Data date
    institution_name = Column(String, nullable=True)  # Institution name
    institution_type = Column(String, nullable=True)  # 'mutual_fund', 'insurance', 'pension_fund', 'hedge_fund', etc.
    shares_held = Column(BigInteger, nullable=True)  # Number of shares held
    percentage_held = Column(Numeric, nullable=True)  # Percentage of total shares
    value = Column(Numeric, nullable=True)  # Value of holdings
    currency = Column(String, nullable=True)
    last_modified = Column(Date, nullable=True)

# Add indexes for new tables
Index('idx_institutional_holders_company_code_date', InstitutionalHolder.company_code, InstitutionalHolder.date)
Index('idx_institutional_holders_company_code_institution', InstitutionalHolder.company_code, InstitutionalHolder.institution_name)

class OptionsData(Base):
    """
    Options data for companies.
    """
    __tablename__ = 'options_data'
    id = Column(Integer, primary_key=True)
    company_id = Column(Integer, ForeignKey('companies.id'))
    company_code = Column(String, nullable=True)  # Unified code (NSE or BSE code)
    company_name = Column(String, nullable=True)  # Store company name for convenience
    date = Column(Date)  # Data date
    expiration_date = Column(Date, nullable=True)  # Option expiration date
    option_type = Column(String, nullable=True)  # 'call' or 'put'
    strike_price = Column(Numeric, nullable=True)  # Strike price
    last_price = Column(Numeric, nullable=True)  # Last traded price
    bid = Column(Numeric, nullable=True)  # Bid price
    ask = Column(Numeric, nullable=True)  # Ask price
    volume = Column(BigInteger, nullable=True)  # Trading volume
    open_interest = Column(BigInteger, nullable=True)  # Open interest
    implied_volatility = Column(Numeric, nullable=True)  # Implied volatility
    delta = Column(Numeric, nullable=True)  # Delta
    gamma = Column(Numeric, nullable=True)  # Gamma
    theta = Column(Numeric, nullable=True)  # Theta
    vega = Column(Numeric, nullable=True)  # Vega
    last_modified = Column(Date, nullable=True)

# Add indexes for new tables
Index('idx_options_data_company_code_date', OptionsData.company_code, OptionsData.date)
Index('idx_options_data_company_code_expiration', OptionsData.company_code, OptionsData.expiration_date)
Index('idx_options_data_company_code_strike', OptionsData.company_code, OptionsData.strike_price)

class ShareholdingPattern(Base):
    """
    Shareholding pattern for a company (promoters, FII, DII, public).
    """
    __tablename__ = 'shareholding_patterns'
    id = Column(Integer, primary_key=True)
    company_id = Column(Integer, ForeignKey('companies.id'))
    date = Column(Date)
    promoters = Column(Numeric)
    fii = Column(Numeric)
    dii = Column(Numeric)
    public = Column(Numeric)

class Index(Base):
    __tablename__ = 'indices'
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    ticker = Column(String, nullable=False, unique=True)
    region = Column(String, nullable=True)
    description = Column(Text, nullable=True)
    last_modified = Column(Date, nullable=True)

class IndexPrice(Base):
    __tablename__ = 'index_prices'
    id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)  # Index name (e.g., Nifty 50)
    ticker = Column(String, nullable=False)  # yfinance ticker (e.g., ^NSEI)
    region = Column(String, nullable=True)
    description = Column(Text, nullable=True)
    date = Column(Date, nullable=False)
    open = Column(Numeric, nullable=True)
    high = Column(Numeric, nullable=True)
    low = Column(Numeric, nullable=True)
    close = Column(Numeric, nullable=True)
    volume = Column(BigInteger, nullable=True)
    last_modified = Column(Date, nullable=True) 