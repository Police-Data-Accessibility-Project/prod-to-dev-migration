#!/bin/bash

set -e

# Dump and rebuild the stage database from production
./dump_prod.sh $DUMP_DB_CONN_STRING

python3 rebuild_db.py $TARGET_ADMIN_DB_CONN_STRING $TARGET_DB_CONN_STRING 'prod.dump' $TARGET_DB

echo "Creating app user"
python3 UserCreator.py --admin_db_conn_string $TARGET_DB_CONN_STRING --dev_db_user $TARGET_DB_USER --dev_db_password $TARGET_DB_PASSWORD --target_db $TARGET_DB

python3 relation_access_permissions/upload_relation_configurations_to_db.py --connection_string $TARGET_DB_CONN_STRING