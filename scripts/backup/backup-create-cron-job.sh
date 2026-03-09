#!/bin/bash
set -e

# Daily backup of filesystem at 01:00
0 1 * * * /mnt/20TbHd_Usb3/scripts/backup_filesystem.sh >> /var/log/backup_filesystem-cron.log 2>&1
