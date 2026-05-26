"""
Budget Transaction Migration
Migrates tblTransactionCAEPLog → budget_transactions.

Source transaction type taxonomy (from usp_FinanceSummary_Get):
  1 = COMMITTED       – reservation against an equipment action
  2 = INV_PAYM        – invoice / payment
  3 = BASE_BUDGET     – quarterly base budget release to provider
  4 = GROWTH_FUND     – growth fund injection to provider
  5 = ONEOFF_FUND     – one-off fund; either:
                          (a) inter-business transfer  → paired adjacent rows
                          (b) Finance injection to provider → single credit row
  6 = ADDITIONAL_REVENUE – additional revenue credit
  7 = ROLL_OVER       – uncommitted rollover carry-forward

Source ledger conventions (single-entry per account):
  AmountCredit > 0  → money flowing INTO this business account
  AmountDebit  > 0  → money flowing OUT OF this business account

Target double-entry mapping:
  RESERVATION  (type 1)  debit  → from_provider = this business (committing funds)
                          credit → to_provider   = this business (releasing reservation)
  PAYMENT      (type 2)  debit  → from_provider = this business (paying out)
                          credit → to_provider   = this business (reversal)
  ALLOCATION   (types 3,4,5b,6,7)
               credit only → to_provider = this business (budget received from DoH/CAEP)
  ALLOCATION   (type 5a transfer pair)
               collapsed  → from_provider = sender, to_provider = receiver

Pair detection rule (from SP qCaepTransferOOF CTE):
  Two consecutive type-5 rows are a transfer pair when:
    - same Narration
    - same CreatedBy
    - row[n].AmountDebit == row[n+1].AmountCredit  (and vice-versa)
    - NOT both rows belong to the same BusinessAccountID
"""
import json
import logging
from datetime import datetime, date
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
import uuid6
from sqlalchemy import text, Engine
from sqlalchemy.exc import SQLAlchemyError

from core.config import config
from core.id_mapper import IdMapper
from migrations.budget_years import BudgetYearMigration

logger = logging.getLogger(__name__)


class MigrationError(Exception):
    pass


def _clean(value):
    """Convert pandas NA / NaT / NaN → None for safe DB insertion"""
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


def _float(value) -> float:
    v = _clean(value)
    return float(v) if v is not None else 0.0


# Map source type IDs to target budget_transaction type enum values
_TYPE_MAP: Dict[int, str] = {
    1: "RESERVATION",
    2: "PAYMENT",
    3: "ALLOCATION",   # base budget release
    4: "ALLOCATION",   # growth fund
    5: "ALLOCATION",   # one-off fund (transfer or Finance injection)
    6: "ALLOCATION",   # additional revenue
    7: "ALLOCATION",   # rollover
}


def _is_transfer_pair(curr: Dict, nxt: Dict) -> bool:
    """
    Determine whether two rows form an inter-business transfer pair.

    Rules derived from qCaepTransferOOF CTE in usp_FinanceSummary_Get:
      - Only type 5 (ONEOFF_FUND) rows are ever paired — types 1 & 2 are
        always standalone rows linked to an EquipmentActionID.
      1. Both rows must be TransactionCAEPTypeID = 5
      2. Consecutive TransactionCAEPLogIDs  (curr_id + 1 == nxt_id)
      3. Same Narration
      4. Same CreatedBy
      5. curr.AmountDebit == nxt.AmountCredit  (and vice-versa)
      6. Not the same BusinessAccountID on both sides
    """
    if nxt is None:
        return False
    # Pairing is type-5 only (qCaepTransferOOF explicitly filters TypeID=5)
    if int(curr["TransactionCAEPTypeID"]) != 5 or int(nxt["TransactionCAEPTypeID"]) != 5:
        return False
    if int(curr["TransactionCAEPLogID"]) + 1 != int(nxt["TransactionCAEPLogID"]):
        return False
    if curr["Narration"] != nxt["Narration"]:
        return False
    if curr.get("CreatedBy") != nxt.get("CreatedBy"):
        return False
    curr_debit  = _float(curr["AmountDebit"])
    curr_credit = _float(curr["AmountCredit"])
    nxt_debit   = _float(nxt["AmountDebit"])
    nxt_credit  = _float(nxt["AmountCredit"])
    if curr_debit != nxt_credit or curr_credit != nxt_debit:
        return False
    if curr["BusinessAccountID"] == nxt["BusinessAccountID"]:
        return False
    return True


