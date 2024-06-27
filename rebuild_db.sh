#!/bin/bash
# This script will tear down and rebuild the given database
# utilizing the provided dump sql file.

ADMIN_DB_CONN_STRING=$1
DUMP_FILE=$2

# Change directory to the location of the script
cd "$(dirname "$0")"

echo "Dropping all connections to the database..."
psql -d $ADMIN_DB_CONN_STRING -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = 'pdap_dev_db' AND pid <> pg_backend_pid();"

echo "Dropping the database..."
psql -d $ADMIN_DB_CONN_STRING -c "DROP DATABASE IF EXISTS pdap_dev_db;"

echo "Creating database..."
psql -d $ADMIN_DB_CONN_STRING -c "CREATE DATABASE pdap_dev_db;"

echo "Restoring dump to database..."
psql $ADMIN_DB_CONN_STRING < $DUMP_FILE

echo "Adding development schemas to database..."
psql $ADMIN_DB_CONN_STRING < dev_scripts.sql
