#!/bin/bash
# This script will dump the production database to a .sql file in the current
# directory, with options to either dump the entire database or just the schema.
PROD_DB_CONN_STRING=$1
SCHEMA_ONLY=$2

# Change directory to the location of the script
cd "$(dirname "$0")"

# If SCHEMA_ONLY is not set, then dump the entire database.
if [[ -z "$SCHEMA_ONLY" ]]; then
  echo "Dumping production database..."
  DUMP_FILE="prod_dump.sql"
  pg_dump "$PROD_DB_CONN_STRING" > $DUMP_FILE
else
  echo "Dumping production schema..."
  DUMP_FILE="prod_schema_dump.sql"
  pg_dump "$PROD_DB_CONN_STRING" --schema-only --no-owner --no-acl > $DUMP_FILE
fi