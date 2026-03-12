#!/usr/bin/env bash
# unmount_backup_drive.sh - Unmount and spin down the NewsBlur backup drive
#
# Runs via nsenter/docker on the host so it works from any container.
# Uses SCSI stop (sg_start) to spin down the USB drive — hdparm doesn't work
# with USB-SATA bridges like the Sabrent adapter.

DRIVE_DEVICE="/dev/sda"
HOST_MOUNT_POINT="/mnt/data/supervisor/media/newsblur-backup"

nsenter_run() {
    docker run --rm --privileged --pid=host alpine nsenter -t 1 -m -- "$@"
}

if nsenter_run mountpoint -q "${HOST_MOUNT_POINT}" 2>/dev/null; then
    sync
    nsenter_run umount "${HOST_MOUNT_POINT}" \
        && echo "Unmounted ${HOST_MOUNT_POINT}" \
        || { echo "ERROR: could not unmount ${HOST_MOUNT_POINT}"; exit 1; }
else
    echo "Not mounted"
fi

# Spin down the drive via SCSI stop command
docker run --rm --privileged --device="${DRIVE_DEVICE}" alpine \
    sh -c "apk add -q sg3_utils && sg_start --stop ${DRIVE_DEVICE}" 2>/dev/null \
    && echo "Drive spun down" \
    || echo "WARNING: could not spin down drive"
