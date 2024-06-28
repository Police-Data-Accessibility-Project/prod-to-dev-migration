#!/bin/bash
# Change directory to the location of the script
cd "$(dirname "$0")"

./apt.postgresql.org.sh -y
apt-get update
apt-get install postgresql-15 postgresql-client-15 -y
