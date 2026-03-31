#!/bin/bash
set -e

sudo adduser arm
sudo usermod -aG docker arm

# Log in as arm user
su - arm

mkdir -p ~/config ~/logs ~/media ~/music

git clone https://github.com/automatic-ripping-machine/automatic-ripping-machine.git
cd automatic-ripping-machine

chmod +x docker-setup.sh

sudo ./docker-setup.sh

sudo chown -R YOUR_UID:YOUR_GID /home/arm/config /home/arm/media /home/arm/music /home/arm/logs
