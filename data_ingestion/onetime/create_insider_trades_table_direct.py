from sqlalchemy import create_engine, MetaData, Table, Column, String, Integer, Date, DateTime, Float, PrimaryKeyConstraint, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB

def create_insider_trades_table():
    # Create database connection
    engine = create_engine('postgresql://localhost/stockdb')
    metadata = MetaData()

    # Define the table
    insider_trades = Table('insidertrades', metadata,
        Column('symbol', String(20), nullable=False),
        Column('company', String(200), nullable=False),
        Column('regulation', String(200), nullable=False),
        Column('name_of_acquirer_disposer', String(200), nullable=False),
        Column('category_of_person', String(200), nullable=False),
        Column('security_type_prior', String(100), nullable=True),
        Column('security_quantity_prior', Integer, nullable=True),
        Column('security_percent_prior', Float, nullable=True),
        Column('security_type_acquired', String(100), nullable=True),
        Column('security_quantity_acquired', Integer, nullable=True),
        Column('security_value_acquired', Float, nullable=True),
        Column('transaction_type', String(100), nullable=True),
        Column('security_type_post', String(100), nullable=True),
        Column('security_quantity_post', Integer, nullable=True),
        Column('security_percent_post', Float, nullable=True),
        Column('date_from', Date, nullable=True),
        Column('date_to', Date, nullable=True),
        Column('date_of_intimation', Date, nullable=True),
        Column('mode_of_acquisition', String(200), nullable=True),
        Column('derivative_type', String(100), nullable=True),
        Column('derivative_specification', String(200), nullable=True),
        Column('notional_value_buy', Float, nullable=True),
        Column('contract_lot_size_buy', Integer, nullable=True),
        Column('notional_value_sell', Float, nullable=True),
        Column('contract_lot_size_sell', Integer, nullable=True),
        Column('exchange', String(100), nullable=True),
        Column('remark', String(500), nullable=True),
        Column('broadcast_date', Date, nullable=True),
        Column('broadcast_timestamp', DateTime, nullable=True),
        Column('last_modified', DateTime, nullable=False),
        Column('data', JSONB, nullable=False),
        UniqueConstraint('symbol', 'date_from', 'name_of_acquirer_disposer', 'transaction_type', 'mode_of_acquisition', 'regulation', 'broadcast_timestamp', 'security_quantity_acquired', 'security_value_acquired', name='uq_insidertrades_event')
    )

    # Create indexes
    indexes = [
        'CREATE INDEX idx_insidertrades_date_from ON insidertrades(date_from)',
        'CREATE INDEX idx_insidertrades_company ON insidertrades(company)',
        'CREATE INDEX idx_insidertrades_category ON insidertrades(category_of_person)'
    ]

    try:
        # Create the table
        metadata.create_all(engine, tables=[insider_trades])
        print("Table created successfully")

        # Create indexes using text()
        from sqlalchemy import text
        
        with engine.connect() as connection:
            for index_sql in indexes:
                connection.execute(text(index_sql))
        print("Indexes created successfully")

    except Exception as e:
        print(f"Error creating table: {str(e)}")

if __name__ == "__main__":
    create_insider_trades_table()
