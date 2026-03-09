#!/bin/bash

################################################################################
#
# SnapRAID Health Check and Sync Script
#
# Purpose:
#   Automated health checking and synchronization of SnapRAID parity files.
#   Performs DIFF → SYNC → CHECK → SCRUB operations with configurable thresholds
#   and notifications.
#
# Prerequisites (must be installed on system):
#   - snapraid          : SnapRAID parity tool
#   - bash              : Shell interpreter with process substitution support
#   - grep, sed, cut    : Text processing utilities
#   - bc                : Calculator for floating-point math
#   - mail              : Mail utility for email notifications (optional)
#
# Required Configuration:
#   This script sources a settings file that defines all configuration variables.
#   Default location: ./snapraid-check-settings.sh
#   Custom location: Pass as first argument to script
#
#   Key configuration variables (from settings file):
#   - SNAPRAID_BIN       : Path to snapraid binary (default: /usr/bin/snapraid)
#   - SNAPRAID_CONF      : Path to snapraid config file (default: /etc/snapraid.conf)
#   - SNAPRAID_LOG       : Path to snapraid log file (default: /var/log/snapraid.log)
#   - DEL_THRESHOLD      : Max deleted files before blocking sync (default: 500)
#   - UP_THRESHOLD       : Max updated files before blocking sync (default: 500)
#   - SCRUB_PERCENT      : Percentage of array to scrub (0=disable, default: 5)
#   - SCRUB_AGE          : Age in days for scrub check (default: 10)
#   - PREHASH            : Enable pre-hash for data integrity (default: 1)
#   - EMAIL_ADDRESS_TO   : Email for notifications (default: online@jaimerios.com)
#   - SNAP_STATUS        : Run snapraid status command (default: 0)
#
# Usage:
#
#   1. Run with default settings file in same directory:
#      ./snapraid-check.sh
#
#   2. Run with custom settings file:
#      ./snapraid-check.sh /etc/snapraid-check/custom-settings.sh
#
#   3. Run in dry-run mode (preview actions without executing snapraid commands):
#      ./snapraid-check.sh --dry-run
#      ./snapraid-check.sh --dry-run /etc/snapraid-check/custom-settings.sh
#
#   4. Schedule with cron (runs daily at 2 AM):
#      0 2 * * * /path/to/scripts/snapraid/snapraid-check.sh
#
#   5. Schedule with systemd timer (recommended):
#      Create /etc/systemd/system/snapraid-check.service and .timer files
#
#   6. Manual execution with custom threshold (requires editing settings file):
#      Edit snapraid-check-settings.sh, then run: ./snapraid-check.sh
#
# Output:
#   - Console: Real-time progress of all operations
#   - Log file: /tmp/snapRAID.out (or configured SNAPRAID_LOG_DIR)
#   - System log: /var/log/snapraid.log (via mklog function)
#   - Email: Notification to EMAIL_ADDRESS_TO on warnings/errors (if configured)
#
# Exit Codes:
#   0 : Success - all operations completed
#   1 : Error - configuration validation failed, or SnapRAID operation failed
#
# Workflow:
#   1. Validate configuration (snapraid binary, config file, required commands)
#   2. Check if SnapRAID is already running (prevent concurrent execution)
#   3. [TOUCH] Fix files with zero sub-second timestamps
#   4. [STATUS] Display array health information (optional)
#   5. [DIFF] Compare current data with parity
#   6. [SYNC] Update parity if safe (respects thresholds)
#   7. [CHECK] Verify parity consistency with data (if sync ran)
#   8. [SCRUB] Check for latent disk errors (if sync ran)
#   9. Save logs and rotate old logs based on retention days
#
# Author: SnapRAID script (inspired by https://github.com/auanasgheps/snapraid-aio-script)
# Version: 0.1.0
#
################################################################################

# If needed, run `shellcheck snapraid-check.sh` to make sure the syntax is fine.

set -euo pipefail

##################################################################
#  Script variables
SNAPSCRIPTVERSION="0.1.0"
DRY_RUN=0

