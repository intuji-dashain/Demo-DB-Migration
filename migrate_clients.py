"""
Clients Migration — Batch 3 (Transactions)
Migrates tblClient → clients with FK resolution via IdMapper.

FK dependencies (must be migrated first):
  tblBusiness                  → service_providers         (service_provider_id)
  tblOtherEligibilityCriteria  → client_eligibility_criterias (client_eligibility_criteria_id)

Enum conversions:
  tblClientStatus.ClientStatusName  → clients.status       (VARCHAR(11))
  tblIndigenousType.IndigenousTypeName → clients.indigenous_status (VARCHAR(22))
"""
import logging
from datetime import datetime
from typing import Any, Dict, List, Optional

import numpy as np
import pandas as pd
import uuid6
from sqlalchemy import text, Engine
from sqlalchemy.exc import SQLAlchemyError

from config import config
from id_mapper import IdMapper
from migration_tracker import MigrationTracker

logger = logging.getLogger(__name__)


def _clean(value):
    """Convert pandas NA/NaT/NaN to None for safe DB insertion."""
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
# Enum normalisation helpers
# ---------------------------------------------------------------------------

_STATUS_MAP: Dict[str, str] = {
"Current":    "ACTIVE",
    "Deceased":   "DECEASED",
    "Inactive": "INACTIVE",
}

_INDIGENOUS_MAP: Dict[str, str] = {
    "aboriginal":                                          "NON_INDIGENOUS",
    "torres strait islander":                              "TORRES_STRAIT_ISLANDER",
    "aboriginal and torres strait islander":               "TORRES_STRAIT_ISLANDER",
    "both aboriginal and torres strait islander":          "TORRES_STRAIT_ISLANDER",
    "neither aboriginal nor torres strait islander":       "NON_INDIGENOUS",
    "not stated":                                          "UNSPECIFIED",
    "unknown":                                             "UNSPECIFIED",
}

_GENDER_MAP: Dict[str, str] = {
    "M":      "MALE",
    "F":      "FEMALE",
}


def _normalise_status(raw: Optional[str]) -> str:
    if not raw:
        return "ACTIVE"
    return _STATUS_MAP.get(str(raw).strip().lower(), "ACTIVE")


def _normalise_indigenous(raw: Optional[str]) -> str:
    if not raw:
        return "UNSPECIFIED"
    return _INDIGENOUS_MAP.get(str(raw).strip().lower(), "UNSPECIFIED")


def _normalise_gender(raw: Optional[str]) -> str:
    if not raw:
        return "OTHER"
    return _GENDER_MAP.get(str(raw).strip().lower(), "OTHER")


# ---------------------------------------------------------------------------
# ClientMigration
# ---------------------------------------------------------------------------

