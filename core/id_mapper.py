"""
ID Mapping Module
Maintains a mapping of legacy source IDs to new target UUIDs.
Used to resolve foreign key references across migration batches.
"""
import logging
from typing import Optional, Dict
from sqlalchemy import text, Engine
from sqlalchemy.exc import SQLAlchemyError

logger = logging.getLogger(__name__)


class IdMapper:
    """Manages legacy_id → new_uuid mappings in PostgreSQL"""

    def __init__(self, pg_engine: Engine):
        self.pg_engine = pg_engine
        self._ensure_table()

    def _ensure_table(self):
        """Create the id_map table if it doesn't exist"""
        with self.pg_engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS id_map (
                    source_table VARCHAR(255) NOT NULL,
                    source_id VARCHAR(255) NOT NULL,
                    target_table VARCHAR(255) NOT NULL,
                    target_id UUID NOT NULL,
                    migrated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (source_table, source_id)
                );
                CREATE INDEX IF NOT EXISTS idx_id_map_target
                    ON id_map(target_table, target_id);
            """))
        logger.info("ID mapping table initialized")

    def put(self, source_table: str, source_id, target_table: str, target_id: str):
        """Store a single mapping"""
        with self.pg_engine.begin() as conn:
            conn.execute(text("""
                INSERT INTO id_map (source_table, source_id, target_table, target_id)
                VALUES (:src_table, :src_id, :tgt_table, :tgt_id)
                ON CONFLICT (source_table, source_id) DO UPDATE
                    SET target_id = EXCLUDED.target_id
            """), {
                "src_table": source_table,
                "src_id": str(source_id),
                "tgt_table": target_table,
                "tgt_id": target_id,
            })

    def put_batch(self, source_table: str, target_table: str, mappings: Dict[str, str]):
        """
        Store a batch of mappings.
        mappings: { source_id: target_uuid, ... }
        """
        if not mappings:
            return
        with self.pg_engine.begin() as conn:
            for src_id, tgt_id in mappings.items():
                conn.execute(text("""
                    INSERT INTO id_map (source_table, source_id, target_table, target_id)
                    VALUES (:src_table, :src_id, :tgt_table, :tgt_id)
                    ON CONFLICT (source_table, source_id) DO UPDATE
                        SET target_id = EXCLUDED.target_id
                """), {
                    "src_table": source_table,
                    "src_id": str(src_id),
                    "tgt_table": target_table,
                    "tgt_id": tgt_id,
                })
        logger.info(f"Stored {len(mappings)} ID mappings for {source_table} → {target_table}")

    def get(self, source_table: str, source_id) -> Optional[str]:
        """Look up a single target UUID by source table + id"""
        with self.pg_engine.connect() as conn:
            row = conn.execute(text("""
                SELECT target_id FROM id_map
                WHERE source_table = :src_table AND source_id = :src_id
            """), {"src_table": source_table, "src_id": str(source_id)}).fetchone()
            return str(row[0]) if row else None

    def get_all(self, source_table: str) -> Dict[str, str]:
        """Get all mappings for a given source table as {source_id: target_uuid}"""
        with self.pg_engine.connect() as conn:
            rows = conn.execute(text("""
                SELECT source_id, target_id FROM id_map
                WHERE source_table = :src_table
            """), {"src_table": source_table}).fetchall()
            return {row[0]: str(row[1]) for row in rows}
