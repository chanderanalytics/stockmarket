"""
Daily Backup Prices Table Script

Simple backup script to create a daily backup of the prices table.
This creates a backup table with today's date and removes old daily backups.
"""

import psycopg2
from datetime import datetime

def backup_prices_table():
    """Create a daily backup of the prices table"""
    DB_NAME = 'stockdb'
    DB_USER = 'stockuser'
    DB_PASS = 'stockpass'
    DB_HOST = 'localhost'
    DB_PORT = '5432'

    conn = psycopg2.connect(dbname=DB_NAME, user=DB_USER, password=DB_PASS, host=DB_HOST, port=DB_PORT)
    cur = conn.cursor()
    
    # Get today's date in YYYYMMDD format
    today = datetime.now().strftime('%Y%m%d')
    backup_table = f"prices_daily_{today}"
    print(f"Creating backup table: {backup_table}")
    
    # Drop backup table if it already exists (safety check)
    cur.execute(f"DROP TABLE IF EXISTS {backup_table};")
    
    # Create backup table
    cur.execute(f"CREATE TABLE {backup_table} AS TABLE prices;")
    
    # Remove old daily backup tables (keep only today's)
    cur.execute(f"""
        SELECT tablename 
        FROM pg_tables 
        WHERE tablename LIKE 'prices_daily_%' 
        AND tablename != '{backup_table}'
    """)
    
    old_backups = cur.fetchall()
    for old_backup in old_backups:
        old_table = old_backup[0]
        print(f"Dropping old backup table: {old_table}")
        cur.execute(f"DROP TABLE IF EXISTS {old_table} CASCADE;")
    
    conn.commit()
    print(f"Backup complete: {backup_table}")
    cur.close()
    conn.close()

if __name__ == '__main__':
    backup_prices_table() 