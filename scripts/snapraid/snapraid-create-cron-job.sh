set -e

# Daily SnapRAID check/sync/scrub at 03:15
15 3 * * * /usr/local/sbin/snapraid-check.sh >> /var/log/snapraid-cron.log 2>&1
