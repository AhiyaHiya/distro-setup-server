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
    true >"$TMP_OUTPUT"

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
            trim_log <"$TMP_OUTPUT" | send_mail
        fi
        exit 1
    else
        echo "SnapRAID is not running, proceeding."
        mklog "INFO: SnapRAID is not running, proceeding."
    fi

  if [ "$RETENTION_DAYS" -gt 0 ]; then
    echo "SnapRAID output retention is enabled. Detailed logs will be kept in $SNAPRAID_LOG_DIR for $RETENTION_DAYS days."
  fi

  # sanity check first to make sure we can access the content and parity files
  mklog "INFO: Checking SnapRAID disks"
  sanity_check


}

# Sends important messages to syslog
function mklog() {
  [[ "$*" =~ ^([A-Za-z]*):\ (.*) ]] &&
  {
    PRIORITY=${BASH_REMATCH[1]} # INFO, DEBUG, WARN
    LOGMESSAGE=${BASH_REMATCH[2]} # the Log-Message
  }
  echo "$(date '+[%Y-%m-%d %H:%M:%S]') $(basename "$0"): $PRIORITY: '$LOGMESSAGE'" >> "$SNAPRAID_LOG"
}

# Redirects output to file and screen. Open a new tee process.
function output_to_file_screen() {
    # redirect all output to screen and file
    exec {OUT}>&1 {ERROR}>&2
    # NOTE: Not preferred format but valid: exec &> >(tee -ia "${TMP_OUTPUT}" )
    exec > >(tee -a "${TMP_OUTPUT}") 2>&1
}


function sanity_check() {
  # If PARITY_FILES is unset or empty, exit early with a clear message.
  if [ "${#PARITY_FILES[@]}" -eq 0 ]; then
    echo "PARITY_FILES is empty. Cannot perform parity file checks. Please set PARITY_FILES in the settings file."
    mklog "WARN: PARITY_FILES is empty. Cannot perform parity file checks. Please set PARITY_FILES in the settings file."

    SUBJECT="[WARNING] - PARITY_FILES is empty $EMAIL_SUBJECT_PREFIX"
    NOTIFY_OUTPUT="$SUBJECT"
    notify_warning
    if [ "$EMAIL_ADDRESS" ]; then
      trim_log < "$TMP_OUTPUT" | send_mail
    fi

    return 1
  fi

  echo "Checking if all parity and content files are present."
  mklog "INFO: Checking if all parity and content files are present."
  for i in "${PARITY_FILES[@]}"; do
    if [ ! -e "$i" ]; then
      echo "[$(date)] ERROR - Parity file ($i) not found!"
      echo "ERROR - Parity file ($i) not found!" >> "$TMP_OUTPUT"
      echo "**ERROR**: Please check the status of your disks! The script exits here due to missing file or disk."
      mklog "WARN: Parity file ($i) not found!"
      mklog "WARN: Please check the status of your disks! The script exits here due to missing file or disk."

      SUBJECT="[WARNING] - Parity file ($i) not found! $EMAIL_SUBJECT_PREFIX"
      NOTIFY_OUTPUT="$SUBJECT"
      notify_warning
      if [ "$EMAIL_ADDRESS" ]; then
        trim_log < "$TMP_OUTPUT" | send_mail
      fi
      exit 1
    fi
  done
  echo "All parity files found."
  mklog "INFO: All parity files found."

  for i in "${CONTENT_FILES[@]}"; do
    if [ ! -e "$i" ]; then
      echo "[$(date)] ERROR - Content file ($i) not found!"
      echo "ERROR - Content file ($i) not found!" >> "$TMP_OUTPUT"
      echo "**ERROR**: Please check the status of your disks! The script exits here due to missing file or disk."
      mklog "WARN: Content file ($i) not found!"
      mklog "WARN: Please check the status of your disks! The script exits here due to missing file or disk."

      SUBJECT="[WARNING] - Content file ($i) not found! $EMAIL_SUBJECT_PREFIX"
      NOTIFY_OUTPUT="$SUBJECT"
      notify_warning
      if [ "$EMAIL_ADDRESS" ]; then
        trim_log < "$TMP_OUTPUT" | send_mail
      fi
      exit 1
    fi
  done
  echo "All content files found."
  mklog "INFO: All content files found."
}

echo "SnapRAID Script started [$(date)]"
main "$@"
