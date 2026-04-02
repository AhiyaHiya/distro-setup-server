#!/bin/bash

set -e

sudo timedatectl set-timezone America/Phoenix
echo "Timezone set to America/Phoenix"
date

echo "Enabling NTP synchronization"
sudo timedatectl set-ntp on
echo "NTP synchronization enabled"
timedatectl status
