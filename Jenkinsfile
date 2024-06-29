#!/usr/bin/env groovy

pipeline {

    agent {
        dockerfile true
    }

    stages {
        stage('Build') {
            steps {
                echo 'Building...'
                sh './setup.sh'
            }
        }
        stage('Migrate Prod to Sandbox') {
            steps {
                echo 'Migrating Prod to Sandbox...'
                sh './sandbox_migration_runner.sh'
            }
        }
    }
}