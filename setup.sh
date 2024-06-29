#!/bin/bash

# This script will install the required dependencies
./apt.postgresql.org.sh -y
apt-get update
apt-get install postgresql-15 postgresql-client-15 -y
apt-get install software-properties-common -y
add-apt-repository ppa:deadsnakes/ppa -y
apt-get install python3.11 -y
pip3 install -r requirements.txt
