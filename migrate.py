"""
Production-Ready Database Migration Script
Migrates data from SQL Server to PostgreSQL with comprehensive error handling,
validation, retry logic, and state tracking.
"""
import os
import sys
import logging
import time
import urllib.parse
from datetime import datetime
from typing import List, Dict, Any, Optional, Tuple
from contextlib import contextmanager

import pandas as pd
from sqlalchemy import create_engine, text, Engine
from sqlalchemy.exc import SQLAlchemyError
import uuid6

from config import config
from migration_tracker import MigrationTracker, MigrationStatus


# Configure logging
logging.basicConfig(
    level=getattr(logging, config.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(config.LOG_FILE) if config.LOG_FILE else logging.NullHandler()
    ]
)
logger = logging.getLogger(__name__)


class MigrationError(Exception):
    """Custom exception for migration errors"""
    pass


class DatabaseConnector:
    """Manages database connections with retry logic"""
    
    def __init__(self):
        self.source_engine: Optional[Engine] = None
        self.target_engine: Optional[Engine] = None
    
    def connect(self) -> Tuple[Engine, Engine]:
        """
        Establish database connections with retry logic
        
        Returns:
            Tuple of (source_engine, target_engine)
        """
        logger.info("Establishing database connections...")
        
        for attempt in range(config.MAX_RETRIES):
            try:
                # Source (SQL Server)
                mssql_password = urllib.parse.quote_plus(config.MSSQL_PASSWORD)
                source_uri = (
                    f"mssql+pymssql://{config.MSSQL_USER}:{mssql_password}"
                    f"@{config.MSSQL_HOST}:{config.MSSQL_PORT}/{config.MSSQL_DB}"
                    f"?timeout={config.CONNECTION_TIMEOUT}"
                )
                self.source_engine = create_engine(
                    source_uri,
                    pool_pre_ping=True,
                    pool_recycle=3600
                )
                
                # Target (PostgreSQL)
                postgres_password = urllib.parse.quote_plus(config.POSTGRES_PASSWORD)
                target_uri = (
                    f"postgresql+psycopg2://{config.POSTGRES_USER}:{postgres_password}"
                    f"@{config.POSTGRES_HOST}:{config.POSTGRES_PORT}/{config.POSTGRES_DB}"
                    f"?connect_timeout={config.CONNECTION_TIMEOUT}"
                )
                self.target_engine = create_engine(
                    target_uri,
                    pool_pre_ping=True,
                    pool_recycle=3600
                )
                
                # Test connections
                with self.source_engine.connect() as conn:
                    conn.execute(text("SELECT 1"))
                with self.target_engine.connect() as conn:
                    conn.execute(text("SELECT 1"))
                
                logger.info("Database connections established successfully")
                return self.source_engine, self.target_engine
                
            except SQLAlchemyError as e:
                logger.warning(f"Connection attempt {attempt + 1}/{config.MAX_RETRIES} failed: {e}")
                if attempt < config.MAX_RETRIES - 1:
                    time.sleep(config.RETRY_DELAY)
                else:
                    raise MigrationError(f"Failed to connect to databases after {config.MAX_RETRIES} attempts") from e
    
    def close(self):
        """Close database connections"""
        if self.source_engine:
            self.source_engine.dispose()
        if self.target_engine:
            self.target_engine.dispose()
        logger.info("Database connections closed")


