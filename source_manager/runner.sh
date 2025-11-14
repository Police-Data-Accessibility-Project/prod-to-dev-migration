#!/bin/bash

set -e

export PGPASSWORD=$PG_B_PASS
# Drop and recreate database B
# 'defaultdb' is the default database in Digital Ocean postgres and used for accessing the database
psql -h "$PG_B_HOST" -U "$PG_B_USER" -p "$PG_B_PORT" -d "defaultdb" <<SQL
-- Terminate all other connections to the target DB
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '${PG_B_DB}'
  AND pid <> pg_backend_pid();

-- Now it's safe to drop & recreate
DROP DATABASE IF EXISTS "${PG_B_DB}";
CREATE DATABASE "${PG_B_DB}";
SQL

# Run dump
pg_dump \
  --dbname="postgresql://${PG_A_USER}:${PG_A_PASS}@${PG_A_HOST}:${PG_A_PORT}/${PG_A_DB}" \
  --format=custom \
| pg_restore \
    --dbname="postgresql://${PG_B_USER}:${PG_B_PASS}@${PG_B_HOST}:${PG_B_PORT}/${PG_B_DB}" \
    --no-owner \
    --no-privileges