#!/bin/bash

# If needed, run `shellcheck snapraid-check-settings.sh` to
# make sure the syntax if fine.

EMAIL_ADDRESS_FROM="online@jaimerios.com"
EMAIL_ADDRESS_TO="online@jaimerios.com"

RETENTION_DAYS=0

SNAPRAID_CONF="/etc/snapraid.conf"
SNAPRAID_LOG_DIR="$HOME"
SNAPRAID_LOG="/var/log/snapraid.log"

TMP_OUTPUT="/tmp/snapRAID.out"

# Extract info from SnapRAID config
SNAPRAID_CONF_LINES=$(grep -E '^[^#;]' $SNAPRAID_CONF)

IFS=$'\n'
# Build an array of content files
CONTENT_FILES=(
$(echo "$SNAPRAID_CONF_LINES" | grep snapraid.content | cut -d ' ' -f2)
)

# Build an array of parity all files...
PARITY_FILES=(
  $(echo "$SNAPRAID_CONF_LINES" | grep -E '^([2-6z]-)*parity' | cut -d ' ' -f2- | tr ',' '\n')
)
unset IFS
