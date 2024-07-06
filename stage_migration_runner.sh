#!/bin/bash

# Dump and rebuild the stage database from production
./dump_prod.sh $PROD_DB_CONN_STRING

chmod +x rebuild_db.py

python3 rebuild_db.py $STG_ADMIN_DB_CONN_STRING $STG_TARGET_DB_CONN_STRING 'prod.dump' $STG_TARGET_DB

./create_db_user.sh $STG_TARGET_DB_CONN_STRING $STG_DB_USER $STG_DB_PASSWORD $STG_TARGET_DB