# Parse command-line arguments for --dry-run flag
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            SETTINGS_FILE="$1"
            shift
            ;;
    esac
done

# Ensure SETTINGS_FILE is set with default if needed
: "${SETTINGS_FILE:=${CURRENT_DIR:-$(dirname "${0}")}/snapraid-check-settings.sh}"

CURRENT_DIR=$(dirname "${0}")

# Read SnapRAID version
SNAPRAIDVERSION="$(snapraid -V | sed -e 's/snapraid v\(.*\)by.*/\1/')"

SYNC_MARKER="SYNC -"

#shellcheck source=snapraid-check-settings.sh
source "$SETTINGS_FILE"

# Helper function to execute snapraid commands with dry-run support
function snapraid_exec()
{
    local cmd="$@"
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY-RUN] Would execute: $cmd"
        return 0
    else
        eval "$cmd"
        return $?
    fi
}

# Validate configuration before starting
function validate_config()
{
    local errors=0
    
    # Check if snapraid binary exists
    if [ ! -x "$SNAPRAID_BIN" ]; then
        echo "ERROR: SnapRAID binary not found or not executable: $SNAPRAID_BIN" >&2
        ((errors++))
    fi
    
    # Check if config file exists
    if [ ! -f "$SNAPRAID_CONF" ]; then
        echo "ERROR: SnapRAID config file not found: $SNAPRAID_CONF" >&2
        ((errors++))
    fi
    
    # Check for bc command availability
    if ! command -v bc &>/dev/null; then
        echo "ERROR: 'bc' command is required but not installed." >&2
        echo "Install it with: sudo apt install bc" >&2
        ((errors++))
    fi
    
    # Validate numeric settings
    if ! [[ "$DEL_THRESHOLD" =~ ^[0-9]+$ ]]; then
        echo "ERROR: DEL_THRESHOLD must be a number, got: $DEL_THRESHOLD" >&2
        ((errors++))
    fi
    
    if ! [[ "$UP_THRESHOLD" =~ ^[0-9]+$ ]]; then
        echo "ERROR: UP_THRESHOLD must be a number, got: $UP_THRESHOLD" >&2
        ((errors++))
    fi
    
    if [ "$errors" -gt 0 ]; then
        echo "Configuration validation failed with $errors error(s)" >&2
        return 1
    fi
    
    return 0
}

