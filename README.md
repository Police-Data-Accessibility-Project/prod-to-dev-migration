# prod-to-dev-migration
Regularly migrates production database and schema to the Stage and v2 Prod Databases

## How it works

### In the scripts
For Stage the following actions are performed:
1. Dump the production database (all data for Stage)
2. Rebuild the database from the given dump file
3. Create a database user for the database with CRUD permissions

### In Jenkins

This repository is cloned within the Automation Manager droplet. It will sync the production database environment to the stage database environment on a daily basis.

## Environment Setup
It requires the following environment variables to be set:

* PROD_DB_CONN_STRING: The connection string for the production database, used to dump the database
* STG_ADMIN_DB_CONN_STRING: The connection string for the admin database for the stage, used to create the database
* STG_TARGET_DB_CONN_STRING: The connection string for the target database for the stage, used to restore the dump
* STG_DB_USER: The database user with CRUD permissions to be created for the stage database
* STG_DB_PASSWORD: The password for the database user with CRUD permissions to be created for the stage database
* TEST_APP_USER_API_KEY: The API key for the test user
* TEST_APP_USER_EMAIL: The email for the test user
* TEST_APP_USER_PASSWORD: The password for the test user

## Usage

To set up the repository to properly run the associated operation, perform the following actions:

```bash
chmod +x *
docker build -t prod-migration .
docker run -it prod-migration
./stg_migration_runner.sh
```