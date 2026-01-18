"""
Connects to your financial database and retrieves data for a given company.
Uses SQLAlchemy for database connections.
"""

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
import pandas as pd
import yaml
import os

def get_db_engine():
    """Create and return a SQLAlchemy engine using the configuration."""
    with open("config/settings.yaml", "r") as f:
        cfg = yaml.safe_load(f)
    
    db_config = cfg["database"]
    db_url = f"postgresql://{db_config['user']}:{db_config['password']}@{db_config['host']}:{db_config['port']}/{db_config['name']}"
    return create_engine(db_url)

def get_company_identifiers(company_name: str):
    """
    Fetch NSE symbol and BSE code for a given company from your database.
    
    Args:
        company_name: Name of the company to look up
        
    Returns:
        dict: Dictionary containing 'nse_symbol' and 'bse_code'
        
    Note:
        - BSE code is formatted as a 6-digit string with leading zeros
        - NSE symbol is returned as-is from the database
    """
    engine = get_db_engine()
    query = text("""
        SELECT nse_code, bse_code::text
        FROM merged_price_baseline_probabilities_wide
        WHERE LOWER(name) = LOWER(:company_name)
        LIMIT 1;
    """)
    with engine.connect() as conn:
        result = conn.execute(query, {"company_name": company_name}).fetchone()
        if not result:
            raise ValueError(f"No NSE/BSE code found for {company_name}")
            
        nse_symbol, bse_code = result
        
        # Ensure BSE code is a 6-digit string with leading zeros
        if bse_code is not None:
            bse_code = str(bse_code).strip()
            # Pad with leading zeros if needed
            bse_code = bse_code.zfill(6)
        
        return {
            "nse_symbol": nse_symbol.strip().upper() if nse_symbol else None,
            "bse_code": bse_code
        }

def get_available_companies() -> list[str]:
    """
    Fetch a list of all available company names from the database.
    
    Returns:
        list[str]: Sorted list of unique company names
    """
    engine = get_db_engine()
    Session = sessionmaker(bind=engine)
    session = Session()
    
    try:
        query = text("""
            SELECT DISTINCT name
            FROM merged_price_baseline_probabilities_wide
            WHERE name IS NOT NULL
            ORDER BY name;
        """)
        
        result = session.execute(query)
        return [row[0] for row in result if row[0]]
        
    except Exception as e:
        print(f"Error fetching company list: {e}")
        return []
    finally:
        session.close()

def get_company_financials(company_name: str) -> pd.DataFrame:
    """
    Fetch all available metrics for a company from the merged_price_baseline_probabilities_wide table.
    
    Args:
        company_name: Name of the company to fetch data for
        
    Returns:
        pd.DataFrame: DataFrame containing all available metrics for the company
        
    Raises:
        ValueError: If no data is found for the company
        sqlalchemy.exc.SQLAlchemyError: For database-related errors
    """
    engine = get_db_engine()
    Session = sessionmaker(bind=engine)
    session = Session()
    
    try:
        # First verify the company exists
        company_query = text("""
            SELECT DISTINCT name
            FROM merged_price_baseline_probabilities_wide
            WHERE name = :company_name
            LIMIT 1;
        """)
        
        company = session.execute(
            company_query,
            {"company_name": company_name}
        ).scalar()
        
        if not company:
            raise ValueError(f"No company found with name: {company_name}")
            
        print(f"\n📊 Fetching data for {company_name}...")
        
        # Fetch the financial data
        query = text("""
            SELECT *
            FROM merged_price_baseline_probabilities_wide
            WHERE name = :company_name
        """)
        
        df = pd.read_sql_query(
            query, 
            session.connection(), 
            params={"company_name": company_name}
        )
        
        if df.empty:
            raise ValueError(f"No data found for company: {company_name}")
            
        # Add company name to the dataframe for display
        df['company_name'] = company_name
            
        return df
        
    except Exception as e:
        # Re-raise the exception to be handled by the caller
        raise
    finally:
        # Ensure the session is always closed
        session.close()
