#!/bin/bash

# This script will install the required dependencies
./apt.postgresql.org.sh -y
apt-get update
apt-get install postgresql-15 postgresql-client-15 -y
apt-get install software-properties-common -y
apt-get install curl -y
curl https://pyenv.run | bash

# Add pyenv to PATH
PATH="/root/.pyenv/bin:$PATH"
echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc

#add-apt-repository ppa:deadsnakes/ppa -y
#apt-get install python3.11 -y
#python3 -m ensurepip
pip install -r requirements.txt
