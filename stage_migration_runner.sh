#!/bin/bash

set -e

# Dump and rebuild the stage database from production
./dump_prod.sh $PROD_DB_CONN_STRING


python3 rebuild_db.py $STG_ADMIN_DB_CONN_STRING $STG_TARGET_DB_CONN_STRING 'prod.dump' $STG_TARGET_DB

echo "Creating app user"
python3 UserCreator.py --admin_db_conn_string $STG_TARGET_DB_CONN_STRING --dev_db_user $STG_DB_USER --dev_db_password $STG_DB_PASSWORD --target_db $STG_TARGET_DB

python3 relation_access_permissions/upload_relation_configurations_to_db.py ----connection_string $STG_TARGET_DB