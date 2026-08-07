#!/usr/bin/env bash
# Runs all schema files in /schemas/postgres in numeric order against
# the database pointed to by $DATABASE_URL.
#
# Usage:
#   export DATABASE_URL="postgresql://user:pass@host:5432/hedge_fund_os"
#   ./scripts/db/migrate.sh
#
# This is intentionally simple for Phase 1 — a flat, idempotent-by-convention
# runner. If schema churn picks up in Phase 2+, replace with a real migration
# tool (sqitch, dbmate, or Flyway) rather than growing this script.

set -euo pipefail

if [ -z "${DATABASE_URL:-}" ]; then
  echo "ERROR: DATABASE_URL is not set." >&2
  echo 'Example: export DATABASE_URL="postgresql://user:pass@localhost:5432/hedge_fund_os"' >&2
  exit 1
fi

SCHEMA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../schemas/postgres" && pwd)"

echo "Running migrations from ${SCHEMA_DIR} against ${DATABASE_URL%%@*}@***"

for f in "${SCHEMA_DIR}"/*.sql; do
  echo "-> $(basename "$f")"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$f"
done

echo "Done."
