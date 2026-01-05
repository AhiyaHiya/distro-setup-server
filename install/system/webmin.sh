#!/bin/bash

curl -o webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
sudo sh webmin-setup-repo.sh

sudo apt update
sudo apt install --install-recommends webmin
sudo systemctl status webmin

