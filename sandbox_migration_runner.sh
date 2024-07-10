#!/bin/bash

# Dump and rebuild the sandbox database from production
./dump_prod.sh $PROD_DB_CONN_STRING 'true'

python3 rebuild_db.py $SANDBOX_ADMIN_DB_CONN_STRING $SANDBOX_TARGET_DB_CONN_STRING 'prod_to_sandbox.sql' $SANDBOX_TARGET_DB

echo "Creating sandbox users"
echo "Creating app user"
python3 UserCreator.py --admin_db_conn_string $SANDBOX_TARGET_DB_CONN_STRING --dev_db_user $SANDBOX_DB_USER --dev_db_password $SANDBOX_DB_PASSWORD --target_db $SANDBOX_TARGET_DB
echo "Creating developer user"
python3 UserCreator.py --admin_db_conn_string $SANDBOX_TARGET_DB_CONN_STRING --dev_db_user $SANDBOX_DEV_USER --dev_db_password $SANDBOX_DEV_PASSWORD --target_db $SANDBOX_TARGET_DB --developer_privileges

python3 load_csv_data.py $SANDBOX_TARGET_DB_CONN_STRING