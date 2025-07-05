import datetime
import psycopg2

# Database connection parameters
DB_NAME = 'stockdb'
DB_USER = 'stockuser'
DB_HOST = 'localhost'
DB_PORT = '5432'

# Get current date and time in YYYYMMDD_HHMMSS format
backup_date = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
backup_table = f"prices_backup_historical_{backup_date}"

conn = psycopg2.connect(dbname=DB_NAME, user=DB_USER, host=DB_HOST, port=DB_PORT)
cur = conn.cursor()

cur.execute(f"""
    CREATE TABLE {backup_table} AS TABLE prices;
""")
conn.commit()
cur.close()
conn.close()
print(f"Backup table {backup_table} created.") 