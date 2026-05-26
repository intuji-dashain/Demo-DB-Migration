"""
Admin Lookups Migration — Batch 1
Migrates all simple lookup tables in a single pass:

  tblCardType              → client_card_types
  tblEquipmentCategory     → equipment_categories
  tblEligibilityDetermined → referral_eligibilities
  tblOtherEligibilityCriteria → client_eligibility_criterias
  tblEquipmentType         → equipment_types  (requires equipment_categories FK)

Run order matters: equipment_categories must finish before equipment_types.
"""
import logging
import re
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
import uuid6
from sqlalchemy import text, Engine
from sqlalchemy.exc import SQLAlchemyError

from config import config
from id_mapper import IdMapper
from migration_tracker import MigrationTracker

logger = logging.getLogger(__name__)


class MigrationError(Exception):
    pass


def _clean(value):
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


# ---------------------------------------------------------------------------
# Base class — shared ETL skeleton
# ---------------------------------------------------------------------------

class _SimpleLookupMigration:
    """
    Abstract base for a simple lookup table with the standard columns:
        id, name, description, is_active, created_at, updated_at, creator_user_id
    Subclasses override SOURCE_QUERY, TARGET_TABLE, and _transform_row().
    """

    MIGRATION_NAME: str = ""
    TARGET_TABLE:   str = ""
    SOURCE_QUERY:   str = ""

    def __init__(self, source_engine: Engine, target_engine: Engine, id_mapper: IdMapper):
        self.source_engine = source_engine
        self.target_engine = target_engine
        self.id_mapper     = id_mapper
        self.tracker       = MigrationTracker(target_engine)

    # -- override in subclass ------------------------------------------------

    def _transform_row(self, row: Any, now: datetime) -> Dict[str, Any]:
        raise NotImplementedError

    def _upsert_stmt(self) -> text:
        raise NotImplementedError

    # -- shared pipeline -----------------------------------------------------

    def _extract(self) -> pd.DataFrame:
        df = pd.read_sql(self.SOURCE_QUERY, self.source_engine)
        logger.info(f"  ✓ Extracted {len(df)} rows from source for {self.TARGET_TABLE}")
        return df

    def _transform(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        now = datetime.utcnow()
        records = [self._transform_row(row, now) for _, row in df.iterrows()]
        logger.info(f"  ✓ Transformed {len(records)} records for {self.TARGET_TABLE}")
        return records

    def _load(self, records: List[Dict[str, Any]]) -> Tuple[int, int]:
        if config.DRY_RUN:
            logger.info(f"  [DRY RUN] Would insert {len(records)} rows into {self.TARGET_TABLE}")
            return len(records), 0

        stmt = self._upsert_stmt()
        success, failed = 0, 0
        for start in range(0, len(records), config.BATCH_SIZE):
            batch = records[start: start + config.BATCH_SIZE]
            try:
                with self.target_engine.begin() as conn:
                    for rec in batch:
                        conn.execute(stmt, rec)
                success += len(batch)
            except SQLAlchemyError as e:
                logger.error(f"  Batch failed at index {start} for {self.TARGET_TABLE}: {e}")
                failed += len(batch)
                if not config.CONTINUE_ON_ERROR:
                    raise MigrationError(f"Load aborted for {self.TARGET_TABLE}") from e
        return success, failed

    def run(self) -> bool:
        logger.info(f"  ▶ {self.MIGRATION_NAME}")
        batch_id     = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        migration_id = None
        try:
            migration_id = self.tracker.start_migration(self.MIGRATION_NAME, batch_id)
            df           = self._extract()
            if df.empty:
                logger.warning(f"  No rows found for {self.TARGET_TABLE}")
                self.tracker.complete_migration(migration_id, 0, 0)
                return True
            records          = self._transform(df)
            success, failed  = self._load(records)
            self.tracker.complete_migration(migration_id, success, failed)
            logger.info(f"  ✓ {self.TARGET_TABLE}: {success} inserted, {failed} failed")
            return failed == 0
        except Exception as e:
            logger.error(f"  ✗ {self.TARGET_TABLE} failed: {e}", exc_info=True)
            if migration_id:
                self.tracker.fail_migration(migration_id, str(e))
            return False


# ---------------------------------------------------------------------------
# 1. client_card_types  ←  tblCardType
# ---------------------------------------------------------------------------

class ClientCardTypeMigration(_SimpleLookupMigration):

    MIGRATION_NAME = "client_card_types_migration"
    TARGET_TABLE   = "client_card_types"
    SOURCE_QUERY   = "SELECT CardTypeID, CardTypeName FROM dbo.tblCardType ORDER BY CardTypeID"

    def _transform_row(self, row, now):
        new_id = str(uuid6.uuid7())
        self.id_mapper.put("tblCardType", int(row["CardTypeID"]), "client_card_types", new_id)
        return {
            "id":              new_id,
            "name":            row["CardTypeName"],
            "description":     None,
            "is_active":       True,
            "created_at":      now,
            "updated_at":      now,
            "creator_user_id": None,
        }

    def _upsert_stmt(self):
        return text("""
            INSERT INTO client_card_types
                (id, name, description, is_active, created_at, updated_at, creator_user_id)
            VALUES
                (:id, :name, :description, :is_active, :created_at, :updated_at, :creator_user_id)
            ;
        """)


# ---------------------------------------------------------------------------
# 2. equipment_categories  ←  tblEquipmentCategory
# ---------------------------------------------------------------------------

class EquipmentCategoryMigration(_SimpleLookupMigration):

    MIGRATION_NAME = "equipment_categories_migration"
    TARGET_TABLE   = "equipment_categories"
    SOURCE_QUERY   = "SELECT EquipmentCategoryID, EquipmentCategoryName FROM dbo.tblEquipmentCategory ORDER BY EquipmentCategoryID"

    def _transform_row(self, row, now):
        new_id = str(uuid6.uuid7())
        self.id_mapper.put("tblEquipmentCategory", int(row["EquipmentCategoryID"]), "equipment_categories", new_id)
        return {
            "id":              new_id,
            "name":            row["EquipmentCategoryName"],
            "description":     None,
            "is_editable":     True,
            "is_active":       True,
            "created_at":      now,
            "updated_at":      now,
            "creator_user_id": None,
        }

    def _upsert_stmt(self):
        return text("""
            INSERT INTO equipment_categories
                (id, name, description, is_editable, is_active, created_at, updated_at, creator_user_id)
            VALUES
                (:id, :name, :description, :is_editable, :is_active, :created_at, :updated_at, :creator_user_id)
            ;
        """)


# ---------------------------------------------------------------------------
# 3. referral_eligibilities  ←  tblEligibilityDetermined
# ---------------------------------------------------------------------------

class ReferralEligibilityMigration(_SimpleLookupMigration):

    MIGRATION_NAME = "referral_eligibilities_migration"
    TARGET_TABLE   = "referral_eligibilities"
    SOURCE_QUERY   = "SELECT EligibilityDeterminedID, EligibilityDeterminedName FROM dbo.tblEligibilityDetermined ORDER BY EligibilityDeterminedID"

    def _transform_row(self, row, now):
        new_id = str(uuid6.uuid7())
        self.id_mapper.put("tblEligibilityDetermined", int(row["EligibilityDeterminedID"]), "referral_eligibilities", new_id)
        return {
            "id":              new_id,
            "name":            row["EligibilityDeterminedName"],
            "description":     None,
            "is_active":       True,
            "created_at":      now,
            "updated_at":      now,
            "creator_user_id": None,
        }

    def _upsert_stmt(self):
        return text("""
            INSERT INTO referral_eligibilities
                (id, name, description, is_active, created_at, updated_at, creator_user_id)
            VALUES
                (:id, :name, :description, :is_active, :created_at, :updated_at, :creator_user_id)
            ;
        """)


# ---------------------------------------------------------------------------
# 4. client_eligibility_criterias  ←  tblOtherEligibilityCriteria
# ---------------------------------------------------------------------------

class ClientEligibilityCriteriaMigration(_SimpleLookupMigration):

    MIGRATION_NAME = "client_eligibility_criterias_migration"
    TARGET_TABLE   = "client_eligibility_criterias"
    SOURCE_QUERY   = "SELECT OtherEligibilityCriteriaID, OtherEligibilityCriteriaName FROM dbo.tblOtherEligibilityCriteria ORDER BY OtherEligibilityCriteriaID"

    def _transform_row(self, row, now):
        new_id = str(uuid6.uuid7())
        self.id_mapper.put("tblOtherEligibilityCriteria", int(row["OtherEligibilityCriteriaID"]), "client_eligibility_criterias", new_id)
        return {
            "id":              new_id,
            "name":            row["OtherEligibilityCriteriaName"],
            "description":     None,
            "is_active":       True,
            "created_at":      now,
            "updated_at":      now,
            "creator_user_id": None,
        }

    def _upsert_stmt(self):
        return text("""
            INSERT INTO client_eligibility_criterias
                (id, name, description, is_active, created_at, updated_at, creator_user_id)
            VALUES
                (:id, :name, :description, :is_active, :created_at, :updated_at, :creator_user_id)
            ;
        """)


# ---------------------------------------------------------------------------
# 5. equipment_types  ←  tblEquipmentType
#    Depends on equipment_categories being migrated first (FK via id_mapper)
# ---------------------------------------------------------------------------

class EquipmentTypeMigration(_SimpleLookupMigration):

    MIGRATION_NAME = "equipment_types_migration"
    TARGET_TABLE   = "equipment_types"
    SOURCE_QUERY   = """
        SELECT
            EquipmentTypeID,
            EquipmentCategoryID,
            EquipmentTypeName,
            EquipmentTypeCode,
            MaximumQuantity,
            ApplyLoading,
            [Current]
        FROM dbo.tblEquipmentType
        ORDER BY EquipmentTypeID
    """

    def _transform_row(self, row, now):
        new_id      = str(uuid6.uuid7())
        category_id = self.id_mapper.get("tblEquipmentCategory", int(row["EquipmentCategoryID"])) \
                      if _clean(row.get("EquipmentCategoryID")) is not None else None
        self.id_mapper.put("tblEquipmentType", int(row["EquipmentTypeID"]), "equipment_types", new_id)
        return {
            "id":                  new_id,
            "equipment_category_id": category_id,
            "name":                str(row["EquipmentTypeName"])[:255],
            "code":                str(int(row["EquipmentTypeCode"])) if _clean(row.get("EquipmentTypeCode")) is not None else None,
            "description":         None,
            "max_quantity":        int(row["MaximumQuantity"]) if _clean(row.get("MaximumQuantity")) is not None else None,
            "has_loading_cost":    bool(row["ApplyLoading"]) if _clean(row.get("ApplyLoading")) is not None else False,
            "can_therapist_view":  True,
            "is_active":           bool(row["Current"]) if _clean(row.get("Current")) is not None else True,
            "created_at":          now,
            "updated_at":          now,
            "creator_user_id":     None,
        }

    def _upsert_stmt(self):
        return text("""
            INSERT INTO equipment_types (
                id, equipment_category_id, name, code, description,
                max_quantity, has_loading_cost, can_therapist_view,
                is_active, created_at, updated_at, creator_user_id
            ) VALUES (
                :id, :equipment_category_id, :name, :code, :description,
                :max_quantity, :has_loading_cost, :can_therapist_view,
                :is_active, :created_at, :updated_at, :creator_user_id
            )
        """)


# ---------------------------------------------------------------------------
# 6. referral_levels  ←  tblReferralLevel
# ---------------------------------------------------------------------------

class ReferralLevelMigration(_SimpleLookupMigration):

    MIGRATION_NAME = "referral_levels_migration"
    TARGET_TABLE   = "referral_levels"
    SOURCE_QUERY   = "SELECT ReferralLevelID, ReferralLevelName FROM dbo.tblReferralLevel ORDER BY ReferralLevelID"

    def __init__(self, source_engine: Engine, target_engine: Engine, id_mapper: IdMapper):
        super().__init__(source_engine, target_engine, id_mapper)
        self._display_order = 0

    def _transform_row(self, row, now):
        self._display_order += 1
        new_id = str(uuid6.uuid7())
        self.id_mapper.put("tblReferralLevel", int(row["ReferralLevelID"]), "referral_levels", new_id)
        return {
            "id":              new_id,
            "name":            row["ReferralLevelName"],
            "description":     None,
            "display_order":   self._display_order,
            "is_active":       True,
            "created_at":      now,
            "updated_at":      now,
            "creator_user_id": None,
        }

    def _upsert_stmt(self):
        return text("""
            INSERT INTO referral_levels
                (id, name, description, display_order, is_active, created_at, updated_at, creator_user_id)
            VALUES
                (:id, :name, :description, :display_order, :is_active, :created_at, :updated_at, :creator_user_id)
            ;
        """)


# ---------------------------------------------------------------------------
# 7. info_types  ←  tblInformationCategory
# ---------------------------------------------------------------------------

class InfoTypeMigration(_SimpleLookupMigration):

    MIGRATION_NAME = "info_types_migration"
    TARGET_TABLE   = "info_types"
    SOURCE_QUERY   = "SELECT ID, Name FROM dbo.tblInformationCategory ORDER BY ID"

    def __init__(self, source_engine: Engine, target_engine: Engine, id_mapper: IdMapper):
        super().__init__(source_engine, target_engine, id_mapper)
        self._sort_order = 0

    def _transform_row(self, row, now):
        self._sort_order += 1
        new_id = str(uuid6.uuid7())
        name   = str(row["Name"])
        slug   = name.lower().strip().replace(" ", "-").replace("/", "-")
        slug = re.sub(r"[^a-z0-9\-_]", "", slug)
        self.id_mapper.put("tblInformationCategory", int(row["ID"]), "info_types", new_id)
        return {
            "id":          new_id,
            "name":        name,
            "slug":        slug,
            "description": None,
            "sort_order":  self._sort_order,
            "is_active":   True,
            "created_at":  now,
            "updated_at":  now,
        }

    def _upsert_stmt(self):
        return text("""
            INSERT INTO info_types
                (id, name, slug, description, sort_order, is_active, created_at, updated_at)
            VALUES
                (:id, :name, :slug, :description, :sort_order, :is_active, :created_at, :updated_at)
                ;
        """)


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------

class AdminLookupsMigration:
    """
    Runs all Batch 1 admin lookup migrations in dependency order.
    equipment_categories must run before equipment_types.
    """

    def __init__(self, source_engine: Engine, target_engine: Engine, id_mapper: IdMapper):
        self.steps = [
            ClientCardTypeMigration(source_engine, target_engine, id_mapper),
            EquipmentCategoryMigration(source_engine, target_engine, id_mapper),  # before EquipmentType
            ReferralEligibilityMigration(source_engine, target_engine, id_mapper),
            ClientEligibilityCriteriaMigration(source_engine, target_engine, id_mapper),
            EquipmentTypeMigration(source_engine, target_engine, id_mapper),
            ReferralLevelMigration(source_engine, target_engine, id_mapper),
            InfoTypeMigration(source_engine, target_engine, id_mapper),
        ]

    def run(self) -> bool:
        logger.info("=" * 70)
        logger.info("Starting Admin Lookups Migration (Batch 1)")
        logger.info("=" * 70)
        for step in self.steps:
            if not step.run():
                logger.error(f"✗ Admin lookup migration failed at: {step.TARGET_TABLE}")
                return False
        logger.info("✓ All admin lookup migrations complete")
        return True
