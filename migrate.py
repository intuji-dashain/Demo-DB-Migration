"""
Migration Orchestrator
Runs all migrations in dependency order.
"""
import sys
import logging

from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError
import time
from typing import Optional, Tuple
from sqlalchemy.engine import Engine

from config import config
from id_mapper import IdMapper
from migrate_admin_lookups import AdminLookupsMigration
from migrate_clients import ClientMigration, ClientCardMigration
from migrate_service_providers import ServiceProviderMigration
from migrate_budget_years import BudgetYearMigration
from migrate_budget_transactions import BudgetTransactionMigration


logging.basicConfig(
    level=getattr(logging, config.LOG_LEVEL),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(config.LOG_FILE) if config.LOG_FILE else logging.NullHandler(),
    ],
)
logger = logging.getLogger(__name__)


class MigrationError(Exception):
    pass


class DatabaseConnector:
    """Manages database connections with retry logic"""

    def __init__(self):
        self.source_engine: Optional[Engine] = None
        self.target_engine: Optional[Engine] = None

    def connect(self) -> Tuple[Engine, Engine]:
        logger.info("Establishing database connections...")
        for attempt in range(config.MAX_RETRIES):
            try:
                self.source_engine = create_engine(
                    config.MSSQL_STRING, pool_pre_ping=True, pool_recycle=3600
                )
                self.target_engine = create_engine(
                    config.POSTGRES_STRING, pool_pre_ping=True, pool_recycle=3600
                )
                with self.source_engine.connect() as conn:
                    conn.execute(text("SELECT 1"))
                with self.target_engine.connect() as conn:
                    conn.execute(text("SELECT 1"))
                logger.info("✓ Database connections established")
                return self.source_engine, self.target_engine
            except SQLAlchemyError as e:
                logger.warning(f"Connection attempt {attempt + 1}/{config.MAX_RETRIES} failed: {e}")
                if attempt < config.MAX_RETRIES - 1:
                    time.sleep(config.RETRY_DELAY)
                else:
                    raise MigrationError(f"Failed to connect after {config.MAX_RETRIES} attempts") from e

    def close(self):
        if self.source_engine:
            self.source_engine.dispose()
        if self.target_engine:
            self.target_engine.dispose()
        logger.info("Database connections closed")


def main():
    logger.info("Starting migration pipeline...")
    logger.info(f"DRY_RUN={config.DRY_RUN}, BATCH_SIZE={config.BATCH_SIZE}")

    connector = DatabaseConnector()
    try:
        source_engine, target_engine = connector.connect()
        id_mapper = IdMapper(target_engine)
        by_migration = BudgetYearMigration(source_engine, target_engine, id_mapper)

        steps = [
            ("Service Providers",   ServiceProviderMigration(source_engine, target_engine, id_mapper)),
            ("Budget Years",        by_migration),
            # ("Budget Transactions", BudgetTransactionMigration(source_engine, target_engine, id_mapper, by_migration)),
            ("Admin Lookups",       AdminLookupsMigration(source_engine, target_engine, id_mapper)),
            ("Clients",             ClientMigration(source_engine, target_engine, id_mapper)),
            ("Client Cards",        ClientCardMigration(source_engine, target_engine, id_mapper)),
        ]

        for name, migration in steps:
            logger.info(f"▶ Running: {name}")
            if not migration.run():
                logger.error(f"✗ {name} migration failed — aborting pipeline.")
                sys.exit(1)
            logger.info(f"✓ {name} complete")

        logger.info("✓ All migrations completed successfully.")
        sys.exit(0)

    except Exception as e:
        logger.critical(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)
    finally:
        connector.close()


if __name__ == "__main__":
    main()