function main()
{
    # create tmp file for output
    true >"$TMP_OUTPUT"

    output_to_file_screen

    # Validate configuration
    validate_config || exit 1

    # timestamp the job
    echo "SnapRAID Script Job started [$(date)]"
    echo "Running SnapRAID version $SNAPRAIDVERSION"
    echo "SnapRAID AIO Script version $SNAPSCRIPTVERSION"
    echo "Using configuration file: $SETTINGS_FILE"
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "----------------------------------------"
        echo "**DRY-RUN MODE ENABLED**"
        echo "SnapRAID commands will be shown but NOT executed"
        echo "----------------------------------------"
    fi
    
    echo "----------------------------------------"
    mklog "INFO: ----------------------------------------"
    mklog "INFO: SnapRAID Script Job started"
    mklog "INFO: Running SnapRAID version $SNAPRAIDVERSION"
    mklog "INFO: SnapRAID Script version $SNAPSCRIPTVERSION"
    mklog "INFO: Using configuration file: $SETTINGS_FILE"

    ### Check if SnapRAID is already running
    if pgrep -f "$SNAPRAID_BIN" >/dev/null 2>&1; then
        echo "The script has detected SnapRAID is already running. Please check the status of the previous SnapRAID job before running this script again."
        mklog "WARN: The script has detected SnapRAID is already running. Please check the status of the previous SnapRAID job before running this script again."
        SUBJECT="[WARNING] - SnapRAID already running $EMAIL_SUBJECT_PREFIX"
        NOTIFY_OUTPUT="$SUBJECT"
        notify_warning
        if [ "$EMAIL_ADDRESS_TO" ]; then
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

    mklog "INFO: Fix timestamps if needed"
    chk_zero

    # Run status if enabled
    if [ "$SNAP_STATUS" -eq 1 ]; then
        echo "### SnapRAID STATUS [$(date)]"
        mklog "INFO: SnapRAID STATUS started"
        echo "```"
        snapraid_exec "$SNAPRAID_BIN -c $SNAPRAID_CONF status"
        if [ "$DRY_RUN" -eq 0 ]; then
            close_output_and_wait
            output_to_file_screen
        fi
        echo "```"
        echo "STATUS finished [$(date)]"
        mklog "INFO: SnapRAID STATUS finished"
    fi

    mklog "INFO: run the snapraid DIFF command"
    echo "### SnapRAID DIFF [$(date)]"
    mklog "INFO: SnapRAID DIFF started"
    echo "```"
    snapraid_exec "$SNAPRAID_BIN -c $SNAPRAID_CONF diff"
    if [ "$DRY_RUN" -eq 0 ]; then
        close_output_and_wait
        output_to_file_screen
    fi
    echo "```"
    echo "DIFF finished [$(date)]"
    mklog "INFO: SnapRAID DIFF finished"
    JOBS_DONE="DIFF"

    # Get number of deleted, updated, and modified files...
    if [ "$DRY_RUN" -eq 0 ]; then
        get_counts
    else
        # In dry-run mode, set dummy counts to show workflow
        EQ_COUNT="0"
        ADD_COUNT="0"
        DEL_COUNT="0"
        UPDATE_COUNT="0"
        MOVE_COUNT="0"
        COPY_COUNT="0"
        echo "[DRY-RUN] Skipping file count parsing in dry-run mode"
    fi

    # sanity check to make sure that we were able to get our counts from the
    # output of the DIFF job
    if [ -z "$DEL_COUNT" ] || [ -z "$ADD_COUNT" ] || [ -z "$MOVE_COUNT" ] || [ -z "$COPY_COUNT" ] || [ -z "$UPDATE_COUNT" ]; then
        # failed to get one or more of the count values, lets report to user and
        # exit with error code
        echo "**ERROR** - Failed to get one or more count values. Unable to continue."
        mklog "WARN: Failed to get one or more count values. Unable to continue."
        echo "Exiting script. [$(date)]"
        SUBJECT="[WARNING] - Unable to continue with SYNC/SCRUB job(s). Check DIFF job output. $EMAIL_SUBJECT_PREFIX"
        NOTIFY_OUTPUT="$SUBJECT"
        notify_warning
        if [ "$EMAIL_ADDRESS_TO" ]; then
            trim_log < "$TMP_OUTPUT" | send_mail
        fi
        exit 1
    fi
    echo "**SUMMARY: Equal [$EQ_COUNT] - Added [$ADD_COUNT] - Deleted [$DEL_COUNT] - Moved [$MOVE_COUNT] - Copied [$COPY_COUNT] - Updated [$UPDATE_COUNT]**"
    mklog "INFO: SUMMARY: Equal [$EQ_COUNT] - Added [$ADD_COUNT] - Deleted [$DEL_COUNT] - Moved [$MOVE_COUNT] - Copied [$COPY_COUNT] - Updated [$UPDATE_COUNT]"

    # Check if the conditions to run SYNC are met in dry-run mode
    if [ "$DRY_RUN" -eq 1 ]; then
        # In dry-run mode, assume sync would be authorized
        echo "[DRY-RUN] Assuming SYNC would be authorized based on default settings"
        DO_SYNC=1
    elif [ "$DEL_COUNT" -gt 0 ] || [ "$ADD_COUNT" -gt 0 ] || [ "$MOVE_COUNT" -gt 0 ] || [ "$COPY_COUNT" -gt 0 ] || [ "$UPDATE_COUNT" -gt 0 ]; then
        # In normal mode, check if files have changed
        chk_del
        if [ "$CHK_FAIL" -eq 0 ]; then
            chk_updated
        fi
        if [ "$CHK_FAIL" -eq 1 ]; then
            chk_sync_warn
        fi
    else
        # NO, so let's skip SYNC
        echo "No change detected. Not running SYNC job. [$(date)]"
        mklog "INFO: No change detected. Not running SYNC job."
        DO_SYNC=0
    fi

    # Now run sync if conditions are met
  if [ "$DO_SYNC" -eq 1 ]; then
    echo "SYNC is authorized. [$(date)]"
    echo "### SnapRAID SYNC [$(date)]"
    mklog "INFO: SnapRAID SYNC Job started"
    echo "\`\`\`"
    
    SYNC_CMD="$SNAPRAID_BIN -c $SNAPRAID_CONF"
    if [ "$PREHASH" -eq 1 ] && [ "$FORCE_ZERO" -eq 1 ]; then
      SYNC_CMD="$SYNC_CMD -h --force-zero -q sync"
    elif [ "$PREHASH" -eq 1 ]; then
      SYNC_CMD="$SYNC_CMD -h -q sync"
    elif [ "$FORCE_ZERO" -eq 1 ]; then
      SYNC_CMD="$SYNC_CMD --force-zero -q sync"
    else
      SYNC_CMD="$SYNC_CMD -q sync"
    fi
    
    snapraid_exec "$SYNC_CMD"
    if [ "$DRY_RUN" -eq 0 ]; then
        close_output_and_wait
        output_to_file_screen
    fi
    echo "\`\`\`"
    echo "SYNC finished [$(date)]"
    mklog "INFO: SnapRAID SYNC Job finished"
    JOBS_DONE="$JOBS_DONE + SYNC"
    # insert SYNC marker to 'Everything OK' or 'Nothing to do' string to
    # differentiate it from SCRUB job later
    if [ "$DRY_RUN" -eq 0 ]; then
        sed_me "
          s/^Everything OK/${SYNC_MARKER} Everything OK/g;
          s/^Nothing to do/${SYNC_MARKER} Nothing to do/g" "$TMP_OUTPUT"
    fi
    # Remove any warning flags if set previously. This is done in this step to
    # take care of scenarios when user has manually synced or restored deleted
    # files and we will have missed it in the checks above.
    if [ -e "$SYNC_WARN_FILE" ]; then
      rm "$SYNC_WARN_FILE"
    fi
  fi

    # CHECK operation - verify parity is consistent with data
    if [ "$DO_SYNC" -eq 1 ]; then
        echo "### SnapRAID CHECK [$(date)]"
        mklog "INFO: SnapRAID CHECK Job started"
        echo "```"
        snapraid_exec "$SNAPRAID_BIN -c $SNAPRAID_CONF -q check"
        if [ "$DRY_RUN" -eq 0 ]; then
            close_output_and_wait
            output_to_file_screen
        fi
        echo "```"
        echo "CHECK finished [$(date)]"
        mklog "INFO: SnapRAID CHECK Job finished"
        JOBS_DONE="$JOBS_DONE + CHECK"
    fi

    # SCRUB operation - check for latent disk errors
    if [ "$DO_SYNC" -eq 1 ]; then
        echo "### SnapRAID SCRUB [$(date)]"
        mklog "INFO: SnapRAID SCRUB Job started"
        
        SCRUB_CMD="$SNAPRAID_BIN -c $SNAPRAID_CONF"
        
        # Add scrub parameters if configured
        if [ "$SCRUB_PERCENT" -gt 0 ]; then
            SCRUB_CMD="$SCRUB_CMD -p $SCRUB_PERCENT"
        fi
        
        if [ "$SCRUB_AGE" -gt 0 ]; then
            SCRUB_CMD="$SCRUB_CMD -a $SCRUB_AGE"
        fi
        
        SCRUB_CMD="$SCRUB_CMD -q scrub"
        
        echo "```"
        snapraid_exec "$SCRUB_CMD"
        if [ "$DRY_RUN" -eq 0 ]; then
            close_output_and_wait
            output_to_file_screen
        fi
        echo "```"
        echo "SCRUB finished [$(date)]"
        mklog "INFO: SnapRAID SCRUB Job finished"
        JOBS_DONE="$JOBS_DONE + SCRUB"
    fi

    # Save and rotate logs if enabled
  if [ "$RETENTION_DAYS" -gt 0 ]; then
    # Ensure directory exists
    mkdir -p "$SNAPRAID_LOG_DIR" || {
        echo "ERROR: Cannot create log directory: $SNAPRAID_LOG_DIR"
        mklog "WARN: Cannot create log directory: $SNAPRAID_LOG_DIR"
    }
    
    find "$SNAPRAID_LOG_DIR"/SnapRAID-* -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
    
    if ! cp "$TMP_OUTPUT" "$SNAPRAID_LOG_DIR"/SnapRAID-"$(date +"%Y_%m_%d-%H%M")".out; then
        mklog "WARN: Failed to copy log file to $SNAPRAID_LOG_DIR"
    fi
  fi

  # exit with success, letting the trap handle cleanup of file descriptors
  exit 0;
}

