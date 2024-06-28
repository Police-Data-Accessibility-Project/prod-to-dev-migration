#!/bin/bash
# This script will dump the production database to a .sql file in the current
# directory, with options to either dump the entire database or just the schema.
PROD_DB_CONN_STRING=$1
SANDBOX_DUMP=$2

# Change directory to the location of the script
cd "$(dirname "$0")"

# If SANDBOX_DUMP is not set, then dump the entire database.
if [[ -z "$SANDBOX_DUMP" ]]; then
  echo "Dumping production database..."
  DUMP_FILE="prod.dump"
  pg_dump "$PROD_DB_CONN_STRING" -Fc --no-owner --no-acl > $DUMP_FILE
else
  echo "Dumping production data for sandbox..."
  DUMP_FILE="prod_to_sandbox.sql"
  pg_dump "$PROD_DB_CONN_STRING" -Fp --schema-only --no-owner --no-acl > $DUMP_FILE
  # Additionally, dump data from most but not all tables
  pg_dump "$PROD_DB_CONN_STRING" -Fp --data-only --no-owner --no-acl -T quick_search_query_logs -T data_requests -T users -T access_tokens -T session_tokens >> $DUMP_FILE
fi