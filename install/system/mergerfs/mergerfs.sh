#!/bin/bash

# Post install commands
# sudo mkdir -p /mnt/8TbHd /mnt/8TbHd_1 /mnt/8TbHd_2 /mnt/8TbHd_Parity /mnt/pool
# sudo cp /etc/fstab /etc/fstab.backup
# sudo nano /etc/fstab
# sudo mount -a # test without committing
# sudo shutdown -r now

sudo apt update
sudo apt install mergerfs -y