function chk_del()
{
    if [ "$DEL_COUNT" -eq 0 ]; then
        echo "There are no deleted files, that's fine."
        DO_SYNC=1
    elif [ "$DEL_COUNT" -lt "$DEL_THRESHOLD" ]; then
        echo "There are deleted files. The number of deleted files ($DEL_COUNT) is below the threshold of ($DEL_THRESHOLD)."
        DO_SYNC=1
    # check if ADD_DEL_THRESHOLD is greater than zero before attempting to use it
    elif [ "$(echo "$ADD_DEL_THRESHOLD > 0" | bc -l)" -eq 1 ]; then
        ADD_DEL_RATIO=$(echo "scale=2; $ADD_COUNT / $DEL_COUNT" | bc)
        if [ "$(echo "$ADD_DEL_RATIO >= $ADD_DEL_THRESHOLD" | bc -l)" -eq 1 ]; then
            echo "There are deleted files. The number of deleted files ($DEL_COUNT) is above the threshold of ($DEL_THRESHOLD)"
            echo "but the add/delete ratio of ($ADD_DEL_RATIO) is above the threshold of ($ADD_DEL_THRESHOLD), sync will proceed."
            DO_SYNC=1
        else
            echo "**WARNING!** Deleted files ($DEL_COUNT) reached/exceeded threshold ($DEL_THRESHOLD) and add/delete threshold ($ADD_DEL_THRESHOLD) was not met."
            mklog "WARN: Deleted files ($DEL_COUNT) reached/exceeded threshold ($DEL_THRESHOLD) and add/delete threshold ($ADD_DEL_THRESHOLD) was not met."
            CHK_FAIL=1
        fi
    else
        if [ "$RETENTION_DAYS" -gt 0 ]; then
            echo "**WARNING!** Deleted files ($DEL_COUNT) reached/exceeded threshold ($DEL_THRESHOLD)."
            echo "For more information, please check the DIFF ouput saved in $SNAPRAID_LOG_DIR."
            mklog "WARN: Deleted files ($DEL_COUNT) reached/exceeded threshold ($DEL_THRESHOLD)."
            CHK_FAIL=1
        else
            echo "**WARNING!** Deleted files ($DEL_COUNT) reached/exceeded threshold ($DEL_THRESHOLD)."
            mklog "WARN: Deleted files ($DEL_COUNT) reached/exceeded threshold ($DEL_THRESHOLD)."
            CHK_FAIL=1
        fi
    fi
}


