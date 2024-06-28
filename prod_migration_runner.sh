#!/bin/bash

# Change directory to the location of the script
cd "$(dirname "$0")"

# Load environment variables
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

./setup.sh

# Dump and rebuild the stage database from production
./dump_prod.sh $PROD_DB_CONN_STRING
./rebuild_db.sh $STG_ADMIN_DB_CONN_STRING 'prod_dump.sql'
./create_db_user.sh $STG_ADMIN_DB_CONN_STRING $STG_DB_USER $STG_DB_PASSWORD

# Dump and rebuild the sandbox database from stage
./dump_prod.sh $PROD_DB_CONN_STRING 'true'
./rebuild_db.sh $SANDBOX_ADMIN_DB_CONN_STRING 'prod_schema_dump.sql'
./create_db_user.sh $SANDBOX_ADMIN_DB_CONN_STRING $SANDBOX_DB_USER $SANDBOX_DB_PASSWORD