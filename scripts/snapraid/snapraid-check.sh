#!/bin/bash

# If needed, run `shellcheck snapraid-check.sh` to
# make sure the syntax if fine.

# Source in this script was inspired by https://github.com/auanasgheps/snapraid-aio-script

##################################################################
#  Script variables
SNAPSCRIPTVERSION="0.1.0"

# Read SnapRAID version
SNAPRAIDVERSION="$(snapraid -V | sed -e 's/snapraid v\(.*\)by.*/\1/')"

CURRENT_DIR=$(dirname "${0}")
SETTINGS_FILE=${1:-$CURRENT_DIR/snapraid-check-settings.sh}

#shellcheck source=snapraid-check-settings.sh
source "$SETTINGS_FILE"

function main()
{
    # create tmp file for output
    true > "$TMP_OUTPUT"

    output_to_file_screen

    # timestamp the job
    echo "SnapRAID Script Job started [$(date)]"
    echo "Running SnapRAID version $SNAPRAIDVERSION"
    echo "SnapRAID AIO Script version $SNAPSCRIPTVERSION"
    echo "Using configuration file: $SETTINGS_FILE"
    echo "----------------------------------------"
    mklog "INFO: ----------------------------------------"
    mklog "INFO: SnapRAID Script Job started"
    mklog "INFO: Running SnapRAID version $SNAPRAIDVERSION"
    mklog "INFO: SnapRAID Script version $SNAPSCRIPTVERSION"
    mklog "INFO: Using configuration file: $SETTINGS_FILE"

    ### Check if SnapRAID is already running
  if pgrep -x snapraid >/dev/null; then
    echo "The script has detected SnapRAID is already running. Please check the status of the previous SnapRAID job before running this script again."
      mklog "WARN: The script has detected SnapRAID is already running. Please check the status of the previous SnapRAID job before running this script again."
      SUBJECT="[WARNING] - SnapRAID already running $EMAIL_SUBJECT_PREFIX"
      NOTIFY_OUTPUT="$SUBJECT"
      notify_warning
      if [ "$EMAIL_ADDRESS" ]; then
        trim_log < "$TMP_OUTPUT" | send_mail
      fi
      exit 1;
  else
      echo "SnapRAID is not running, proceeding."
    mklog "INFO: SnapRAID is not running, proceeding."
  fi
}

# Redirects output to file and screen. Open a new tee process.
function output_to_file_screen()
{
    # redirect all output to screen and file
    exec {OUT}>&1 {ERROR}>&2
    # NOTE: Not preferred format but valid: exec &> >(tee -ia "${TMP_OUTPUT}" )
    exec > >(tee -a "${TMP_OUTPUT}") 2>&1
}