function chk_sync_warn()
{
    if [ "$SYNC_WARN_THRESHOLD" -gt -1 ]; then
    if [ "$SYNC_WARN_THRESHOLD" -eq 0 ]; then
      echo "Forced sync is enabled."
      mklog "INFO: Forced sync is enabled."
    else
      echo "Sync after threshold warning(s) is enabled."
      mklog "INFO: Sync after threshold warning(s) is enabled."
    fi

    local sync_warn_count
    sync_warn_count=$(sed '/^[0-9]*$/!d' "$SYNC_WARN_FILE" 2>/dev/null)
    # zero if file does not exist or did not contain a number
    : "${sync_warn_count:=0}"

    if [ "$sync_warn_count" -ge "$SYNC_WARN_THRESHOLD" ]; then
      # Force a sync. If the warn count is zero it means the sync was already
      # forced, do not output a dumb message and continue with the sync job.
      if [ "$sync_warn_count" -eq 0 ]; then
        DO_SYNC=1
      else
        # If there is at least one warn count, output a message and force a
        # sync job. Do not need to remove warning marker here as it is
        # automatically removed when the sync job is run by this script
        echo "Number of threshold warning(s) ($sync_warn_count) has reached/exceeded threshold ($SYNC_WARN_THRESHOLD). Forcing a SYNC job to run."
        mklog "INFO: Number of threshold warning(s) ($sync_warn_count) has reached/exceeded threshold ($SYNC_WARN_THRESHOLD). Forcing a SYNC job to run."
        DO_SYNC=1
      fi
    else
      # NO, so let's increment the warning count and skip the sync job
      ((sync_warn_count += 1))
      echo "$sync_warn_count" > "$SYNC_WARN_FILE"
      if [ "$sync_warn_count" == "$SYNC_WARN_THRESHOLD" ]; then
        echo  "This is the **last** warning left. **NOT** proceeding with SYNC job. [$(date)]"
        mklog "INFO: This is the **last** warning left. **NOT** proceeding with SYNC job. [$(date)]"
        DO_SYNC=0
      else
        echo "$((SYNC_WARN_THRESHOLD - sync_warn_count)) threshold warning(s) until the next forced sync. **NOT** proceeding with SYNC job. [$(date)]"
        mklog "INFO: $((SYNC_WARN_THRESHOLD - sync_warn_count)) threshold warning(s) until the next forced sync. **NOT** proceeding with SYNC job."
        DO_SYNC=0
      fi
    fi
  else
    # NO, so let's skip SYNC
    if [ "$RETENTION_DAYS" -gt 0 ]; then
    echo "Forced sync is not enabled. **NOT** proceeding with SYNC job. [$(date)]"
    mklog "INFO: Forced sync is not enabled. **NOT** proceeding with SYNC job."
    DO_SYNC=0
    else
    echo "Forced sync is not enabled. Check $TMP_OUTPUT for details. **NOT** proceeding with SYNC job. [$(date)]"
    mklog "INFO: Forced sync is not enabled. Check $TMP_OUTPUT for details. **NOT** proceeding with SYNC job."
    DO_SYNC=0
    fi
  fi
}

