#!/bin/bash

set -e

# Dump and rebuild the stage database from production
./dump_prod_to_stage.sh $PROD_DB_CONN_STRING


python3 rebuild_db.py $STG_ADMIN_DB_CONN_STRING $STG_TARGET_DB_CONN_STRING 'prod.dump' $STG_TARGET_DB

echo "Cleaning user data"
python3 DataCleaner.py --admin_db_conn_string $STG_TARGET_DB_CONN_STRING

echo "Creating app user"
python3 DBUserCreator.py --admin_db_conn_string $STG_TARGET_DB_CONN_STRING --dev_db_user $STG_DB_USER --dev_db_password $STG_DB_PASSWORD --target_db $STG_TARGET_DB

echo "Creating user with write permissions"
python3 DBUserCreator.py --admin_db_conn_string $STG_TARGET_DB_CONN_STRING --dev_db_user $STG_DB_USER_WRITE --dev_db_password $STG_DB_PASSWORD_WRITE --target_db $STG_TARGET_DB


echo "Creating test user"
python3 AppUserCreator.py --admin_db_conn_string $STG_TARGET_DB_CONN_STRING --user_email $TEST_APP_USER_EMAIL --user_password $TEST_APP_USER_PASSWORD --api_key $TEST_APP_USER_API_KEY

python3 relation_access_permissions/upload_relation_configurations_to_db.py --connection_string $STG_TARGET_DB_CONN_STRING