class DataValidator:
    """Validates migrated data"""
    
    def __init__(self, source_engine: Engine, target_engine: Engine):
        self.source_engine = source_engine
        self.target_engine = target_engine
    
    def validate_row_count(self) -> bool:
        """
        Validate that row counts match between source and target
        
        Returns:
            True if counts match, False otherwise
        """
        try:
            with self.source_engine.connect() as conn:
                source_count = conn.execute(
                    text("SELECT COUNT(*) FROM tblReferralLevel")
                ).scalar()
            
            with self.target_engine.connect() as conn:
                target_count = conn.execute(
                    text("SELECT COUNT(*) FROM referral_levels")
                ).scalar()
            
            if source_count == target_count:
                logger.info(f"✓ Row count validation passed: {source_count} rows")
                return True
            else:
                logger.error(f"✗ Row count mismatch: source={source_count}, target={target_count}")
                return False
                
        except SQLAlchemyError as e:
            logger.error(f"Row count validation failed: {e}")
            return False
    
    def validate_data_integrity(self, sample_size: Optional[int] = None) -> bool:
        """
        Validate data integrity by comparing sample records
        
        Args:
            sample_size: Number of records to sample (None = all records)
            
        Returns:
            True if validation passes, False otherwise
        """
        try:
            sample_size = sample_size or config.VALIDATION_SAMPLE_SIZE
            
            # Get source data
            with self.source_engine.connect() as conn:
                source_df = pd.read_sql(
                    f"SELECT TOP {sample_size} ReferralLevelName FROM tblReferralLevel ORDER BY ReferralLevelID",
                    conn
                )
            
            # Get target data
            with self.target_engine.connect() as conn:
                target_df = pd.read_sql(
                    f"SELECT name FROM referral_levels ORDER BY display_order LIMIT {sample_size}",
                    conn
                )
            
            # Compare names
            source_names = set(source_df['ReferralLevelName'].tolist())
            target_names = set(target_df['name'].tolist())
            
            missing_in_target = source_names - target_names
            extra_in_target = target_names - source_names
            
            if missing_in_target:
                logger.error(f"✗ Records missing in target: {missing_in_target}")
                return False
            
            if extra_in_target:
                logger.warning(f"Extra records in target (may be from previous runs): {extra_in_target}")
            
            logger.info(f"✓ Data integrity validation passed for {len(source_names)} records")
            return True
            
        except SQLAlchemyError as e:
            logger.error(f"Data integrity validation failed: {e}")
            return False
    
    def validate_all(self) -> bool:
        """
        Run all validation checks
        
        Returns:
            True if all validations pass, False otherwise
        """
        logger.info("Running post-migration validation...")
        
        validations = [
            ("Row Count", self.validate_row_count()),
            ("Data Integrity", self.validate_data_integrity())
        ]
        
        all_passed = all(result for _, result in validations)
        
        if all_passed:
            logger.info("✓ All validation checks passed")
        else:
            failed = [name for name, result in validations if not result]
            logger.error(f"✗ Validation checks failed: {', '.join(failed)}")
        
        return all_passed


