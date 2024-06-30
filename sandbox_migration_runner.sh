#!/bin/bash

# Dump and rebuild the sandbox database from production
./dump_prod.sh $PROD_DB_CONN_STRING 'true'
./rebuild_db.sh $SANDBOX_ADMIN_DB_CONN_STRING $SANDBOX_TARGET_DB_CONN_STRING 'prod_to_sandbox.sql' $SANDBOX_TARGET_DB
./create_db_user.sh $SANDBOX_ADMIN_DB_CONN_STRING $SANDBOX_DB_USER $SANDBOX_DB_PASSWORD $SANDBOX_TARGET_DB
#source venv/bin/activate
python3 load_csv_data.py $SANDBOX_TARGET_DB_CONN_STRING