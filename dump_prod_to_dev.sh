#!/bin/bash

# Change directory to the location of the script
cd "$(dirname "$0")"

# Load environment variables
set -a  # Automatically export all variables
source .env
set +a  # Disable auto export

# Define the path for the dump file
DUMP_FILE="prod_dump.sql"

echo "Dumping production database..."
pg_dump $PROD_DB_CONN_STRING > $DUMP_FILE

echo "Dropping all connections to the development database..."
psql -d $DEV_ADMIN_DB_CONN_STRING -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = 'pdap_dev_db' AND pid <> pg_backend_pid();"

echo "Dropping the development database..."
psql -d $DEV_ADMIN_DB_CONN_STRING -c "DROP DATABASE IF EXISTS pdap_dev_db;"

echo "Creating development database..."
psql -d $DEV_ADMIN_DB_CONN_STRING -c "CREATE DATABASE pdap_dev_db;"

echo "Restoring dump to development database..."
psql $DEV_DB_CONN_STRING < $DUMP_FILE

echo "Adding development schemas to development database..."
psql $DEV_DB_CONN_STRING < dev_scripts.sql

echo "Creating or updating dev user..."
psql -d $DEV_ADMIN_DB_CONN_STRING -c "DO \$\$
BEGIN
   IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DEV_DB_USER') THEN
      ALTER ROLE $DEV_DB_USER WITH LOGIN PASSWORD '$DEV_DB_PASSWORD';
   ELSE
      CREATE ROLE $DEV_DB_USER LOGIN PASSWORD '$DEV_DB_PASSWORD';
   END IF;
END
\$\$;"


echo "Granting CRUD privileges to dev user..."
psql -d $DEV_DB_CONN_STRING -c "GRANT CONNECT ON DATABASE pdap_dev_db TO $DEV_DB_USER;"
psql -d $DEV_DB_CONN_STRING -c "GRANT USAGE ON SCHEMA public TO $DEV_DB_USER;"
psql -d $DEV_DB_CONN_STRING -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $DEV_DB_USER;"
psql -d $DEV_DB_CONN_STRING -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $DEV_DB_USER;"

echo "Granting necessary sequence privileges to dev user..."
psql -d $DEV_DB_CONN_STRING -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $DEV_DB_USER;"
psql -d $DEV_DB_CONN_STRING -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO $DEV_DB_USER;"
