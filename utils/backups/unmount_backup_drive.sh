#!/usr/bin/env bash
# unmount_backup_drive.sh - Unmount the NewsBlur backup drive on the HA box
#
# Runs via nsenter on the host so it works from any container (SSH add-on, HA Core).
# The drive will spin down on its own once unmounted (no filesystem polling to keep it awake).

HOST_MOUNT_POINT="/mnt/data/supervisor/media/newsblur-backup"

nsenter_run() {
    docker run --rm --privileged --pid=host alpine nsenter -t 1 -m -- "$@"
}

if ! nsenter_run mountpoint -q "${HOST_MOUNT_POINT}" 2>/dev/null; then
    echo "Not mounted"
    exit 0
fi

sync
nsenter_run umount "${HOST_MOUNT_POINT}" \
    && echo "Unmounted ${HOST_MOUNT_POINT}" \
    || { echo "ERROR: could not unmount ${HOST_MOUNT_POINT}"; exit 1; }
