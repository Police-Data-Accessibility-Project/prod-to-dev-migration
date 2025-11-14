#!/bin/bash

set -e

export PGPASSWORD=$PG_B_PASS
# Drop and recreate database B
# 'defaultdb' is the default database in Digital Ocean postgres and used for accessing the database
psql -h $PG_B_HOST -U $PG_B_USER -p $PG_B_PORT -d "defaultdb" -c "DROP DATABASE IF EXISTS ${PG_B_DB};"
psql -h $PG_B_HOST -U $PG_B_USER -p $PG_B_PORT -d "defaultdb" -c "CREATE DATABASE ${PG_B_DB};"

# Run dump
pg_dump \
  --dbname="postgresql://${PG_A_USER}:${PG_A_PASS}@${PG_A_HOST}:${PG_A_PORT}/${PG_A_DB}" \
  --format=custom \
| pg_restore \
    --dbname="postgresql://${PG_B_USER}:${PG_B_PASS}@${PG_B_HOST}:${PG_B_PORT}/${PG_B_DB}"