#!/usr/bin/env bash
# run_offsite_backup.sh - Mount the backup drive, pull backups, unmount it again
#
# The entry point for every backup run on the HA box: the nightly cron job
# installed by setup_cron.sh and `make offsite-backup` both call this.
# Arguments are passed through to offsite_pull.sh (e.g. --force-mongo).
#
# The unmount happens here, after offsite_pull.sh has exited, and this script's
# own log lives off the drive, so nothing has a file open on the drive when it
# is unmounted. Until October 2026 the cron line redirected the pull's output
# and the unmount's output onto the drive, and the pull unmounted the drive
# itself, so umount always found it busy. unmount_backup_drive.sh then fell
# back to a lazy unmount and cut USB power under the live filesystem, aborting
# the ext4 journal after every pull.
#
# Usage: ./run_offsite_backup.sh [--force-mongo]

set -uo pipefail

SCRIPTS_DIR="/config/scripts"
BACKUP_DRIVE="/media/newsblur-backup"
# Mount, pull exit code and unmount for each run. On HA's eMMC, not the drive
# (see above), and only a few lines per run.
RUN_LOG="${SCRIPTS_DIR}/offsite_backup_runs.log"
# Everything offsite_pull.sh prints, including the mongodump progress stream
PULL_LOG="${BACKUP_DRIVE}/backup_run.log"
LOCK_FILE="/tmp/offsite_backup.lock"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "${RUN_LOG}"
}

# One run at a time. A manual `make offsite-backup` overlapping the 6am cron
# would otherwise unmount the drive out from under the other run.
exec 9> "${LOCK_FILE}"
if ! flock -n 9; then
    log "Another off-site backup run is in progress, exiting"
    exit 0
fi

log "=== Off-site backup run starting ($*) ==="

if ! "${SCRIPTS_DIR}/mount_backup_drive.sh" 2>&1 | while read -r line; do log "  ${line}"; done; then
    # No pull means no heartbeat reaches S3, so utils/monitor_offsite_backup.py
    # emails about the missed run within a day.
    log "ERROR: backup drive did not mount, skipping the pull"
    "${SCRIPTS_DIR}/unmount_backup_drive.sh" 2>&1 | while read -r line; do log "  ${line}"; done
    exit 1
fi

# Under cron stdout is /dev/null, so the pull's output only lands in PULL_LOG.
# Run by hand it also shows in the terminal.
"${SCRIPTS_DIR}/offsite_pull.sh" "$@" 2>&1 | tee -a "${PULL_LOG}"
PULL_EXIT=${PIPESTATUS[0]}
log "offsite_pull.sh exited ${PULL_EXIT}"

cd /
if ! "${SCRIPTS_DIR}/unmount_backup_drive.sh" 2>&1 | while read -r line; do log "  ${line}"; done; then
    log "ERROR: backup drive did not unmount cleanly, left mounted"
    exit 1
fi

log "=== Off-site backup run finished ==="
exit "${PULL_EXIT}"
