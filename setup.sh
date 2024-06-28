#!/bin/bash
# Change directory to the location of the script
cd "$(dirname "$0")"

./apt.postgresql.org.sh -y
apt-get update
apt-get install postgresql-15 postgresql-client-15 -y
apt-get install software-properties-common -y
add-apt-repository ppa:deadsnakes/ppa -y
apt-get install python3.11 -y
apt-get install python3.11-venv -y
python3 -m venv migration_venv
source migration_venv/bin/activate
pip install -r requirements.txt