function chk_updated()
{
    if [ "$UPDATE_COUNT" -lt "$UP_THRESHOLD" ]; then
    if [ "$UPDATE_COUNT" -eq 0 ]; then
      echo "There are no updated files, that's fine."
      DO_SYNC=1
    else
      echo "There are updated files. The number of updated files ($UPDATE_COUNT) is below the threshold of ($UP_THRESHOLD)."
      DO_SYNC=1
    fi
  else
    if [ "$RETENTION_DAYS" -gt 0 ]; then
      echo "**WARNING!** Updated files ($UPDATE_COUNT) reached/exceeded threshold ($UP_THRESHOLD)."
      echo "For more information, please check the DIFF ouput saved in $SNAPRAID_LOG_DIR."
      mklog "WARN: Updated files ($UPDATE_COUNT) reached/exceeded threshold ($UP_THRESHOLD)."
      CHK_FAIL=1
    else
      echo "**WARNING!** Updated files ($UPDATE_COUNT) reached/exceeded threshold ($UP_THRESHOLD)."
      mklog "WARN: Updated files ($UPDATE_COUNT) reached/exceeded threshold ($UP_THRESHOLD)."
      CHK_FAIL=1
    fi
  fi
}

function chk_zero()
{
    echo "### SnapRAID TOUCH [$(date)]"
    echo "Checking for zero sub-second files."
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY-RUN] Would check: $SNAPRAID_BIN -c $SNAPRAID_CONF status"
        echo "[DRY-RUN] (Skipping actual status check in dry-run mode)"
    else
        TIMESTATUS=$($SNAPRAID_BIN -c $SNAPRAID_CONF status | grep -E 'You have [1-9][0-9]* files with( a)? zero sub-second timestamp\.' | sed 's/^You have/Found/g')
        if [ -n "$TIMESTATUS" ]; then
            echo "$TIMESTATUS"
            echo "Running TOUCH job to timestamp. [$(date)]"
            echo "```"
            $SNAPRAID_BIN -c $SNAPRAID_CONF touch
            close_output_and_wait
            output_to_file_screen
            echo "```"
        else
            echo "No zero sub-second timestamp files found."
        fi
    fi
    echo "TOUCH finished [$(date)]"
}