class BudgetTransactionMigration:
    """Migrates tblTransactionCAEPLog → budget_transactions."""

    SOURCE_TABLE = "tblTransactionCAEPLog"
    TARGET_TABLE = "budget_transactions"

    def __init__(
        self,
        source_engine: Engine,
        target_engine: Engine,
        id_mapper: IdMapper,
        budget_year_migration: BudgetYearMigration,
    ):
        self.source_engine = source_engine
        self.target_engine = target_engine
        self.id_mapper = id_mapper
        self.budget_year_migration = budget_year_migration
        self.provider_cache: Dict[str, str] = {}

    # ------------------------------------------------------------------
    # Lookups
    # ------------------------------------------------------------------

    def _load_lookups(self):
        self.provider_cache = self.id_mapper.get_all("tblBusiness")
        self.budget_year_migration.load_ranges()
        logger.info(f"Loaded {len(self.provider_cache)} provider mappings")

    # ------------------------------------------------------------------
    # Extract
    # ------------------------------------------------------------------

    def _extract(self) -> List[Dict[str, Any]]:
        logger.info("Extracting transaction log from SQL Server...")
        query = """
            SELECT
                TransactionCAEPLogID,
                TransactionCAEPTypeID,
                BusinessAccountID,
                EquipmentActionID,
                AmountCredit,
                AmountDebit,
                Narration,
                CreatedBy,
                DateCreated
            FROM dbo.tblTransactionCAEPLog
            ORDER BY TransactionCAEPLogID;
        """
        try:
            df = pd.read_sql(query, self.source_engine)
            logger.info(f"✓ Extracted {len(df)} transaction rows from source")
            return df.to_dict(orient="records")
        except SQLAlchemyError as e:
            raise MigrationError(f"Extraction failed: {e}") from e

    # ------------------------------------------------------------------
    # Transform
    # ------------------------------------------------------------------

    def _build_record(
        self,
        ref_num: int,
        tx_date,
        budget_year_id: str,
        tx_type: str,
        amount: float,
        from_provider: Optional[str],
        to_provider: Optional[str],
        description: Optional[str],
        metadata: dict,
    ) -> Dict[str, Any]:
        d = tx_date.date() if hasattr(tx_date, "date") else tx_date
        now = datetime.utcnow()
        return {
            "id":                       str(uuid6.uuid7()),
            "budget_year_id":           budget_year_id,
            "budget_allocation_id":     None,
            "budget_reservation_id":    None,
            "from_service_provider_id": from_provider,
            "to_service_provider_id":   to_provider,
            "amount":                   amount,
            "ref_num":                  ref_num,
            "description":              _clean(description),
            "metadata":                 json.dumps(metadata),
            "type":                     tx_type,
            "is_system_added":          True,
            "effective_from_date":      d,
            "transaction_at":           d,
            "created_at":               now,
            "updated_at":               now,
            "creator_user_id":          None,
        }

    def _transform(self, rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        logger.info("Transforming transaction records...")
        records: List[Dict[str, Any]] = []
        skipped = 0
        i, total = 0, len(rows)

        while i < total:
            curr = rows[i]
            nxt  = rows[i + 1] if i + 1 < total else None

            tx_date         = curr["DateCreated"]
            budget_year_id  = self.budget_year_migration.resolve_or_create(tx_date)
            legacy_type     = int(curr["TransactionCAEPTypeID"])
            tx_type         = _TYPE_MAP.get(legacy_type, "ALLOCATION")
            provider_id     = self.provider_cache.get(str(curr["BusinessAccountID"]))
            curr_ref        = int(curr["TransactionCAEPLogID"])
            equip_action_id = _clean(curr.get("EquipmentActionID"))

            # ── Type 5 inter-business transfer (paired rows) ─────────────────
            if _is_transfer_pair(curr, nxt):
                sender_id   = self.provider_cache.get(str(curr["BusinessAccountID"]))
                receiver_id = self.provider_cache.get(str(nxt["BusinessAccountID"]))
                amount      = _float(curr["AmountDebit"])
                records.append(self._build_record(
                    ref_num       = int(curr["TransactionCAEPLogID"]),
                    tx_date       = tx_date,
                    budget_year_id= budget_year_id,
                    tx_type       = "ALLOCATION",
                    amount        = amount,
                    from_provider = sender_id,
                    to_provider   = receiver_id,
                    description   = curr["Narration"],
                    metadata      = {
                        "legacy_type_id": legacy_type,
                        "legacy_type_name": "ONEOFF_FUND_TRANSFER",
                        "paired_log_ids": [
                            int(curr["TransactionCAEPLogID"]),
                            int(nxt["TransactionCAEPLogID"]),
                        ],
                        "strategy": "collapsed_transfer_pair",
                    },
                ))
                i += 2
                continue

            # ── Type 1 (COMMITTED / RESERVATION) ─────────────────────────────
            if legacy_type == 1:
                debit  = _float(curr["AmountDebit"])
                credit = _float(curr["AmountCredit"])
                amount = debit if debit > 0 else credit
                # if amount == 0:
                #     skipped += 1; i += 1; continue
                records.append(self._build_record(
                    ref_num        = curr_ref,
                    tx_date        = tx_date,
                    budget_year_id = budget_year_id,
                    tx_type        = "RESERVATION",
                    amount         = amount,
                    from_provider  = provider_id if debit > 0 else None,
                    to_provider    = None if debit > 0 else provider_id,
                    description    = curr["Narration"],
                    metadata       = {
                        "legacy_type_id":      1,
                        "legacy_type_name":    "COMMITTED",
                        "equipment_action_id": equip_action_id,
                        "direction":           "debit" if debit > 0 else "credit_release",
                        "strategy":            "standalone",
                    },
                ))
                i += 1
                continue

            # ── Type 2 (INV_PAYM / PAYMENT) ──────────────────────────────────
            if legacy_type == 2:
                debit  = _float(curr["AmountDebit"])
                credit = _float(curr["AmountCredit"])
                amount = debit if debit > 0 else credit
                # if amount == 0:
                #     skipped += 1; i += 1; continue
                records.append(self._build_record(
                    ref_num        = curr_ref,
                    tx_date        = tx_date,
                    budget_year_id = budget_year_id,
                    tx_type        = "PAYMENT",
                    amount         = amount,
                    from_provider  = provider_id if debit > 0 else None,
                    to_provider    = None if debit > 0 else provider_id,
                    description    = curr["Narration"],
                    metadata       = {
                        "legacy_type_id":      2,
                        "legacy_type_name":    "INV_PAYM",
                        "equipment_action_id": equip_action_id,
                        "direction":           "debit" if debit > 0 else "credit_reversal",
                        "strategy":            "standalone",
                    },
                ))
                i += 1
                continue

            # ── Types 3,4,5(Finance),6,7 (budget injections / rollovers) ──────
            _INJECTION_NAMES = {
                3: "BASE_BUDGET", 4: "GROWTH_FUND", 5: "ONEOFF_FUND_FINANCE",
                6: "ADDITIONAL_REVENUE", 7: "ROLL_OVER",
            }
            credit = _float(curr["AmountCredit"])
            debit  = _float(curr["AmountDebit"])
            amount = credit if credit > 0 else debit
            if amount == 0:
                skipped += 1; i += 1; continue
            records.append(self._build_record(
                ref_num        = curr_ref,
                tx_date        = tx_date,
                budget_year_id = budget_year_id,
                tx_type        = "ALLOCATION",
                amount         = amount,
                from_provider  = None if credit > 0 else provider_id,
                to_provider    = provider_id if credit > 0 else None,
                description    = curr["Narration"],
                metadata       = {
                    "legacy_type_id":   legacy_type,
                    "legacy_type_name": _INJECTION_NAMES.get(legacy_type, "UNKNOWN"),
                    "direction":        "credit" if credit > 0 else "debit_adjustment",
                    "strategy":         "standalone",
                },
            ))
            i += 1

        logger.info(
            f"✓ Transformed {len(records)} transaction records "
            f"({skipped} zero-amount rows skipped)"
        )
        return records

    # ------------------------------------------------------------------
    # Load
    # ------------------------------------------------------------------

    def _load(self, records: List[Dict[str, Any]]):
        if config.DRY_RUN:
            logger.info(f"[DRY RUN] Would insert {len(records)} budget transactions")
            return

        stmt = text("""
            INSERT INTO budget_transactions (
                id, budget_year_id, budget_allocation_id, budget_reservation_id,
                from_service_provider_id, to_service_provider_id,
                amount, ref_num, description, metadata, type, is_system_added,
                effective_from_date, transaction_at, created_at, updated_at, creator_user_id
            ) VALUES (
                :id, :budget_year_id, :budget_allocation_id, :budget_reservation_id,
                :from_service_provider_id, :to_service_provider_id,
                :amount, :ref_num, :description, :metadata, :type, :is_system_added,
                :effective_from_date, :transaction_at, :created_at, :updated_at, :creator_user_id
            ) ON CONFLICT (ref_num) DO NOTHING;
        """)

        total = len(records)
        for start in range(0, total, config.BATCH_SIZE):
            batch = records[start : start + config.BATCH_SIZE]
            try:
                with self.target_engine.begin() as conn:
                    for rec in batch:
                        conn.execute(stmt, rec)
                logger.info(
                    f"✓ Committed batch {start // config.BATCH_SIZE + 1} "
                    f"({start + len(batch)}/{total})"
                )
            except SQLAlchemyError as e:
                logger.error(f"Batch failed at index {start}: {e}")
                if not config.CONTINUE_ON_ERROR:
                    raise MigrationError("Transaction load aborted") from e

    # ------------------------------------------------------------------
    # Pipeline
    # ------------------------------------------------------------------

    def run(self) -> bool:
        logger.info("=" * 70)
        logger.info("Starting Budget Transaction Migration")
        logger.info("=" * 70)
        try:
            self._load_lookups()
            rows = self._extract()
            if not rows:
                logger.warning("No transaction rows found — nothing to migrate")
                return True
            records = self._transform(rows)
            self._load(records)
            logger.info("✓ Budget Transaction migration complete")
            return True
        except Exception as e:
            logger.error(f"Budget Transaction migration failed: {e}", exc_info=True)
            return False



class BudgetTransactionMigration:
    """
    Migrates tblTransactionCAEPLog → budget_transactions.

    Key behaviours:
    - Collapses paired type-5 debit/credit rows into a single ALLOCATION transfer.
    - Auto-generates a budget_year row (and id_map entry) for any transaction
      date that falls outside existing budget year ranges.
    - Resolves legacy BusinessAccountID → service_provider UUID via id_map.
    """

    SOURCE_TABLE = "tblTransactionCAEPLog"
    TARGET_TABLE = "budget_transactions"

    def __init__(
        self,
        source_engine: Engine,
        target_engine: Engine,
        id_mapper: IdMapper,
        budget_year_migration: BudgetYearMigration,
    ):
        self.source_engine = source_engine
        self.target_engine = target_engine
        self.id_mapper = id_mapper
        self.budget_year_migration = budget_year_migration
        self.provider_cache: Dict[str, str] = {}

    # ------------------------------------------------------------------
    # Lookups
    # ------------------------------------------------------------------

    def _load_lookups(self):
        """Load provider ID mappings and budget year ranges."""
        self.provider_cache = self.id_mapper.get_all("tblBusiness")
        self.budget_year_migration.load_ranges()
        logger.info(f"Loaded {len(self.provider_cache)} provider mappings")

    # ------------------------------------------------------------------
    # Extract
    # ------------------------------------------------------------------

    def _extract(self) -> List[Dict[str, Any]]:
        logger.info("Extracting transaction log from SQL Server...")
        query = """
            SELECT
                TransactionCAEPLogID,
                TransactionCAEPTypeID,
                BusinessAccountID,
                AmountCredit,
                AmountDebit,
                Narration,
                DateCreated
            FROM dbo.tblTransactionCAEPLog
            ORDER BY TransactionCAEPLogID;
        """
        try:
            df = pd.read_sql(query, self.source_engine)
            logger.info(f"✓ Extracted {len(df)} transaction rows from source")
            return df.to_dict(orient="records")
        except SQLAlchemyError as e:
            raise MigrationError(f"Extraction failed: {e}") from e

    # ------------------------------------------------------------------
    # Transform
    # ------------------------------------------------------------------

    def _transform(self, rows: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Single-pass lookahead transform:
        - Paired type-5 rows → one collapsed ALLOCATION transfer
        - All other rows → standalone record typed by TransactionCAEPTypeID
        """
        logger.info("Transforming transaction records...")
        records: List[Dict[str, Any]] = []
        i, total = 0, len(rows)

        TYPE_MAP = {1: "RESERVATION", 2: "PAYMENT"}

        while i < total:
            curr = rows[i]
            nxt = rows[i + 1] if i + 1 < total else None
            tx_date = curr["DateCreated"]
            budget_year_id = self.budget_year_migration.resolve_or_create(tx_date)
            d = tx_date.date() if hasattr(tx_date, "date") else tx_date
            now = datetime.utcnow()

            # --- Paired transfer (type 5 + type 5) ---
            is_transfer_pair = (
                nxt is not None
                and curr["TransactionCAEPTypeID"] == 5
                and nxt["TransactionCAEPTypeID"] == 5
                and curr["Narration"] == nxt["Narration"]
                and float(curr["AmountDebit"] or 0) > 0
                and float(curr["AmountDebit"] or 0) == float(nxt["AmountCredit"] or 0)
            )

            if is_transfer_pair:
                records.append({
                    "id": str(uuid6.uuid7()),
                    "budget_year_id": budget_year_id,
                    "budget_allocation_id": None,
                    "budget_reservation_id": None,
                    "from_service_provider_id": self.provider_cache.get(str(curr["BusinessAccountID"])),
                    "to_service_provider_id": self.provider_cache.get(str(nxt["BusinessAccountID"])),
                    "amount": float(curr["AmountDebit"]),
                    "ref_num": int(curr["TransactionCAEPLogID"]),
                    "description": _clean(curr["Narration"]),
                    "metadata": json.dumps({
                        "legacy_type_id": 5,
                        "paired_log_ids": [curr["TransactionCAEPLogID"], nxt["TransactionCAEPLogID"]],
                        "strategy": "collapsed_transfer_pair",
                    }),
                    "type": "ALLOCATION",
                    "is_system_added": True,
                    "effective_from_date": d,
                    "transaction_at": d,
                    "created_at": now,
                    "updated_at": now,
                    "creator_user_id": None,
                })
                i += 2
            else:
                # --- Standalone record ---
                debit = float(curr["AmountDebit"] or 0)
                credit = float(curr["AmountCredit"] or 0)
                is_debit = debit > 0
                amount = debit if is_debit else credit
                legacy_type = curr["TransactionCAEPTypeID"]
                tx_type = TYPE_MAP.get(legacy_type, "ALLOCATION")
                provider = self.provider_cache.get(str(curr["BusinessAccountID"]))

                records.append({
                    "id": str(uuid6.uuid7()),
                    "budget_year_id": budget_year_id,
                    "budget_allocation_id": None,
                    "budget_reservation_id": None,
                    "from_service_provider_id": provider if is_debit else None,
                    "to_service_provider_id": None if is_debit else provider,
                    "amount": amount,
                    "ref_num": int(curr["TransactionCAEPLogID"]),
                    "description": _clean(curr["Narration"]),
                    "metadata": json.dumps({
                        "legacy_type_id": legacy_type,
                        "direction": "debit" if is_debit else "credit",
                        "strategy": "standalone",
                    }),
                    "type": tx_type,
                    "is_system_added": True,
                    "effective_from_date": d,
                    "transaction_at": d,
                    "created_at": now,
                    "updated_at": now,
                    "creator_user_id": None,
                })
                i += 1

        logger.info(f"✓ Transformed {len(records)} transaction records")
        return records

    # ------------------------------------------------------------------
    # Load
    # ------------------------------------------------------------------

    def _load(self, records: List[Dict[str, Any]]):
        if config.DRY_RUN:
            logger.info(f"[DRY RUN] Would insert {len(records)} budget transactions")
            return

        stmt = text("""
            INSERT INTO budget_transactions (
                id, budget_year_id, budget_allocation_id, budget_reservation_id,
                from_service_provider_id, to_service_provider_id,
                amount, ref_num, description, metadata, type, is_system_added,
                effective_from_date, transaction_at, created_at, updated_at, creator_user_id
            ) VALUES (
                :id, :budget_year_id, :budget_allocation_id, :budget_reservation_id,
                :from_service_provider_id, :to_service_provider_id,
                :amount, :ref_num, :description, :metadata, :type, :is_system_added,
                :effective_from_date, :transaction_at, :created_at, :updated_at, :creator_user_id
            ) ON CONFLICT (ref_num) DO NOTHING;
        """)

        total = len(records)
        for start in range(0, total, config.BATCH_SIZE):
            batch = records[start : start + config.BATCH_SIZE]
            try:
                with self.target_engine.begin() as conn:
                    for rec in batch:
                        conn.execute(stmt, rec)
                logger.info(
                    f"✓ Committed batch {start // config.BATCH_SIZE + 1} "
                    f"({start + len(batch)}/{total})"
                )
            except SQLAlchemyError as e:
                logger.error(f"Batch failed at index {start}: {e}")
                if not config.CONTINUE_ON_ERROR:
                    raise MigrationError("Transaction load aborted") from e

    # ------------------------------------------------------------------
    # Pipeline
    # ------------------------------------------------------------------

    def run(self) -> bool:
        logger.info("=" * 70)
        logger.info("Starting Budget Transaction Migration")
        logger.info("=" * 70)
        try:
            self._load_lookups()
            rows = self._extract()
            if not rows:
                logger.warning("No transaction rows found — nothing to migrate")
                return True
            records = self._transform(rows)
            self._load(records)
            logger.info("✓ Budget Transaction migration complete")
            return True
        except Exception as e:
            logger.error(f"Budget Transaction migration failed: {e}", exc_info=True)
            return False
