"""
Database Seeding Script
Initializes SQL Server with demo data for testing purposes.
Separate from production migration logic.
"""
import os
import sys
import logging
import urllib.parse
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError

from config import config


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def seed_sql_server():
    """Initialize SQL Server database with demo data"""
    logger.info("Starting SQL Server seeding process...")
    
    try:
        # Connect to master database first
        mssql_password = urllib.parse.quote_plus(config.MSSQL_PASSWORD)
        master_uri = f"mssql+pymssql://{config.MSSQL_USER}:{mssql_password}@{config.MSSQL_HOST}/master"
        master_engine = create_engine(master_uri)
        
        # 1. Create user database if it doesn't exist
        with master_engine.execution_options(isolation_level="AUTOCOMMIT").connect() as conn:
            db_exists = conn.execute(text(f"SELECT DB_ID('{config.MSSQL_DB}')")).scalar()
            
            if not db_exists:
                logger.info(f"Creating database '{config.MSSQL_DB}'...")
                conn.execute(text(f"CREATE DATABASE {config.MSSQL_DB}"))
                logger.info(f"✓ Database '{config.MSSQL_DB}' created")
            else:
                logger.info(f"Database '{config.MSSQL_DB}' already exists")
        
        # 2. Connect to user database
        user_db_uri = f"mssql+pymssql://{config.MSSQL_USER}:{mssql_password}@{config.MSSQL_HOST}/{config.MSSQL_DB}"
        user_db_engine = create_engine(user_db_uri)
        
        # 3. Create table if it doesn't exist
        with user_db_engine.begin() as conn:
            conn.execute(text("""
                IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='tblReferralLevel' and xtype='U')
                BEGIN
                    CREATE TABLE tblReferralLevel (
                        ReferralLevelID INT IDENTITY(1,1) CONSTRAINT PK_tblReferralLevel PRIMARY KEY,
                        ReferralLevelName VARCHAR(100) NOT NULL
                    )
                END
            """))
            logger.info("✓ Table 'tblReferralLevel' verified")
            
            # 4. Check if table has data
            has_data = conn.execute(text("SELECT COUNT(1) FROM tblReferralLevel")).scalar()
            
            if has_data == 0:
                logger.info("Table is empty. Inserting demo records...")
                conn.execute(text("""
                    INSERT INTO tblReferralLevel (ReferralLevelName) VALUES 
                    ('Bronze'), 
                    ('Silver'), 
                    ('Gold'), 
                    ('Platinum'), 
                    ('Diamond');
                """))
                logger.info("✓ Demo data inserted: 5 referral levels")
            else:
                logger.info(f"Table already contains {has_data} records. Skipping seed.")
        
        logger.info("=" * 70)
        logger.info("✓ SQL Server seeding completed successfully")
        logger.info("=" * 70)
        
        # Cleanup
        master_engine.dispose()
        user_db_engine.dispose()
        
        return True
        
    except SQLAlchemyError as e:
        logger.error(f"Seeding failed: {e}", exc_info=True)
        return False


def main():
    """Main entry point"""
    success = seed_sql_server()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