class ReferralLevelMigration:
    """Handles referral level data migration from SQL Server to PostgreSQL"""
    
    MIGRATION_NAME = "referral_levels_migration"
    
    def __init__(self, source_engine: Engine, target_engine: Engine):
        self.source_engine = source_engine
        self.target_engine = target_engine
        self.tracker = MigrationTracker(target_engine)
        self.validator = DataValidator(source_engine, target_engine)
    
    def _ensure_target_schema(self):
        """Ensure target schema exists"""
        logger.info("Ensuring target schema exists...")
        try:
            with self.target_engine.begin() as conn:
                # Create users table (dependency)
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS users (
                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                        email VARCHAR(255) UNIQUE NOT NULL
                    );
                """))
                
                # Create referral_levels table
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS referral_levels (
                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                        name VARCHAR(255) UNIQUE NOT NULL,
                        description VARCHAR(255) NULL,
                        display_order SMALLINT DEFAULT 1 NOT NULL,
                        is_active BOOLEAN DEFAULT TRUE NOT NULL,
                        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                        creator_user_id UUID NULL,
                        CONSTRAINT fk_creator_user FOREIGN KEY (creator_user_id) 
                            REFERENCES users(id) ON DELETE SET NULL
                    );
                """))
                
                logger.info("✓ Target schema verified")
        except SQLAlchemyError as e:
            raise MigrationError(f"Failed to ensure target schema: {e}") from e
    
    def _extract_data(self) -> pd.DataFrame:
        """
        Extract data from source database
        
        Returns:
            DataFrame with source data
        """
        logger.info("Extracting data from SQL Server...")
        try:
            query = "SELECT ReferralLevelID, ReferralLevelName FROM tblReferralLevel ORDER BY ReferralLevelID"
            df = pd.read_sql(query, self.source_engine)
            logger.info(f"✓ Extracted {len(df)} records from source")
            return df
        except SQLAlchemyError as e:
            raise MigrationError(f"Failed to extract data: {e}") from e
    
    def _transform_data(self, source_df: pd.DataFrame) -> List[Dict[str, Any]]:
        """
        Transform source data to target schema format
        
        Args:
            source_df: Source DataFrame
            
        Returns:
            List of transformed records
        """
        logger.info("Transforming data...")
        transformed_records = []
        current_time = datetime.utcnow()
        
        for idx, row in source_df.iterrows():
            transformed_records.append({
                'id': str(uuid6.uuid7()),
                'name': row['ReferralLevelName'],
                'description': None,
                'display_order': idx + 1,
                'is_active': True,
                'created_at': current_time,
                'updated_at': current_time,
                'creator_user_id': None
            })
        
        logger.info(f"✓ Transformed {len(transformed_records)} records")
        return transformed_records
    
    def _load_batch(self, records: List[Dict[str, Any]], dry_run: bool = False) -> Tuple[int, int]:
        """
        Load a batch of records into target database
        
        Args:
            records: List of records to insert
            dry_run: If True, don't actually insert
            
        Returns:
            Tuple of (success_count, failure_count)
        """
        success_count = 0
        failure_count = 0
        
        if dry_run:
            logger.info(f"[DRY RUN] Would insert {len(records)} records")
            return len(records), 0
        
        try:
            with self.target_engine.begin() as conn:
                for record in records:
                    try:
                        insert_stmt = text("""
                            INSERT INTO referral_levels 
                            (id, name, description, display_order, is_active, created_at, updated_at, creator_user_id)
                            VALUES (:id, :name, :description, :display_order, :is_active, :created_at, :updated_at, :creator_user_id)
                            ON CONFLICT (name) DO UPDATE SET
                                description = EXCLUDED.description,
                                display_order = EXCLUDED.display_order,
                                updated_at = EXCLUDED.updated_at;
                        """)
                        conn.execute(insert_stmt, record)
                        success_count += 1
                    except SQLAlchemyError as e:
                        logger.error(f"Failed to insert record {record.get('name')}: {e}")
                        failure_count += 1
                        if not config.CONTINUE_ON_ERROR:
                            raise
        except SQLAlchemyError as e:
            raise MigrationError(f"Batch load failed: {e}") from e
        
        return success_count, failure_count
    
    def _load_data_in_batches(self, records: List[Dict[str, Any]], dry_run: bool = False) -> Tuple[int, int]:
        """
        Load transformed data into target database in batches
        
        Args:
            records: List of all records to insert
            dry_run: If True, simulate without actual inserts
            
        Returns:
            Tuple of (total_success, total_failures)
        """
        total_records = len(records)
        total_success = 0
        total_failures = 0
        
        logger.info(f"Loading {total_records} records in batches of {config.BATCH_SIZE}...")
        
        for i in range(0, total_records, config.BATCH_SIZE):
            batch = records[i:i + config.BATCH_SIZE]
            batch_num = (i // config.BATCH_SIZE) + 1
            total_batches = (total_records + config.BATCH_SIZE - 1) // config.BATCH_SIZE
            
            logger.info(f"Processing batch {batch_num}/{total_batches} ({len(batch)} records)")
            
            success, failures = self._load_batch(batch, dry_run)
            total_success += success
            total_failures += failures
            
            if config.ENABLE_PROGRESS_TRACKING:
                progress = (i + len(batch)) / total_records * 100
                logger.info(f"Progress: {progress:.1f}% ({total_success} succeeded, {total_failures} failed)")
        
        return total_success, total_failures
    
    def run(self, dry_run: Optional[bool] = None) -> bool:
        """
        Execute the migration
        
        Args:
            dry_run: Override config dry_run setting
            
        Returns:
            True if migration succeeded, False otherwise
        """
        dry_run = dry_run if dry_run is not None else config.DRY_RUN
        batch_id = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        migration_id = None
        
        try:
            if dry_run:
                logger.info("=" * 70)
                logger.info("DRY RUN MODE - No data will be modified")
                logger.info("=" * 70)
            
            # Start tracking
            migration_id = self.tracker.start_migration(self.MIGRATION_NAME, batch_id)
            
            # Ensure target schema exists
            self._ensure_target_schema()
            
            # ETL Process
            source_df = self._extract_data()
            
            if source_df.empty:
                logger.warning("No data to migrate")
                self.tracker.complete_migration(migration_id, 0, 0)
                return True
            
            transformed_records = self._transform_data(source_df)
            success_count, failure_count = self._load_data_in_batches(transformed_records, dry_run)
            
            # Update progress
            self.tracker.update_progress(migration_id, success_count, failure_count)
            
            # Validation (skip in dry run)
            if not dry_run and not config.SKIP_VALIDATION:
                if not self.validator.validate_all():
                    raise MigrationError("Post-migration validation failed")
            
            # Complete
            self.tracker.complete_migration(migration_id, success_count, failure_count)
            
            logger.info("=" * 70)
            logger.info(f"✓ Migration completed successfully")
            logger.info(f"  Records processed: {success_count}")
            logger.info(f"  Records failed: {failure_count}")
            logger.info(f"  Batch ID: {batch_id}")
            logger.info("=" * 70)
            
            return failure_count == 0
            
        except Exception as e:
            logger.error(f"Migration failed: {e}", exc_info=True)
            if migration_id:
                self.tracker.fail_migration(migration_id, str(e))
            return False


def main():
    """Main entry point"""
    logger.info("Starting production migration process...")
    logger.info(f"Configuration: DRY_RUN={config.DRY_RUN}, BATCH_SIZE={config.BATCH_SIZE}")
    
    connector = DatabaseConnector()
    
    try:
        # Connect to databases
        source_engine, target_engine = connector.connect()
        
        # Run migration
        migration = ReferralLevelMigration(source_engine, target_engine)
        success = migration.run()
        
        # Exit with appropriate code
        sys.exit(0 if success else 1)
        
    except Exception as e:
        logger.critical(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)
    finally:
        connector.close()


if __name__ == "__main__":
    main()