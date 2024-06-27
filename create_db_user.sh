
# This script will create a user in the given database
# providing CRUD and sequence privileges to the user.
ADMIN_DB_CONN_STRING=$1
DEV_DB_USER=$2
DEV_DB_PASSWORD=$3

echo "Creating or updating dev user..."
psql -d $ADMIN_DB_CONN_STRING -c "DO \$\$
BEGIN
   IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DEV_DB_USER') THEN
      ALTER ROLE $DEV_DB_USER WITH LOGIN PASSWORD '$DEV_DB_PASSWORD';
   ELSE
      CREATE ROLE $DEV_DB_USER LOGIN PASSWORD '$DEV_DB_PASSWORD';
   END IF;
END
\$\$;"


echo "Granting CRUD privileges to dev user..."
psql -d $ADMIN_DB_CONN_STRING -c "GRANT CONNECT ON DATABASE pdap_dev_db TO $DEV_DB_USER;"
psql -d $ADMIN_DB_CONN_STRING -c "GRANT USAGE ON SCHEMA public TO $DEV_DB_USER;"
psql -d $ADMIN_DB_CONN_STRING -c "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $DEV_DB_USER;"
psql -d $ADMIN_DB_CONN_STRING -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $DEV_DB_USER;"

echo "Granting necessary sequence privileges to dev user..."
psql -d $ADMIN_DB_CONN_STRING -c "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $DEV_DB_USER;"
psql -d $ADMIN_DB_CONN_STRING -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO $DEV_DB_USER;"
