"""
Service Provider Migration
Migrates tblBusiness → service_providers with ID mapping
"""
import logging
from datetime import datetime
from typing import List, Dict, Any

import pandas as pd
import numpy as np
import uuid6
from sqlalchemy import text, Engine
from sqlalchemy.exc import SQLAlchemyError

from core.config import config
from core.id_mapper import IdMapper


def _clean(value):
    """Convert pandas NA/NaT/NaN to None for safe DB insertion"""
    if value is None:
        return None
    if isinstance(value, float) and np.isnan(value):
        return None
    try:
        if pd.isna(value):
            return None
    except (TypeError, ValueError):
        pass
    return value

logger = logging.getLogger(__name__)


class ServiceProviderMigration:
    """Migrates service providers from tblBusiness and records ID mappings"""

    SOURCE_TABLE = "tblBusiness"
    TARGET_TABLE = "service_providers"

    def __init__(self, source_engine: Engine, target_engine: Engine, id_mapper: IdMapper):
        self.source_engine = source_engine
        self.target_engine = target_engine
        self.id_mapper = id_mapper

    def _ensure_target_schema(self):
        """Create service_providers table if not exists"""
        with self.target_engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS service_providers (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    name VARCHAR(255) NOT NULL,
                    description TEXT NULL,
                    email VARCHAR(255) NULL,
                    phone VARCHAR(255) NULL,
                    logo_url VARCHAR(255) NULL,
                    address VARCHAR(255) NULL,
                    suburb VARCHAR(255) NULL,
                    postcode VARCHAR(255) NULL,
                    is_sla_enabled BOOLEAN DEFAULT FALSE,
                    is_specialist BOOLEAN DEFAULT FALSE,
                    is_internal BOOLEAN DEFAULT FALSE,
                    type VARCHAR(20) NOT NULL DEFAULT 'OTHER',
                    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
                    reason VARCHAR(255) NULL,
                    parent_id UUID NULL,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    creator_user_id UUID NULL
                );
            """))
        logger.info("✓ service_providers schema verified")

    def _extract(self) -> pd.DataFrame:
        """Extract businesses from SQL Server"""
        query = """
            SELECT 
                BusinessID,
                BusinessName,
                Comment,
                Address,
                Suburb,
                Postcode,
                SLA,
                Specialist,
                InternalServiceProvider,
                HealthProvider,
                BusinessStatusID,
                ParentID,
                DateCreated,
                DateModified,
                CreatedBy
            FROM dbo.tblBusiness
            ORDER BY BusinessID
        """
        df = pd.read_sql(query, self.source_engine)
        logger.info(f"✓ Extracted {len(df)} service providers from source")
        return df

    def _resolve_type(self, health_provider_flag) -> str:
        """Map HealthProvider bit to service provider type"""
        if health_provider_flag:
            return "HSP"
        return "LSP"

    def _resolve_status(self, status_id) -> str:
        """Map legacy BusinessStatusID to enum string"""
        status_map = {1: "ACTIVE", 2: "INACTIVE", 3: "SUSPENDED", 4: "ARCHIVED"}
        return status_map.get(int(status_id) if status_id else 1, "ACTIVE")

    def _transform(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        """Transform source rows to target schema, generating UUIDs"""
        records = []
        id_mappings: Dict[str, str] = {}
        now = datetime.utcnow()

        for _, row in df.iterrows():
            new_id = str(uuid6.uuid7())
            source_id = str(int(row['BusinessID']))

            records.append({
                'id': new_id,
                'name': row['BusinessName'],
                'description': _clean(row.get('Comment')),
                'email': None,
                'phone': None,
                'logo_url': None,
                'address': _clean(row.get('Address')),
                'suburb': _clean(row.get('Suburb')),
                'postcode': _clean(row.get('Postcode')),
                'is_sla_enabled': bool(row.get('SLA', False)),
                'is_specialist': bool(row.get('Specialist', False)),
                'is_internal': bool(row.get('InternalServiceProvider', False)),
                'type': self._resolve_type(row.get('HealthProvider')),
                'status': self._resolve_status(row.get('BusinessStatusID')),
                'reason': None,
                'parent_id': None,  # resolved in second pass
                'created_at': _clean(row.get('DateCreated')) or now,
                'updated_at': _clean(row.get('DateModified')) or now,
                'creator_user_id': None,
            })
            id_mappings[source_id] = new_id

        # Store all mappings
        self.id_mapper.put_batch(self.SOURCE_TABLE, self.TARGET_TABLE, id_mappings)
        logger.info(f"✓ Transformed {len(records)} service providers, stored {len(id_mappings)} ID mappings")
        return records

    def _resolve_parent_ids(self, records: List[Dict[str, Any]], df: pd.DataFrame):
        """Second pass: resolve ParentID using id_map"""
        parent_map = self.id_mapper.get_all(self.SOURCE_TABLE)
        for i, row in df.iterrows():
            parent_legacy = row.get('ParentID')
            if parent_legacy and not pd.isna(parent_legacy):
                records[i]['parent_id'] = parent_map.get(str(int(parent_legacy)))

    def _load(self, records: List[Dict[str, Any]]):
        """
        Insert into PostgreSQL in two passes to handle self-referential parent_id FK:
          Pass 1 — insert all rows with parent_id=None
          Pass 2 — UPDATE rows that have a parent_id
        """
        if config.DRY_RUN:
            logger.info(f"[DRY RUN] Would insert {len(records)} service providers")
            return

        insert_stmt = text("""
            INSERT INTO service_providers (
                id, name, description, email, phone, logo_url,
                address, suburb, postcode,
                is_sla_enabled, is_specialist, is_internal,
                type, status, reason, parent_id,
                created_at, updated_at, creator_user_id
            ) VALUES (
                :id, :name, :description, :email, :phone, :logo_url,
                :address, :suburb, :postcode,
                :is_sla_enabled, :is_specialist, :is_internal,
                :type, :status, :reason, NULL,
                :created_at, :updated_at, :creator_user_id
            ) ON CONFLICT (id) DO NOTHING;
        """)

        update_stmt = text("""
            UPDATE service_providers SET parent_id = :parent_id WHERE id = :id;
        """)

        # Pass 1: insert all rows without parent_id
        for start in range(0, len(records), config.BATCH_SIZE):
            batch = records[start:start + config.BATCH_SIZE]
            with self.target_engine.begin() as conn:
                for rec in batch:
                    conn.execute(insert_stmt, rec)
            logger.info(f"✓ Inserted batch {start // config.BATCH_SIZE + 1}")

        # Pass 2: update parent_id for rows that have one
        children = [r for r in records if r.get('parent_id')]
        if children:
            with self.target_engine.begin() as conn:
                for rec in children:
                    conn.execute(update_stmt, {'id': rec['id'], 'parent_id': rec['parent_id']})
            logger.info(f"✓ Resolved parent_id for {len(children)} child service providers")

    def run(self) -> bool:
        """Execute full service provider migration"""
        logger.info("=" * 70)
        logger.info("Starting Service Provider Migration (tblBusiness → service_providers)")
        logger.info("=" * 70)
        try:
            self._ensure_target_schema()
            df = self._extract()
            if df.empty:
                logger.warning("No service providers to migrate")
                return True
            records = self._transform(df)
            self._resolve_parent_ids(records, df)
            self._load(records)
            logger.info("✓ Service Provider migration complete")
            return True
        except Exception as e:
            logger.error(f"Service Provider migration failed: {e}", exc_info=True)
            return False