function close_output_and_wait()
{
    exec >& "$OUT" 2>& "$ERROR"
    CHILD_PID=$(pgrep -P $$)
    if [ -n "$CHILD_PID" ]; then
        wait "$CHILD_PID"
    fi
}

function get_counts()
{
    EQ_COUNT=$(grep -w '^ \{1,\}[0-9]* equal' "$TMP_OUTPUT" | sed 's/^ *//g' | cut -d ' ' -f1)
    ADD_COUNT=$(grep -w '^ \{1,\}[0-9]* added' "$TMP_OUTPUT" | sed 's/^ *//g' | cut -d ' ' -f1)
    DEL_COUNT=$(grep -w '^ \{1,\}[0-9]* removed' "$TMP_OUTPUT" | sed 's/^ *//g' | cut -d ' ' -f1)
    UPDATE_COUNT=$(grep -w '^ \{1,\}[0-9]* updated' "$TMP_OUTPUT" | sed 's/^ *//g' | cut -d ' ' -f1)
    MOVE_COUNT=$(grep -w '^ \{1,\}[0-9]* moved' "$TMP_OUTPUT" | sed 's/^ *//g' | cut -d ' ' -f1)
    COPY_COUNT=$(grep -w '^ \{1,\}[0-9]* copied' "$TMP_OUTPUT" | sed 's/^ *//g' | cut -d ' ' -f1)
    # REST_COUNT=$(grep -w '^ \{1,\}[0-9]* restored' $TMP_OUTPUT | sed 's/^ *//g' | cut -d ' ' -f1)
    
    # Provide defaults if values are empty (in case parse fails)
    EQ_COUNT="${EQ_COUNT:-0}"
    ADD_COUNT="${ADD_COUNT:-0}"
    DEL_COUNT="${DEL_COUNT:-0}"
    UPDATE_COUNT="${UPDATE_COUNT:-0}"
    MOVE_COUNT="${MOVE_COUNT:-0}"
    COPY_COUNT="${COPY_COUNT:-0}"
}

# Sends important messages to syslog
function mklog()
{
    [[ "$*" =~ ^([A-Za-z]*):\ (.*) ]] &&
    {
        PRIORITY=${BASH_REMATCH[1]} # INFO, DEBUG, WARN
        LOGMESSAGE=${BASH_REMATCH[2]} # the Log-Message
    }
    echo "$(date '+[%Y-%m-%d %H:%M:%S]') $(basename "$0"): $PRIORITY: '$LOGMESSAGE'" >> "$SNAPRAID_LOG"
}

