# This file is sourced by snapraid-check.sh - do not execute directly
# If needed, run `shellcheck snapraid-check-settings.sh` to
# make sure the syntax is fine.

CHK_FAIL=0
DO_SYNC=0

EMAIL_ADDRESS_FROM="online@jaimerios.com"
EMAIL_ADDRESS_TO="online@jaimerios.com"
EMAIL_SUBJECT_PREFIX="(SnapRAID on $(hostname))"

SECONDS=0 #Capture time

# Initialize CURRENT_DIR - needed for SYNC_WARN_FILE and other relative paths
CURRENT_DIR="$(dirname "${BASH_SOURCE[0]}")"

SNAPRAID_BIN="/usr/bin/snapraid"
SNAPRAID_LOG="/var/log/snapraid.log"

TMP_OUTPUT="/tmp/snapRAID.out"

SYNC_WARN_FILE="$CURRENT_DIR/snapRAID.warnCount"

### SCRIPT AND SNAPRAID SETTINGS ###

# Set the threshold of deleted and updated files to stop the sync job from running.
# Note that depending on how active your filesystem is being used, a low number
# here may result in your parity info being out of sync often and/or you having
# to do lots of manual syncing.
DEL_THRESHOLD=500
UP_THRESHOLD=500

# Allow a sync that would otherwise violate the delete threshold, but only
# if the ratio of added to deleted files is greater than the value set.
# Set to 0 to disable this option.
# Example: A senario with 5000 deleted files and 3800 added files would
# result in an ADD_DEL_THRESHOLD of 0.76 (3800/5000)
ADD_DEL_THRESHOLD=0

# Set number of warnings before forcing a sync, or force the sync every time
# ignoring thresholds (Forced Sync). This option comes in handy when you cannot be 
# bothered to manually start a sync job when DEL_THRESHOLD or UP_TRESHOLD are 
# breached due to false alarm. 
# Set to 0 to ALWAYS force a sync (Forced Sync, ignoring the thresholds above) 
# Set to -1 to NEVER force a sync, the default behaviour (need to manual sync if
# thresholds are breached).
SYNC_WARN_THRESHOLD=-1

# Set percentage and age, in days, of blocks in array to scrub if it is in sync.
# i.e. 0 to disable and 100 to scrub the full array in one go.
# WARNING - depending on size of your array, setting to 100 can take a long time!
SCRUB_PERCENT=5
SCRUB_AGE=10

# Scrub new blocks after sync that have yet to be scrubbed. 1 to enable and any
# other value to disable.
SCRUB_NEW=0

# Set number of script runs before running a scrub. Use this option if you
# don't want to scrub the array every time.
# Set to 0 to disable this option and run scrub every time.
SCRUB_DELAYED_RUN=0

# Prehash Data To avoid the risk of a latent hardware issue, you can enable the
# "pre-hash" mode and have all the data read two times to ensure its integrity.
# This option also verifies the files moved inside the array, to ensure that
# the move operation went successfully, and in case to block the sync and to
# allow to run a fix operation. 1 to enable, any other value to disable.
PREHASH=1

# Forces the operation of syncing a file with zero size that before was not.
# If SnapRAID detects a such condition, it stops proceeding unless you enable
# this option. Useful when syncing system files which can genuinely get
# changed to zero.
# Disabled by default, 1 to enable.
FORCE_ZERO=0

# Set if disk spindown should be performed. Depending on your system, this may
# not work. 1 to enable, any other value to disable.
# hd-idle is required and must be already configured.
SPINDOWN=0

# Increase verbosity of the email output. NOT RECOMMENDED!
# If set to 1, TOUCH and DIFF outputs will be kept in the email, producing
# a mostly unreadable email. You can always check TOUCH and DIFF outputs
# using the TMP file or use the feature RETENTION_DAYS.
# 1 to enable, any other value to disable.
VERBOSITY=0

# SnapRAID detailed output retention for each run.
# Default behaviour is RETENTION_DAYS=0: every time your run SnapRAID, the
# output is saved to "/tmp" and is overridden during every run.
# To enable retention, set RETENTION_DAYS to the days of output you want to
# keep in your home folder. Files will have timestamps.
# SNAPRAID_LOG_DIR can be changed to any folder you like.
RETENTION_DAYS=0
SNAPRAID_LOG_DIR="$HOME"

# Set the option to log SMART info collected by SnapRAID. 
# Use SMART_LOG_NOTIFY to send the output to Telegram/Discord
# 1 to enable, any other value to disable.
SMART_LOG=1
SMART_LOG_NOTIFY=0

# Run 'snapraid status' command to show array general information.
# Use SNAP_STATUS_NOTIFY to send the output to Telegram/Discord
# 1 to enable, any other value to disable.
SNAP_STATUS=0
SNAP_STATUS_NOTIFY=0

# SnapRAID configuration file location. The default path works on most 
# installations, including OMV6.
# If you're using OMV7, the script will try to pick the file automatically.
# If you have multiple SnapRAID arrays, you must must manually specify the 
# config file you want to use. On OMV7 the files are located at /etc/snapraid/
SNAPRAID_CONF="/etc/snapraid.conf"

# Validate that config file exists
if [ ! -f "$SNAPRAID_CONF" ]; then
    echo "ERROR: SnapRAID config file not found: $SNAPRAID_CONF" >&2
    exit 1
fi

# Extract info from SnapRAID config
SNAPRAID_CONF_LINES=$(grep -E '^[^#;]' $SNAPRAID_CONF)

IFS=$'\n'
# Build an array of content files
CONTENT_FILES=(
$(echo "$SNAPRAID_CONF_LINES" | grep snapraid.content | cut -d ' ' -f2)
)

# Build an array of parity all files...
PARITY_FILES=(
  $(echo "$SNAPRAID_CONF_LINES" | grep -E '^([0-9]+-)?parity' | cut -d ' ' -f2- | tr ',' '\n')
)
unset IFS

# Verify required commands are available
for cmd in snapraid grep sed cut; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: Required command '$cmd' not found" >&2
        exit 1
    fi
done
