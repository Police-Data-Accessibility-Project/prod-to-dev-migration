#!/bin/bash

# Change directory to the location of the script
cd "$(dirname "$0")"

# Load environment variables
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

./setup.sh

# Dump and rebuild the sandbox database from production
./dump_prod.sh $PROD_DB_CONN_STRING 'true'
./rebuild_db.sh $SANDBOX_ADMIN_DB_CONN_STRING $SANDBOX_TARGET_DB_CONN_STRING 'prod_schema.dump' $SANDBOX_TARGET_DB
./create_db_user.sh $SANDBOX_ADMIN_DB_CONN_STRING $SANDBOX_DB_USER $SANDBOX_DB_PASSWORD
