"""
Script to add company_name_updated column to master bhavcopy CSV.
Uses issuer name from BSE sector mapping for both NSE and BSE exchanges.
"""

import pandas as pd
import os
import sys
import logging
from pathlib import Path
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('add_company_names.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def get_db_session():
    """Create and return a database session."""
    try:
        # Get database credentials from environment variables
        db_user = os.getenv('PGUSER', 'stockuser')
        db_password = os.getenv('PGPASSWORD', 'your_password')
        db_host = os.getenv('PGHOST', 'localhost')
        db_port = os.getenv('PGPORT', '5432')
        db_name = os.getenv('PGDATABASE', 'stockdb')
        
        DATABASE_URL = f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"
        engine = create_engine(DATABASE_URL)
        Session = sessionmaker(bind=engine)
        return Session()
    except Exception as e:
        logger.error(f"Error creating database session: {str(e)}")
        return None

def get_company_mapping():
    """Fetch company mapping (symbol to id) from the database."""
    session = get_db_session()
    if not session:
        return None, None, {}
        
    try:
        # First get company mappings
        query = """
            SELECT id, nse_code, bse_code, name 
            FROM companies
            WHERE nse_code IS NOT NULL OR bse_code IS NOT NULL
        """
        result = session.execute(text(query))
        
        # Create mapping dictionaries
        nse_mapping = {}  # NSE code -> company name
        bse_mapping = {}  # BSE code -> company name
        company_id_mapping = {}  # symbol -> company_id
        
        for row in result:
            if row.nse_code:
                nse_code = str(row.nse_code).strip()
                nse_mapping[nse_code] = row.name
                company_id_mapping[nse_code] = row.id
                
            if row.bse_code:
                # Handle both string and numeric BSE codes
                bse_code = str(row.bse_code).replace('.0', '').strip()
                bse_mapping[bse_code] = row.name
                company_id_mapping[bse_code] = row.id
        
        logger.info(f"Loaded {len(nse_mapping)} NSE mappings and {len(bse_mapping)} BSE mappings")
        return nse_mapping, bse_mapping, company_id_mapping
        
    except Exception as e:
        logger.error(f"Error fetching company mapping: {str(e)}")
        return None, None, {}
    finally:
        if session:
            session.close()

def load_bse_mapping(mapping_file):
    """Load BSE sector mapping and create lookup dictionaries."""
    try:
        logger.info(f"Loading BSE sector mapping from: {mapping_file}")
        df_mapping = pd.read_csv(mapping_file)
        
        # Create mapping dictionaries
        # For NSE: Security Id -> Issuer Name
        nse_mapping = dict(zip(df_mapping['Security Id'], df_mapping['Issuer Name']))
        
        # For BSE: Security Code -> Issuer Name (convert to string for matching)
        bse_mapping = dict(zip(df_mapping['Security Code'].astype(str), df_mapping['Issuer Name']))
        
        # Also load company IDs from database
        nse_map, bse_map, company_id_map = get_company_mapping()
        
        if nse_map and bse_map:
            # Update with database mappings if available
            nse_mapping.update(nse_map)
            bse_mapping.update(bse_map)
        
        logger.info(f"Loaded {len(nse_mapping)} NSE mappings and {len(bse_mapping)} BSE mappings")
        return nse_mapping, bse_mapping, company_id_map
        
    except Exception as e:
        logger.error(f"Error loading BSE mapping file: {str(e)}")
        return None, None, {}

def add_company_names(input_file, output_file, mapping_file):
    """Add company_name_updated and company_id columns to master bhavcopy CSV."""
    try:
        logger.info(f"Processing master bhavcopy file: {input_file}")
        
        # Load BSE sector mapping and company IDs
        nse_mapping, bse_mapping, company_id_mapping = load_bse_mapping(mapping_file)
        if nse_mapping is None or bse_mapping is None:
            return False
        
        # Read master bhavcopy CSV in chunks to handle large file
        chunk_size = 100000  # Process 100k rows at a time
        chunks = []
        total_rows = 0
        matched_nse = 0
        matched_bse = 0
        
        logger.info("Reading master bhavcopy file in chunks...")
        
        for chunk in pd.read_csv(input_file, chunksize=chunk_size):
            total_rows += len(chunk)
            logger.info(f"Processing chunk with {len(chunk)} rows...")
            
            # Add company_name_updated and company_id columns
            company_names = []
            company_ids = []
            
            for idx, row in chunk.iterrows():
                symbol = str(row['symbol']).strip()
                exchange = row['exchange']
                
                # Default values
                company_name = symbol
                company_id = None
                
                if exchange == 'NSE':
                    # For NSE: try to match Security Id with Issuer Name
                    if symbol in nse_mapping:
                        company_name = nse_mapping[symbol]
                        matched_nse += 1
                    # Get company ID if available
                    company_id = company_id_mapping.get(symbol)
                        
                elif exchange == 'BSE':
                    # For BSE: try to match Security Code with Issuer Name
                    if symbol in bse_mapping:
                        company_name = bse_mapping[symbol]
                        matched_bse += 1
                    # Get company ID if available
                    company_id = company_id_mapping.get(symbol)
                
                company_names.append(company_name)
                company_ids.append(company_id)
            
            # Add the new columns to the chunk
            chunk['company_name_updated'] = company_names
            chunk['company_id'] = company_ids
            chunks.append(chunk)
            
            logger.info(f"Processed chunk. Total rows so far: {total_rows}")
        
        # Combine all chunks
        logger.info("Combining all chunks...")
        master_df = pd.concat(chunks, ignore_index=True)
        
        # Save to output file
        logger.info(f"Saving to output file: {output_file}")
        master_df.to_csv(output_file, index=False)
        
        # Calculate company ID matching stats
        matched_ids = sum(1 for x in master_df['company_id'] if pd.notna(x))
        match_rate = (matched_ids / total_rows) * 100 if total_rows > 0 else 0
        
        # Log summary
        logger.info("\n" + "="*50)
        logger.info("Processing Summary:")
        logger.info(f"Total rows processed: {total_rows:,}")
        logger.info(f"NSE matches found: {matched_nse:,}")
        logger.info(f"BSE matches found: {matched_bse:,}")
        logger.info(f"Company ID matches: {matched_ids:,} ({match_rate:.2f}%)")
        logger.info(f"Total name matches: {matched_nse + matched_bse:,}")
        logger.info(f"Name match rate: {((matched_nse + matched_bse) / total_rows * 100):.2f}%")
        logger.info("="*50)
        
        return True
        
    except Exception as e:
        logger.error(f"Error processing file: {str(e)}", exc_info=True)
        return False

def main():
    """Main function to run the script."""
    # Default paths
    project_root = Path(__file__).parent
    default_input = project_root / 'data' / 'master_bhavcopy.csv'
    default_output = project_root / 'data' / 'master_bhavcopy_with_names.csv'
    default_mapping = project_root / 'data' / 'BSE_Sector_Mapping.csv'
    
    # Get command line arguments
    if len(sys.argv) > 1:
        input_file = sys.argv[1]
    else:
        input_file = str(default_input)
    
    if len(sys.argv) > 2:
        output_file = sys.argv[2]
    else:
        output_file = str(default_output)
    
    if len(sys.argv) > 3:
        mapping_file = sys.argv[3]
    else:
        mapping_file = str(default_mapping)
    
    # Check if input files exist
    if not os.path.exists(input_file):
        logger.error(f"Input file not found: {input_file}")
        sys.exit(1)
    
    if not os.path.exists(mapping_file):
        logger.error(f"Mapping file not found: {mapping_file}")
        sys.exit(1)
    
    # Create output directory if it doesn't exist
    os.makedirs(os.path.dirname(os.path.abspath(output_file)), exist_ok=True)
    
    # Process the file
    success = add_company_names(input_file, output_file, mapping_file)
    
    if success:
        logger.info(f"Successfully created file with company names: {output_file}")
        sys.exit(0)
    else:
        logger.error("Failed to process file. Check the log for details.")
        sys.exit(1)

if __name__ == "__main__":
    main()
