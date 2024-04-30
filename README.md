# prod-to-dev-migration
Regularly migrates production database and schema to development database

This repository will sync the production database environment to the dev database environment on a daily basis.

It requires the following values defined in a .env file in the root repository:

* PROD_DB_CONN_STRING: A connection string to the prod database for user "prod_dump_agent"
* DEV_ADMIN_DB_CONN_STRING: A connection string to the development database at database "defaultdb" for user "doadmin" must be a separate string from DEV_DB_CONN_STRING to enable closing and rebuilding the "pdab_dev_db" database.
* DEV_DB_CONN_STRING: A connection string to the development database at database "pdap_dev_db" for user "doadmin"
