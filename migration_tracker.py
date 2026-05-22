"""
Migration State Tracking Module
Handles migration history, state management, and idempotency
"""
import logging
from datetime import datetime
from enum import Enum
from typing import Optional, Dict, Any
from sqlalchemy import create_engine, text, Engine
from sqlalchemy.exc import SQLAlchemyError


logger = logging.getLogger(__name__)


class MigrationStatus(Enum):
    """Migration execution status"""
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"
    ROLLED_BACK = "rolled_back"


class MigrationTracker:
    """Tracks migration execution state and history"""
    
    def __init__(self, pg_engine: Engine):
        """
        Initialize migration tracker
        
        Args:
            pg_engine: PostgreSQL SQLAlchemy engine
        """
        self.pg_engine = pg_engine
        self._ensure_tracking_table()
    
    def _ensure_tracking_table(self):
        """Create migration tracking table if it doesn't exist"""
        try:
            with self.pg_engine.begin() as conn:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS migration_log (
                        id SERIAL PRIMARY KEY,
                        migration_name VARCHAR(255) NOT NULL,
                        batch_id VARCHAR(100) NOT NULL,
                        status VARCHAR(50) NOT NULL,
                        records_processed INTEGER DEFAULT 0,
                        records_failed INTEGER DEFAULT 0,
                        error_message TEXT NULL,
                        started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                        completed_at TIMESTAMP WITH TIME ZONE NULL,
                        metadata JSONB NULL,
                        UNIQUE(migration_name, batch_id)
                    );
                """))
                
                # Create index for faster lookups
                conn.execute(text("""
                    CREATE INDEX IF NOT EXISTS idx_migration_log_status 
                    ON migration_log(migration_name, status);
                """))
                
                logger.info("Migration tracking table initialized")
        except SQLAlchemyError as e:
            logger.error(f"Failed to create tracking table: {e}")
            raise
    
    def start_migration(self, migration_name: str, batch_id: str, metadata: Optional[Dict[str, Any]] = None) -> int:
        """
        Record migration start
        
        Args:
            migration_name: Name/identifier of the migration
            batch_id: Unique batch identifier (e.g., timestamp or UUID)
            metadata: Additional metadata to store
            
        Returns:
            Migration log ID
        """
        try:
            with self.pg_engine.begin() as conn:
                # Check if this migration batch was already completed
                existing = conn.execute(
                    text("""
                        SELECT id, status FROM migration_log 
                        WHERE migration_name = :name AND batch_id = :batch
                    """),
                    {"name": migration_name, "batch": batch_id}
                ).fetchone()
                
                if existing:
                    if existing[1] == MigrationStatus.COMPLETED.value:
                        logger.warning(f"Migration {migration_name} batch {batch_id} already completed")
                        return existing[0]
                    else:
                        # Update existing incomplete migration
                        logger.info(f"Resuming migration {migration_name} batch {batch_id}")
                        conn.execute(
                            text("""
                                UPDATE migration_log 
                                SET status = :status, started_at = CURRENT_TIMESTAMP
                                WHERE id = :id
                            """),
                            {"status": MigrationStatus.IN_PROGRESS.value, "id": existing[0]}
                        )
                        return existing[0]
                
                # Create new migration record
                result = conn.execute(
                    text("""
                        INSERT INTO migration_log 
                        (migration_name, batch_id, status, metadata)
                        VALUES (:name, :batch, :status, :metadata::jsonb)
                        RETURNING id
                    """),
                    {
                        "name": migration_name,
                        "batch": batch_id,
                        "status": MigrationStatus.IN_PROGRESS.value,
                        "metadata": str(metadata) if metadata else None
                    }
                )
                migration_id = result.fetchone()[0]
                logger.info(f"Started migration {migration_name} with ID {migration_id}")
                return migration_id
                
        except SQLAlchemyError as e:
            logger.error(f"Failed to start migration tracking: {e}")
            raise
    
    def update_progress(self, migration_id: int, records_processed: int, records_failed: int = 0):
        """
        Update migration progress
        
        Args:
            migration_id: Migration log ID
            records_processed: Number of successfully processed records
            records_failed: Number of failed records
        """
        try:
            with self.pg_engine.begin() as conn:
                conn.execute(
                    text("""
                        UPDATE migration_log 
                        SET records_processed = :processed, records_failed = :failed
                        WHERE id = :id
                    """),
                    {"processed": records_processed, "failed": records_failed, "id": migration_id}
                )
        except SQLAlchemyError as e:
            logger.error(f"Failed to update migration progress: {e}")
    
    def complete_migration(self, migration_id: int, records_processed: int, records_failed: int = 0):
        """
        Mark migration as completed
        
        Args:
            migration_id: Migration log ID
            records_processed: Total successfully processed records
            records_failed: Total failed records
        """
        try:
            with self.pg_engine.begin() as conn:
                conn.execute(
                    text("""
                        UPDATE migration_log 
                        SET status = :status, 
                            records_processed = :processed,
                            records_failed = :failed,
                            completed_at = CURRENT_TIMESTAMP
                        WHERE id = :id
                    """),
                    {
                        "status": MigrationStatus.COMPLETED.value,
                        "processed": records_processed,
                        "failed": records_failed,
                        "id": migration_id
                    }
                )
                logger.info(f"Completed migration ID {migration_id}: {records_processed} processed, {records_failed} failed")
        except SQLAlchemyError as e:
            logger.error(f"Failed to complete migration tracking: {e}")
            raise
    
    def fail_migration(self, migration_id: int, error_message: str, records_processed: int = 0, records_failed: int = 0):
        """
        Mark migration as failed
        
        Args:
            migration_id: Migration log ID
            error_message: Error description
            records_processed: Records processed before failure
            records_failed: Number of failed records
        """
        try:
            with self.pg_engine.begin() as conn:
                conn.execute(
                    text("""
                        UPDATE migration_log 
                        SET status = :status, 
                            error_message = :error,
                            records_processed = :processed,
                            records_failed = :failed,
                            completed_at = CURRENT_TIMESTAMP
                        WHERE id = :id
                    """),
                    {
                        "status": MigrationStatus.FAILED.value,
                        "error": error_message,
                        "processed": records_processed,
                        "failed": records_failed,
                        "id": migration_id
                    }
                )
                logger.error(f"Failed migration ID {migration_id}: {error_message}")
        except SQLAlchemyError as e:
            logger.error(f"Failed to record migration failure: {e}")
    
    def get_last_successful_migration(self, migration_name: str) -> Optional[Dict[str, Any]]:
        """
        Get details of the last successful migration
        
        Args:
            migration_name: Name of the migration
            
        Returns:
            Dictionary with migration details or None
        """
        try:
            with self.pg_engine.connect() as conn:
                result = conn.execute(
                    text("""
                        SELECT id, batch_id, records_processed, completed_at
                        FROM migration_log
                        WHERE migration_name = :name AND status = :status
                        ORDER BY completed_at DESC
                        LIMIT 1
                    """),
                    {"name": migration_name, "status": MigrationStatus.COMPLETED.value}
                ).fetchone()
                
                if result:
                    return {
                        "id": result[0],
                        "batch_id": result[1],
                        "records_processed": result[2],
                        "completed_at": result[3]
                    }
                return None
        except SQLAlchemyError as e:
            logger.error(f"Failed to get last migration: {e}")
            return None
