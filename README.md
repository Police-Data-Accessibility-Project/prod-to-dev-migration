# prod-to-dev-migration
Regularly migrates production database and schema to the Stage and Sandbox Databases

## How it works

### In the scripts
For both Stage and Sandbox, the following actions are performed:
1. Dump the production database (all data for Stage, schema and data from only some tables for Sandbox)
2. Rebuild the database from the given dump file
3. Update the database with all updates defined in the `dev_scripts.sql` file
4. Create a database user for the database with CRUD permissions

Additionally, for the Sandbox database, dummy data is added to tables whose data was not retrieved during the dump

### In Jenkins

This repository is cloned within the Automation Manager droplet. It will sync the production database environment to the stage and sandbox database environments on a daily basis.

## Environment Setup
It requires the following environment variables to be set:

* PROD_DB_CONN_STRING: The connection string for the production database, used to dump the database
* SANDBOX_ADMIN_DB_CONN_STRING: The connection string for the admin database for the sandbox, used to create the database
* SANDBOX_TARGET_DB_CONN_STRING: The connection string for the target database for the sandbox, used to restore the dump
* SANDBOX_DB_USER: The database user with CRUD permissions to be created for the sandbox database
* SANDBOX_DB_PASSWORD: The password for the database user with CRUD permissions to be created for the sandbox database
* STG_ADMIN_DB_CONN_STRING: The connection string for the admin database for the stage, used to create the database
* STG_TARGET_DB_CONN_STRING: The connection string for the target database for the stage, used to restore the dump
* STG_DB_USER: The database user with CRUD permissions to be created for the stage database
* STG_DB_PASSWORD: The password for the database user with CRUD permissions to be created for the stage database

## Usage

To set up the repository to properly run the associated operation, perform the following actions:

```bash
chmod +x *
./sandbox_migration_runner.sh
./stg_migration_runner.sh
```

## Additional Notes

In Jenkins, some actions may not be able to be performed by the default Jenkins user due to a lack of permissions. In these cases, the user will need to enter the associated droplet as an administrator and perform these actions themselves. These actions are consigned to the `setup.sh` file