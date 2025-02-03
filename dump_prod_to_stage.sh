#!/bin/bash
# This script will dump the production database to a .sql file in the current
# directory, with options to either dump the entire database or just the schema.
PROD_DB_CONN_STRING=$1

# Change directory to the location of the script
cd "$(dirname "$0")"

# If SANDBOX_DUMP is not set, then dump the entire database.
echo "Dumping production database..."
DUMP_FILE="prod.dump"
pg_dump "$PROD_DB_CONN_STRING" -F c --no-owner --no-acl --exclude-table-data=public.users > $DUMP_FILE
