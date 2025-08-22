import csv
import json
import argparse
import os
from datetime import datetime, date
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

def process_date(date_str):
    if not date_str or date_str.lower() == 'nan':
        return None
    for fmt in ('%d-%b-%Y', '%d-%b-%Y %H:%M', '%Y-%m-%d %H:%M:%S'):
        try:
            return datetime.strptime(date_str, fmt).date()
        except ValueError:
            continue
    print(f"Warning: Could not parse date '{date_str}'")
    return None

def process_datetime(dt_str):
    if not dt_str or isinstance(dt_str, float):
        return None
    for fmt in ('%d-%b-%Y %H:%M', '%d-%b-%Y %H:%M:%S', '%Y-%m-%d %H:%M:%S'):
        try:
            return datetime.strptime(dt_str, fmt)
        except ValueError:
            continue
    # fallback: try date only
    for fmt in ('%d-%b-%Y', '%Y-%m-%d'):
        try:
            d = datetime.strptime(dt_str, fmt)
            return d
        except ValueError:
            continue
    print(f"Warning: Could not parse datetime '{dt_str}'")
    return None

def safe_int(value):
    try:
        return int(value)
    except (ValueError, TypeError):
        return None

def safe_float(value):
    try:
        return float(value)
    except (ValueError, TypeError):
        return None

