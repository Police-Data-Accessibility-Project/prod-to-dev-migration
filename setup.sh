#!/bin/bash
# Change directory to the location of the script
cd "$(dirname "$0")"

./apt.postgresql.org.sh -y
apt-get update
apt-get install postgresql-15 postgresql-client-15 -y
add-apt-repository ppa:deadsnakes/ppa
apt-get install python3.11 -y
python3 -m venv migration_venv
source migration_venv/bin/activate
pip install -r requirements.txt
