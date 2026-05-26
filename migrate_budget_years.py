"""
Budget Year Migration
Migrates tblBudget → budget_years with ID mapping
"""
import logging
from datetime import datetime, date, timedelta
from typing import List, Dict, Any

import pandas as pd
import numpy as np
import uuid6
from sqlalchemy import text, Engine

from config import config
from id_mapper import IdMapper

logger = logging.getLogger(__name__)


def _fiscal_year_bounds(d: date) -> tuple:
    """Return (start, end) for the Australian fiscal year covering d (July 1 – June 30)."""
    if d.month >= 7:
        return date(d.year, 7, 1), date(d.year + 1, 6, 30)
    return date(d.year - 1, 7, 1), date(d.year, 6, 30)


def _fy_name(start: date) -> str:
    """Format fiscal year name, e.g. start=2024-07-01 → '2024-25'"""
    return f"{start.year}-{str(start.year + 1)[-2:]}"


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


class BudgetYearMigration:
    """Migrates budget years from tblBudget and records ID mappings"""

    SOURCE_TABLE = "tblBudget"
    TARGET_TABLE = "budget_years"

    def __init__(self, source_engine: Engine, target_engine: Engine, id_mapper: IdMapper):
        self.source_engine = source_engine
        self.target_engine = target_engine
        self.id_mapper = id_mapper
        # (uuid, start_date, end_date) sorted by start_date — populated by load_ranges()
        self._ranges: list = []

    def load_ranges(self):
        """Load existing budget_year ranges from the target DB into memory."""
        with self.target_engine.connect() as conn:
            rows = conn.execute(text(
                "SELECT id, start_date, end_date FROM budget_years ORDER BY start_date"
            )).fetchall()
        self._ranges = [(str(r[0]), r[1], r[2]) for r in rows]
        logger.info(f"Loaded {len(self._ranges)} budget year ranges into cache")

    def resolve_or_create(self, tx_date) -> str:
        """
        Return the budget_year UUID whose range covers tx_date.
        If none exists, auto-generate a new budget_year row (Australian FY),
        persist it, update the in-memory cache, and return its UUID.
        """
        d: date = tx_date.date() if hasattr(tx_date, "date") else tx_date

        for year_id, start, end in self._ranges:
            if start <= d <= end:
                return year_id

        start, end = _fiscal_year_bounds(d)

        # May have been generated earlier this run
        for year_id, s, e in self._ranges:
            if s == start:
                return year_id

        new_id = str(uuid6.uuid7())
        name = _fy_name(start)
        now = datetime.utcnow()

        with self.target_engine.begin() as conn:
            conn.execute(text("""
                INSERT INTO budget_years
                    (id, name, start_date, end_date, description, total_budget,
                     is_current, is_locked, rollover_enabled, created_at, updated_at)
                VALUES
                    (:id, :name, :start_date, :end_date,
                     'Auto-generated during transaction migration', 0,
                     :is_current, :is_locked, TRUE, :now, :now)
                ON CONFLICT (name) DO NOTHING;
            """), {
                "id": new_id,
                "name": name,
                "start_date": start,
                "end_date": end,
                "is_current": start <= now.date() <= end,
                "is_locked": end < now.date(),
                "now": now,
            })

        self._ranges.append((new_id, start, end))
        self._ranges.sort(key=lambda r: r[1])
        logger.warning(f"Auto-generated budget year '{name}' ({start} → {end}) for tx date {d}")
        return new_id

    def _ensure_target_schema(self):
        """Create budget_years table if not exists"""
        with self.target_engine.begin() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS budget_years (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    name VARCHAR(255) UNIQUE NOT NULL,
                    start_date DATE NOT NULL,
                    end_date DATE NOT NULL,
                    description TEXT NULL,
                    total_budget DECIMAL(15,2) DEFAULT 0,
                    is_current BOOLEAN DEFAULT FALSE,
                    is_locked BOOLEAN DEFAULT FALSE,
                    rollover_enabled BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                    creator_user_id UUID NULL
                );
            """))
        logger.info("✓ budget_years schema verified")

    def _extract(self) -> pd.DataFrame:
        """Extract budget rows from SQL Server"""
        query = """
            SELECT
                BudgetID,
                BudgetStartDate,
                Quarter1,
                Quarter2,
                Quarter3,
                Quarter4,
                DateCreated,
                CreatedBy
            FROM dbo.tblBudget
            ORDER BY BudgetStartDate
        """
        df = pd.read_sql(query, self.source_engine)
        logger.info(f"✓ Extracted {len(df)} budget years from source")
        return df

    def _make_name(self, start_date: date) -> str:
        """Format name as 'YYYY-YY', e.g. 2024-07-01 → '2024-25'"""
        start_year = start_date.year
        end_year = (start_date + timedelta(days=365)).year
        return f"{start_year}-{str(end_year)[-2:]}"

    def _transform(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        """Transform source rows to target schema, generating UUIDs"""
        records = []
        id_mappings: Dict[str, str] = {}
        now = datetime.utcnow()
        current_year = now.year

        for _, row in df.iterrows():
            new_id = str(uuid6.uuid7())
            source_id = str(int(row['BudgetID']))

            start_date: date = pd.to_datetime(row['BudgetStartDate']).date()
            # end_date = June 30 of the following year (Australian fiscal year)
            end_date = date(start_date.year + 1, 6, 30)

            total_budget = sum(
                float(_clean(row.get(q)) or 0)
                for q in ('Quarter1', 'Quarter2', 'Quarter3', 'Quarter4')
            )

            # is_current: fiscal year that covers today
            is_current = (start_date <= now.date() <= end_date)
            # is_locked: year fully in the past
            is_locked = (end_date < now.date()) and not is_current

            records.append({
                'id': new_id,
                'name': self._make_name(start_date),
                'start_date': start_date,
                'end_date': end_date,
                'description': None,
                'total_budget': round(total_budget, 2),
                'is_current': is_current,
                'is_locked': is_locked,
                'rollover_enabled': True,
                'created_at': _clean(row.get('DateCreated')) or now,
                'updated_at': now,
                'creator_user_id': None,  # resolve from user id_map if needed
            })
            id_mappings[source_id] = new_id

        self.id_mapper.put_batch(self.SOURCE_TABLE, self.TARGET_TABLE, id_mappings)
        logger.info(f"✓ Transformed {len(records)} budget years, stored {len(id_mappings)} ID mappings")
        return records

    def _load(self, records: List[Dict[str, Any]]):
        """Insert into PostgreSQL"""
        if config.DRY_RUN:
            logger.info(f"[DRY RUN] Would insert {len(records)} budget years")
            return

        stmt = text("""
            INSERT INTO budget_years (
                id, name, start_date, end_date, description, total_budget,
                is_current, is_locked, rollover_enabled,
                created_at, updated_at, creator_user_id
            ) VALUES (
                :id, :name, :start_date, :end_date, :description, :total_budget,
                :is_current, :is_locked, :rollover_enabled,
                :created_at, :updated_at, :creator_user_id
            ) ON CONFLICT (name) DO UPDATE SET
                total_budget     = EXCLUDED.total_budget,
                is_current       = EXCLUDED.is_current,
                is_locked        = EXCLUDED.is_locked,
                rollover_enabled = EXCLUDED.rollover_enabled,
                updated_at       = EXCLUDED.updated_at;
        """)

        with self.target_engine.begin() as conn:
            for rec in records:
                conn.execute(stmt, rec)
        logger.info(f"✓ Loaded {len(records)} budget years")

    def run(self) -> bool:
        """Execute full budget year migration"""
        logger.info("=" * 70)
        logger.info("Starting Budget Year Migration (tblBudget → budget_years)")
        logger.info("=" * 70)
        try:
            self._ensure_target_schema()
            df = self._extract()
            if df.empty:
                logger.warning("No budget years to migrate")
                return True
            records = self._transform(df)
            self._load(records)
            logger.info("✓ Budget Year migration complete")
            return True
        except Exception as e:
            logger.error(f"Budget Year migration failed: {e}", exc_info=True)
            return False

