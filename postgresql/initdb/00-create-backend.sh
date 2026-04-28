#!/usr/bin/env bash
set -euo pipefail

# Keep backward compatibility with charts using POSTGRES_DATABASE.
TARGET_DB="${POSTGRES_DATABASE:-${POSTGRES_DB:-backend}}"

if [[ -z "${TARGET_DB}" ]]; then
  echo "No target database configured; skipping creation."
  exit 0
fi

echo "Ensuring database '${TARGET_DB}' exists"
psql -v ON_ERROR_STOP=1 \
  --username "${POSTGRES_USER}" \
  --dbname "postgres" \
  --set target_db="${TARGET_DB}" <<'EOSQL'
SELECT format('CREATE DATABASE %I', :'target_db')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'target_db')\gexec
EOSQL
