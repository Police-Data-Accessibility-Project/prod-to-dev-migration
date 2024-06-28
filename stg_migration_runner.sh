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
./rebuild_db.sh $STG_ADMIN_DB_CONN_STRING $STG_TARGET_DB_CONN_STRING 'prod.dump' $STG_TARGET_DB
./create_db_user.sh $STG_ADMIN_DB_CONN_STRING $STG_DB_USER $STG_DB_PASSWORD $STG_TARGET_DB