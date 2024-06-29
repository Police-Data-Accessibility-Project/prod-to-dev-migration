#!/bin/bash

# Add pyenv to PATH
PATH="/root/.pyenv/bin:$PATH"
echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc

#add-apt-repository ppa:deadsnakes/ppa -y
#apt-get install python3.11 -y
#python3 -m ensurepip
pip install -r requirements.txt
