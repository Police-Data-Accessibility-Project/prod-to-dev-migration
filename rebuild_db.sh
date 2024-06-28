#!/bin/bash
# This script will tear down and rebuild the given database
# utilizing the provided dump sql file.


DEFAULT_DB=defaultdb

ADMIN_DB_CONN_STRING=$1
STG_DB_CONN_STRING=$2
DUMP_FILE=$3
TARGET_DB=$4

# Change directory to the location of the script
cd "$(dirname "$0")"

echo "Dropping all connections to the $TARGET_DB database..."
psql -d "$ADMIN_DB_CONN_STRING" -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$TARGET_DB' AND pid <> pg_backend_pid();"

CONNECTIONS=$(psql "$ADMIN_DB_CONN_STRING" -t -c "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$TARGET_DB';" | tr -d '[:space:]')

# Verify if there are no active connections
if [ "$CONNECTIONS" -eq 0 ]; then
  echo "All connections to the database '$TARGET_DB' have been successfully terminated."
else
  echo "There are still active connections to the database '$TARGET_DB'. Cancelling"
  exit
fi

echo "Dropping the database..."
psql -d $ADMIN_DB_CONN_STRING -c "DROP DATABASE IF EXISTS $TARGET_DB;"

# Check if the database still exists
DB_EXISTS=$(psql "$ADMIN_DB_CONN_STRING" -t -c "SELECT 1 FROM pg_database WHERE datname = '$TARGET_DB';" | tr -d '[:space:]')

# Verify if the database has been dropped
if [ -z "$DB_EXISTS" ]; then
  echo "The database '$TARGET_DB' has been successfully dropped."
else
  echo "Failed to drop the database '$TARGET_DB'."
  exit
fi

echo "Creating database..."
psql -d "$ADMIN_DB_CONN_STRING" -c "CREATE DATABASE $TARGET_DB;"

if [[ "$DUMP_FILE" =~ \.sql$ ]]; then
  echo "Restoring dump to database via psql..."
  psql "$STG_DB_CONN_STRING" < $DUMP_FILE
else
  echo "Restoring dump to database via pg_restore..."
  pg_restore --dbname="$STG_DB_CONN_STRING" -v < $DUMP_FILE
fi
echo "Adding development schemas to database..."
psql "$STG_DB_CONN_STRING" < dev_scripts.sql