def import_insider_trades_incremental(csv_path, max_rows=None):
    """
    Imports insider trades data from a CSV file into the database,
    incrementally updating existing records.
    """
    print(f"Executing import_insider_trades_incremental for {csv_path}...")
    session = None
    try:
        print("Attempting to connect to the database...")
        engine = create_engine('postgresql://localhost/stockdb', connect_args={'connect_timeout': 10})
        Session = sessionmaker(bind=engine)
        session = Session()
        print("Database session created successfully.")
        with open(csv_path, 'r', encoding='utf-8-sig') as csvfile:
            print("CSV file opened successfully.")
            reader = csv.reader(csvfile)
            original_headers = [h.strip().replace('"', '') for h in next(reader)]
            print(f"Parsed headers: {original_headers}")

            insert_stmt = text("""
            INSERT INTO insidertrades (symbol, company, regulation, name_of_acquirer_disposer, 
                                     category_of_person, security_type_prior, security_quantity_prior, 
                                     security_percent_prior, security_type_acquired, security_quantity_acquired,
                                     security_value_acquired, transaction_type, security_type_post, 
                                     security_quantity_post, security_percent_post, date_from, date_to,
                                     date_of_intimation, mode_of_acquisition, derivative_type,
                                     derivative_specification, notional_value_buy, contract_lot_size_buy,
                                     notional_value_sell, contract_lot_size_sell, exchange, remark,
                                     broadcast_date, broadcast_timestamp, last_modified, data)
            VALUES (:symbol, :company, :regulation, :name_of_acquirer_disposer, 
                   :category_of_person, :security_type_prior, :security_quantity_prior, 
                   :security_percent_prior, :security_type_acquired, :security_quantity_acquired,
                   :security_value_acquired, :transaction_type, :security_type_post, 
                   :security_quantity_post, :security_percent_post, :date_from, :date_to,
                   :date_of_intimation, :mode_of_acquisition, :derivative_type,
                   :derivative_specification, :notional_value_buy, :contract_lot_size_buy,
                   :notional_value_sell, :contract_lot_size_sell, :exchange, :remark,
                   :broadcast_date, :broadcast_timestamp, :last_modified, :data)
            ON CONFLICT ON CONSTRAINT uq_insidertrades_event
            DO UPDATE SET 
                company = EXCLUDED.company,
                regulation = EXCLUDED.regulation,
                name_of_acquirer_disposer = EXCLUDED.name_of_acquirer_disposer,
                category_of_person = EXCLUDED.category_of_person,
                security_type_prior = EXCLUDED.security_type_prior,
                security_quantity_prior = EXCLUDED.security_quantity_prior,
                security_percent_prior = EXCLUDED.security_percent_prior,
                security_type_acquired = EXCLUDED.security_type_acquired,
                security_quantity_acquired = EXCLUDED.security_quantity_acquired,
                security_value_acquired = EXCLUDED.security_value_acquired,
                transaction_type = EXCLUDED.transaction_type,
                security_type_post = EXCLUDED.security_type_post,
                security_quantity_post = EXCLUDED.security_quantity_post,
                security_percent_post = EXCLUDED.security_percent_post,
                date_from = EXCLUDED.date_from,
                date_to = EXCLUDED.date_to,
                date_of_intimation = EXCLUDED.date_of_intimation,
                mode_of_acquisition = EXCLUDED.mode_of_acquisition,
                derivative_type = EXCLUDED.derivative_type,
                derivative_specification = EXCLUDED.derivative_specification,
                notional_value_buy = EXCLUDED.notional_value_buy,
                contract_lot_size_buy = EXCLUDED.contract_lot_size_buy,
                notional_value_sell = EXCLUDED.notional_value_sell,
                contract_lot_size_sell = EXCLUDED.contract_lot_size_sell,
                exchange = EXCLUDED.exchange,
                remark = EXCLUDED.remark,
                broadcast_date = EXCLUDED.broadcast_date,
                broadcast_timestamp = EXCLUDED.broadcast_timestamp,
                last_modified = EXCLUDED.last_modified,
                data = EXCLUDED.data
            """)

            processed_rows = 0
            for i, row_values in enumerate(reader):
                if max_rows and i >= max_rows:
                    print(f"Reached max rows limit of {max_rows}. Stopping import.")
                    break
                if len(row_values) != len(original_headers):
                    print(f"Skipping malformed row {i + 1}: Expected {len(original_headers)} columns, but got {len(row_values)}. Row data: {row_values}")
                    continue
                row = dict(zip(original_headers, row_values))

                processed_rows += 1
                print(f"Processing row {i + 1}...")
                try:
                    # Strip whitespace from all values
                    cleaned_row = {k: v.strip() if isinstance(v, str) else v for k, v in row.items()}

                    # Parse broadcast datetime and derive broadcast_date
                    broadcast_dt = process_datetime(cleaned_row.get('BROADCASTE DATE AND TIME'))
                    params = {
                        'symbol': cleaned_row.get('SYMBOL'),
                        'company': cleaned_row.get('COMPANY'),
                        'regulation': cleaned_row.get('REGULATION'),
                        'name_of_acquirer_disposer': cleaned_row.get('NAME OF THE ACQUIRER/DISPOSER'),
                        'category_of_person': cleaned_row.get('CATEGORY OF PERSON'),
                        'security_type_prior': cleaned_row.get('TYPE OF SECURITY (PRIOR)'),
                        'security_quantity_prior': safe_int(cleaned_row.get('NO. OF SECURITY (PRIOR)')),
                        'security_percent_prior': safe_float(cleaned_row.get('% SHAREHOLDING (PRIOR)')),
                        'security_type_acquired': cleaned_row.get('TYPE OF SECURITY (ACQUIRED/DISPLOSED)'),
                        'security_quantity_acquired': safe_int(cleaned_row.get('NO. OF SECURITIES (ACQUIRED/DISPLOSED)')),
                        'security_value_acquired': safe_float(cleaned_row.get('VALUE OF SECURITY (ACQUIRED/DISPLOSED)')),
                        'transaction_type': cleaned_row.get('ACQUISITION/DISPOSAL TRANSACTION TYPE'),
                        'security_type_post': cleaned_row.get('TYPE OF SECURITY (POST)'),
                        'security_quantity_post': safe_int(cleaned_row.get('NO. OF SECURITY (POST)')),
                        'security_percent_post': safe_float(cleaned_row.get('% POST')),
                        'date_from': process_date(cleaned_row.get('DATE OF ALLOTMENT/ACQUISITION FROM')),
                        'date_to': process_date(cleaned_row.get('DATE OF ALLOTMENT/ACQUISITION TO')),
                        'date_of_intimation': process_date(cleaned_row.get('DATE OF INITMATION TO COMPANY')),
                        'mode_of_acquisition': cleaned_row.get('MODE OF ACQUISITION'),
                        'derivative_type': cleaned_row.get('DERIVATIVE TYPE SECURITY'),
                        'derivative_specification': cleaned_row.get('DERIVATIVE CONTRACT SPECIFICATION'),
                        'notional_value_buy': safe_float(cleaned_row.get('NOTIONAL VALUE(BUY)')),
                        'contract_lot_size_buy': safe_int(cleaned_row.get('NUMBER OF UNITS/CONTRACT LOT SIZE (BUY)')),
                        'notional_value_sell': safe_float(cleaned_row.get('NOTIONAL VALUE(SELL)')),
                        'contract_lot_size_sell': safe_int(cleaned_row.get('NUMBER OF UNITS/CONTRACT LOT SIZE  (SELL)')),
                        'exchange': cleaned_row.get('EXCHANGE'),
                        'remark': cleaned_row.get('REMARK'),
                        'broadcast_date': broadcast_dt.date() if broadcast_dt else None,
                        'broadcast_timestamp': broadcast_dt,
                        'last_modified': datetime.now()
                    }
                    
                    # Prepare data for JSON column, converting non-serializable types
                    data_for_json = params.copy()
                    for key, value in data_for_json.items():
                        if isinstance(value, date):
                            data_for_json[key] = value.isoformat()
                    params['data'] = json.dumps(data_for_json)

                    session.execute(insert_stmt, params)

                    if (i + 1) % 1000 == 0:
                        session.commit()
                        print(f"Committed 1000 rows. Total processed: {i + 1}")

                except Exception as e:
                    print(f"Error processing row {i + 1}: {row}. Error: {e}")
                    session.rollback()
                    continue
            
            print(f"Total rows processed from CSV: {processed_rows}")
            session.commit()
            print("Final commit successful.")

    except Exception as e:
        print(f"An error occurred: {e}")
        if session:
            session.rollback()
    finally:
        if session:
            session.close()
            print("Database session closed.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Import insider trades CSV into PostgreSQL (idempotent upsert).")
    parser.add_argument("csv_path", help="Path to insider trades CSV file to import")
    parser.add_argument("--max-rows", type=int, default=None, help="Optional limit of rows to process (for testing)")
    args = parser.parse_args()

    if not os.path.isfile(args.csv_path):
        raise SystemExit(f"CSV file not found: {args.csv_path}")

    import_insider_trades_incremental(args.csv_path, max_rows=args.max_rows)
