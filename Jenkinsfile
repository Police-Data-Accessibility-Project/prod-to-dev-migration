#!/usr/bin/env groovy

pipeline {

    agent {
        dockerfile {
            filename 'Dockerfile'
            args '-e PROD_DB_CONN_STRING=$PROD_DB_CONN_STRING -e SANDBOX_DB_USER=$SANDBOX_DB_USER -e SANDBOX_DB_PASSWORD=$SANDBOX_DB_PASSWORD -e SANDBOX_ADMIN_DB_CONN_STRING=$SANDBOX_ADMIN_DB_CONN_STRING -e SANDBOX_TARGET_DB=$SANDBOX_TARGET_DB -e SANDBOX_TARGET_DB_CONN_STRING=$SANDBOX_TARGET_DB_CONN_STRING'
        }
    }

    stages {
        stage('Migrate Prod to Sandbox') {
            steps {
                echo 'Migrating Prod to Sandbox...'
                sh './sandbox_migration_runner.sh'
            }
        }
    }
}