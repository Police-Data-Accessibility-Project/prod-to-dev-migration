#!/usr/bin/env groovy

/*
This script runs both the stage migration from production
*/

pipeline {

    agent {
        dockerfile {
            filename 'Dockerfile'
            args '-e PROD_DB_CONN_STRING=$PROD_DB_CONN_STRING -e SANDBOX_DB_USER=$SANDBOX_DB_USER -e SANDBOX_DB_PASSWORD=$SANDBOX_DB_PASSWORD -e SANDBOX_ADMIN_DB_CONN_STRING=$SANDBOX_ADMIN_DB_CONN_STRING -e SANDBOX_TARGET_DB=$SANDBOX_TARGET_DB -e SANDBOX_TARGET_DB_CONN_STRING=$SANDBOX_TARGET_DB_CONN_STRING -e STG_ADMIN_DB_CONN_STRING=$STG_ADMIN_DB_CONN_STRING -e STG_TARGET_DB=$STG_TARGET_DB -e STG_TARGET_DB_CONN_STRING=$STG_TARGET_DB_CONN_STRING -e STG_DB_USER=$STG_DB_USER -e STG_DB_PASSWORD=$STG_DB_PASSWORD -e SANDBOX_DEV_USER=$SANDBOX_DEV_USER -e SANDBOX_DEV_PASSWORD=$SANDBOX_DEV_PASSWORD -e TEST_APP_USER_EMAIL=$TEST_APP_USER_EMAIL -e TEST_APP_USER_PASSWORD=$TEST_APP_USER_PASSWORD'
        }
    }

    stages {
        stage('Migrate Prod to Stage') {
            steps {
                echo 'Migrating Prod to Stage...'
                sh 'chmod +x *'
                sh './stage_migration_runner.sh'
            }
        }
    }
}