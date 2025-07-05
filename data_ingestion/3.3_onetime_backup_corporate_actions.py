"""
Backup Corporate Actions Table Script

Simple backup script to create a timestamped backup of the corporate_actions table.
Run this after importing historical corporate actions for a complete backup.
"""

import psycopg2
from datetime import datetime

def backup_corporate_actions_table():
    """Create a timestamped backup of the corporate_actions table"""
    DB_NAME = 'stockdb'
    DB_USER = 'stockuser'
    DB_PASS = 'stockpass'
    DB_HOST = 'localhost'
    DB_PORT = '5432'

    conn = psycopg2.connect(dbname=DB_NAME, user=DB_USER, password=DB_PASS, host=DB_HOST, port=DB_PORT)
    cur = conn.cursor()
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_table = f"corporate_actions_backup_historical_{timestamp}"
    print(f"Creating backup table: {backup_table}")
    
    # Drop backup table if it already exists (safety check)
    cur.execute(f"DROP TABLE IF EXISTS {backup_table};")
    
    # Create backup table
    cur.execute(f"CREATE TABLE {backup_table} AS TABLE corporate_actions;")
    conn.commit()
    print(f"Backup complete: {backup_table}")
    cur.close()
    conn.close()

if __name__ == '__main__':
    backup_corporate_actions_table() 