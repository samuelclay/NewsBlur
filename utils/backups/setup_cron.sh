#!/usr/bin/env bash
# setup_cron.sh - Install the NewsBlur backup cron job in the SSH add-on
#
# Called on SSH add-on startup via init_commands in /data/options.json.
# Also called by `make offsite-backup-install`.

CRON_ENTRY='0 6 * * * /config/scripts/mount_backup_drive.sh && /config/scripts/offsite_pull.sh >> /media/newsblur-backup/backup_run.log 2>&1; /config/scripts/unmount_backup_drive.sh >> /media/newsblur-backup/backup_run.log 2>&1'

# Remove any existing offsite_pull entry, then add the current one
(crontab -l 2>/dev/null | grep -v offsite_pull; echo "${CRON_ENTRY}") | crontab -
echo "NewsBlur backup cron job installed (daily 6:00 AM)"

# Start crond if not already running (HAOS SSH add-on doesn't start it by default)
if ! pgrep -x crond > /dev/null 2>&1; then
    crond
    echo "crond started"
else
    echo "crond already running"
fi
