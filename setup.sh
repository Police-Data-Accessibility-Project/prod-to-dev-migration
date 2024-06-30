#!/bin/bash

# This script will install the required dependencies
./apt.postgresql.org.sh -y
apt-get update
apt-get install postgresql-15 postgresql-client-15 -y
