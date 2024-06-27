#!/bin/bash
# This script will tear down and rebuild the given database
# utilizing the provided dump sql file.

ADMIN_DB_CONN_STRING=$1
DUMP_FILE=$2

TARGET_DB=pdap_dev_db

# Change directory to the location of the script
cd "$(dirname "$0")"

echo "Dropping all connections to the $TARGET_DB database..."
psql -d $ADMIN_DB_CONN_STRING -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$TARGET_DB' AND pid <> pg_backend_pid();"

CONNECTIONS=$(psql -d $ADMIN_DB_CONN_STRING -c "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$TARGET_DB';")

# Verify if there are no active connections
if [ "$CONNECTIONS" -eq 0 ]; then
  echo "All connections to the database '$TARGET_DB' have been successfully terminated."
else
  echo "There are still active connections to the database '$TARGET_DB'."
fi

echo "Dropping the database..."
psql -d $ADMIN_DB_CONN_STRING -c "DROP DATABASE IF EXISTS $TARGET_DB;"

echo "Creating database..."
psql -d $ADMIN_DB_CONN_STRING -c "CREATE DATABASE $TARGET_DB;"

echo "Restoring dump to database..."
psql $ADMIN_DB_CONN_STRING < $DUMP_FILE

echo "Adding development schemas to database..."
psql $ADMIN_DB_CONN_STRING < dev_scripts.sql
