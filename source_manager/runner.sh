#!/bin/bash

set -e

# Drop and recreate database B
psql -h $PG_B_HOST -U $PG_B_USER -c "DROP DATABASE IF EXISTS ${PG_B_DB};"
psql -h $PG_B_HOST -U $PG_B_USER -c "CREATE DATABASE ${PG_B_DB};"

# Run dump
pg_dump \
  --dbname="postgresql://${PG_A_USER}:${PG_A_PASS}@${PG_A_HOST}:5432/${PG_A_DB}" \
  --format=custom \
| pg_restore \
    --dbname="postgresql://${PG_B_USER}:${PG_B_PASS}@${PG_B_HOST}:5432/${PG_B_DB}"