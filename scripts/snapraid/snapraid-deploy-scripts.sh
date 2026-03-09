set -e

sudo mkdir -p /usr/local/sbin

sudo cp $(dirname "${0}")/snapraid-check.sh            /usr/local/sbin/snapraid-check.sh
sudo cp $(dirname "${0}")/snapraid-check-settings.sh   /usr/local/sbin/snapraid-check-settings.sh

sudo chmod 755 /usr/local/sbin/snapraid-check.sh /usr/local/sbin/snapraid-check-settings.sh
sudo chown root:root /usr/local/sbin/snapraid-check.sh /usr/local/sbin/snapraid-check-settings.sh
