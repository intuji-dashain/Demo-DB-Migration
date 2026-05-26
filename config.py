"""
Migration Configuration
Centralized settings for database migration operations
"""
import os
from dataclasses import dataclass
from typing import Optional
from dotenv import load_dotenv

load_dotenv()  # loads .env from the current working directory


@dataclass
class MigrationConfig:
    """Configuration for migration operations"""
    
    # Batch processing
    BATCH_SIZE: int = 1000  # Number of records to process in each batch
    MAX_RETRIES: int = 3  # Maximum retry attempts for failed operations
    RETRY_DELAY: int = 5  # Seconds to wait between retries
    
    # Timeouts (seconds)
    CONNECTION_TIMEOUT: int = 30
    QUERY_TIMEOUT: int = 300  # 5 minutes for large queries
    
    # Validation
    ENABLE_DATA_VALIDATION: bool = True
    VALIDATION_SAMPLE_SIZE: int = 100  # Number of records to validate after migration
    
    # Performance
    ENABLE_BATCH_INSERT: bool = True
    ENABLE_PROGRESS_TRACKING: bool = True
    
    # Logging
    LOG_LEVEL: str = "INFO"  # DEBUG, INFO, WARNING, ERROR
    LOG_FILE: Optional[str] = "migration.log"
    
    # Source Database (SQL Server)
    MSSQL_HOST: str = os.getenv('MSSQL_HOST', 'sqlserver')
    MSSQL_USER: str = os.getenv('MSSQL_USER', 'sa')
    MSSQL_PASSWORD: str = os.getenv('MSSQL_PASSWORD', '')
    MSSQL_DB: str = os.getenv('MSSQL_DB', 'source_db')
    MSSQL_PORT: int = int(os.getenv('MSSQL_PORT', '1433'))
    MSSQL_STRING: Optional[str] = os.getenv('MSSQL_STRING')  # Optional full connection string
    
    # Target Database (PostgreSQL)
    POSTGRES_HOST: str = os.getenv('POSTGRES_HOST', 'postgres')
    POSTGRES_USER: str = os.getenv('POSTGRES_USER', 'postgres')
    POSTGRES_PASSWORD: str = os.getenv('POSTGRES_PASSWORD', '')
    POSTGRES_DB: str = os.getenv('POSTGRES_DB', 'destination_db')
    POSTGRES_PORT: int = int(os.getenv('POSTGRES_PORT', '5432'))
    POSTGRES_STRING: Optional[str] = os.getenv('POSTGRES_STRING')  # Optional full connection string
    
    
    # Migration control
    DRY_RUN: bool = os.getenv('DRY_RUN', 'false').lower() == 'true'
    SKIP_VALIDATION: bool = os.getenv('SKIP_VALIDATION', 'false').lower() == 'true'
    CONTINUE_ON_ERROR: bool = os.getenv('CONTINUE_ON_ERROR', 'false').lower() == 'true'
    
    def __post_init__(self):
        """Validate configuration after initialization"""
        if not self.MSSQL_STRING and not self.MSSQL_PASSWORD:
            raise ValueError("Either MSSQL_STRING or MSSQL_PASSWORD is required")
        if not self.POSTGRES_STRING and not self.POSTGRES_PASSWORD:
            raise ValueError("Either POSTGRES_STRING or POSTGRES_PASSWORD is required")
        if self.BATCH_SIZE < 1:
            raise ValueError("BATCH_SIZE must be at least 1")
        if self.MAX_RETRIES < 1:
            raise ValueError("MAX_RETRIES must be at least 1")


# Global configuration instance
config = MigrationConfig()