function notify_warning()
{
    #   if [ "$HEALTHCHECKS" -eq 1 ]; then
    #     curl -fsS -m 5 --retry 3 -o /dev/null "$HEALTHCHECKS_URL$HEALTHCHECKS_ID"/fail --data-raw "$NOTIFY_OUTPUT"
    #   fi
    #   if [ "$TELEGRAM" -eq 1 ]; then
    #     curl -fsS -m 5 --retry 3 -o /dev/null -X POST \
    #     -H 'Content-Type: application/json' \
    #     -d '{"chat_id": "'"$TELEGRAM_CHAT_ID"'", "text": "'"$NOTIFY_OUTPUT"'"}' \
    #     https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendMessage
    #   fi
    #   if [ "$DISCORD" -eq 1 ]; then
    #   DISCORD_SUBJECT=$(echo "$NOTIFY_OUTPUT" | jq -Rs | cut -c 2- | rev | cut -c 2- | rev)
    #     curl -fsS -m 5 --retry 3 -o /dev/null -X POST \
    #     -H 'Content-Type: application/json' \
    #     -d '{"content": "'"$DISCORD_SUBJECT"'"}' \
    #     "$DISCORD_WEBHOOK_URL"
    #   fi
    mklog "WARN: Not implemented: notify_warning"
}

# Redirects output to file and screen. Open a new tee process.
function output_to_file_screen()
{
    # redirect all output to screen and file
    exec {OUT}>&1 {ERROR}>&2
    # NOTE: Not preferred format but valid: exec &> >(tee -ia "${TMP_OUTPUT}" )
    exec > >(tee -a "${TMP_OUTPUT}") 2>&1
}

function sanity_check()
{
    # If PARITY_FILES is unset or empty, exit early with a clear message.
    if [ "${#PARITY_FILES[@]}" -eq 0 ]; then
        echo "PARITY_FILES is empty. Cannot perform parity file checks. Please set PARITY_FILES in the settings file."
        mklog "WARN: PARITY_FILES is empty. Cannot perform parity file checks. Please set PARITY_FILES in the settings file."

        SUBJECT="[WARNING] - PARITY_FILES is empty $EMAIL_SUBJECT_PREFIX"
        NOTIFY_OUTPUT="$SUBJECT"
        notify_warning
        if [ "$EMAIL_ADDRESS_TO" ]; then
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
            if [ "$EMAIL_ADDRESS_TO" ]; then
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
            if [ "$EMAIL_ADDRESS_TO" ]; then
                trim_log < "$TMP_OUTPUT" | send_mail
            fi
            exit 1
        fi
    done
    echo "All content files found."
    mklog "INFO: All content files found."
}

function sed_me()
{
    # Close the open output stream first, then perform sed and open a new tee
    # process and redirect output. We close stream because of the calls to new
    # wait function in between sed_me calls. If we do not do this we try to close
    # Processes which are not parents of the shell.
    exec >& "$OUT" 2>& "$ERROR"
    sed -i "$1" "$2"

    output_to_file_screen
}

# Process and mail the email body read from stdin.
function send_mail()
{
    local body
    body=$(cat)
    
    if [ -z "$EMAIL_ADDRESS_TO" ]; then
        mklog "INFO: Email address not configured, skipping notification"
        return 0
    fi
    
    # Check if mail command exists
    if ! command -v mail &>/dev/null; then
        mklog "WARN: 'mail' command not found, cannot send email. Install mailutils or similar."
        return 1
    fi
    
    # Send email
    if echo "$body" | mail -s "$SUBJECT" -r "$EMAIL_ADDRESS_FROM" "$EMAIL_ADDRESS_TO"; then
        mklog "INFO: Email notification sent to $EMAIL_ADDRESS_TO"
        return 0
    else
        mklog "WARN: Failed to send email notification"
        return 1
    fi
}

# Trim the log file read from stdin.
function trim_log()
{
    sed '
    /^Running TOUCH job to timestamp/,/^\TOUCH finished/{
      /^Running TOUCH job to timestamp/!{/^TOUCH finished/!d}
    };
    /^### SnapRAID DIFF/,/^\DIFF finished/{
      /^### SnapRAID DIFF/!{/^DIFF finished/!d}
    }'
}

echo "SnapRAID Script started [$(date)]"
main "$@"
echo "SnapRAID Script finished [$(date)]"
