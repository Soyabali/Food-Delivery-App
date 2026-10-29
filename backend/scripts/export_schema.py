"""Regenerate database/schema.sql from a migrated database.

Usage (from backend/, with the database already at `alembic upgrade head`):

    pg_dump --schema-only --no-owner --no-privileges --exclude-table=alembic_version \
        -d apna_food -f database/schema_raw.sql
    python scripts/export_schema.py
"""

import re
from pathlib import Path

HEADER = r"""-- =====================================================================
-- Apna Food - PostgreSQL schema (generated, do not edit by hand)
--
-- Source of truth: SQLAlchemy models in backend/app/models and Alembic
-- migrations in backend/alembic/versions. Regenerate with
-- scripts/export_schema.py (see its docstring).
--
-- Normal setup uses Alembic (`alembic upgrade head`). Use this file to read
-- the schema or to create it manually in pgAdmin / psql.
-- =====================================================================
"""

NOISE = ("SET ", "SELECT pg_catalog.set_config", "\\restrict", "\\unrestrict", "-- Dumped")


def main() -> None:
    folder = Path(__file__).resolve().parent.parent / "database"
    raw_file = folder / "schema_raw.sql"
    lines = [line for line in raw_file.read_text(encoding="utf-8").splitlines() if not line.startswith(NOISE)]
    body = re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()
    (folder / "schema.sql").write_text(HEADER + "\n" + body + "\n", encoding="utf-8")
    raw_file.unlink()
    tables = sum(1 for line in body.splitlines() if line.startswith("CREATE TABLE"))
    print(f"{tables} tables, {body.count('FOREIGN KEY')} foreign keys, {body.count('CHECK (')} checks")


if __name__ == "__main__":
    main()