class ClientMigration:
    """Migrates clients from tblClient and records ID mappings."""

    SOURCE_TABLE = "tblClient"
    TARGET_TABLE = "clients"

    SOURCE_QUERY = """
        SELECT
            c.ClientID,
            c.BusinessID,
            c.OtherEligibilityCriteriaID,
            c.FirstName,
            c.SurName,
            c.UMRN,
            c.EmailAddress,
            c.PhoneNumber,
            c.Comment,
            c.DOB,
            c.Address,
            c.Suburb,
            c.Postcode,
            c.BusinessClientNumber,
            c.CardTypeID,
            c.CardNumber,
            c.Gender,
            c.DateCreated,
            c.DateModified,
            c.CreatedBy,
            cs.ClientStatusName,
            it.IndigenousTypeName
        FROM dbo.tblClient c
        LEFT JOIN dbo.tblClientStatus cs
            ON cs.ClientStatusiD = c.ClientStatusID
        LEFT JOIN dbo.tblIndigenousType it
            ON it.IndigenousTypeID = c.IndigenousTypeID
        ORDER BY c.ClientID
    """

    def __init__(self, source_engine: Engine, target_engine: Engine, id_mapper: IdMapper):
        self.source_engine = source_engine
        self.target_engine = target_engine
        self.id_mapper     = id_mapper
        self.tracker       = MigrationTracker(target_engine)


    # ------------------------------------------------------------------ #
    # Extract                                                              #
    # ------------------------------------------------------------------ #

    def _extract(self) -> pd.DataFrame:
        df = pd.read_sql(self.SOURCE_QUERY, self.source_engine)
        logger.info(f"✓ Extracted {len(df)} clients from source")
        return df

    # ------------------------------------------------------------------ #
    # Transform                                                            #
    # ------------------------------------------------------------------ #

    def _transform(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        records: List[Dict[str, Any]] = []
        id_mappings: Dict[str, str]   = {}
        sp_map       = self.id_mapper.get_all("tblBusiness")
        criteria_map = self.id_mapper.get_all("tblOtherEligibilityCriteria")
        now          = datetime.utcnow()

        skipped = 0
        for _, row in df.iterrows():
            source_id  = str(int(row["ClientID"]))
            business_id = _clean(row.get("BusinessID"))

            # service_provider_id is NOT NULL — skip rows that can't be resolved
            sp_id = sp_map.get(str(int(business_id))) if business_id is not None else None
            if sp_id is None:
                logger.warning(
                    f"  Skipping ClientID={source_id}: no service_provider mapping "
                    f"for BusinessID={business_id}"
                )
                skipped += 1
                continue

            new_id = str(uuid6.uuid7())

            # Optional FK: client_eligibility_criteria_id
            criteria_legacy = _clean(row.get("OtherEligibilityCriteriaID"))
            criteria_id = (
                criteria_map.get(str(int(criteria_legacy)))
                if criteria_legacy is not None
                else None
            )

            # has_card: true if client has a card type assigned
            has_card = bool(_clean(row.get("CardTypeID")) is not None)

            record: Dict[str, Any] = {
                "id":                              new_id,
                "service_provider_id":             sp_id,
                "client_eligibility_criteria_id":  criteria_id,
                "client_eligibility_determined_id": None,
                "first_name":                      str(row["FirstName"]).strip(),
                "last_name":                       str(row["SurName"]).strip(),
                "umrn":                            _clean(row.get("UMRN")),
                "email":                           _clean(row.get("EmailAddress")),
                "phone":                           _clean(row.get("PhoneNumber")),
                "description":                     _clean(row.get("Comment")),
                "avatar_url":                      None,
                "dob":                             _clean(row.get("DOB")),
                "address_line1":                   _clean(row.get("Address")),
                "address_line2":                   None,
                "suburb":                          _clean(row.get("Suburb")),
                "postcode":                        _clean(row.get("Postcode")),
                "client_number":                   _clean(row.get("BusinessClientNumber")),
                "internal_reference_code":         None,
                "external_reference_code":         None,
                "has_card":                        has_card,
                "gender":                          _normalise_gender(_clean(row.get("Gender"))),
                "indigenous_status":               _normalise_indigenous(_clean(row.get("IndigenousTypeName"))),
                "status":                          _normalise_status(_clean(row.get("ClientStatusName"))),
                "transfer_history":                None,
                "reason":                          None,
                "created_at":                      _clean(row.get("DateCreated")) or now,
                "updated_at":                      _clean(row.get("DateModified")) or now,
                "creator_user_id":                 None,  # CreatedBy is a legacy int user ref
            }

            records.append(record)
            id_mappings[source_id] = new_id

        self.id_mapper.put_batch(self.SOURCE_TABLE, self.TARGET_TABLE, id_mappings)
        logger.info(
            f"✓ Transformed {len(records)} clients "
            f"({skipped} skipped — missing service_provider FK), "
            f"stored {len(id_mappings)} ID mappings"
        )
        return records

    # ------------------------------------------------------------------ #
    # Load                                                                 #
    # ------------------------------------------------------------------ #

    def _load(self, records: List[Dict[str, Any]]):
        if config.DRY_RUN:
            logger.info(f"[DRY RUN] Would insert {len(records)} clients")
            return 0

        stmt = text("""
            INSERT INTO clients (
                id, service_provider_id,
                client_eligibility_criteria_id, client_eligibility_determined_id,
                first_name, last_name,
                umrn, email, phone, description, avatar_url,
                dob, address_line1, address_line2, suburb, postcode,
                client_number, internal_reference_code, external_reference_code,
                has_card, gender, indigenous_status, status,
                transfer_history, reason,
                created_at, updated_at, creator_user_id
            ) VALUES (
                :id, :service_provider_id,
                :client_eligibility_criteria_id, :client_eligibility_determined_id,
                :first_name, :last_name,
                :umrn, :email, :phone, :description, :avatar_url,
                :dob, :address_line1, :address_line2, :suburb, :postcode,
                :client_number, :internal_reference_code, :external_reference_code,
                :has_card, :gender, :indigenous_status, :status,
                CAST(:transfer_history AS jsonb), :reason,
                :created_at, :updated_at, :creator_user_id
            )
            ON CONFLICT (id) DO NOTHING;
        """)

        success, failed = 0, 0
        for start in range(0, len(records), config.BATCH_SIZE):
            batch = records[start: start + config.BATCH_SIZE]
            try:
                with self.target_engine.begin() as conn:
                    for rec in batch:
                        conn.execute(stmt, rec)
                success += len(batch)
                logger.info(f"  ✓ Inserted batch {start // config.BATCH_SIZE + 1} ({len(batch)} rows)")
            except SQLAlchemyError as e:
                logger.error(f"  Batch failed at index {start}: {e}")
                failed += len(batch)
                if not config.CONTINUE_ON_ERROR:
                    raise
        return success, failed

    # ------------------------------------------------------------------ #
    # Run                                                                  #
    # ------------------------------------------------------------------ #

    def run(self) -> bool:
        logger.info("=" * 70)
        logger.info("Starting Clients Migration (tblClient → clients)")
        logger.info("=" * 70)
        batch_id     = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        migration_id = None
        try:
            migration_id = self.tracker.start_migration("clients_migration", batch_id)
            df           = self._extract()
            if df.empty:
                logger.warning("No clients to migrate")
                self.tracker.complete_migration(migration_id, 0, 0)
                return True
            records         = self._transform(df)
            success, failed = self._load(records)
            self.tracker.complete_migration(migration_id, success, failed)
            logger.info(f"✓ Clients migration complete: {success} inserted, {failed} failed")
            return failed == 0
        except Exception as e:
            logger.error(f"✗ Clients migration failed: {e}", exc_info=True)
            if migration_id:
                self.tracker.fail_migration(migration_id, str(e))
            return False
