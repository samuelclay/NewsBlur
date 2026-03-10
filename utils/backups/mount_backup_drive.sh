#!/usr/bin/env bash
# mount_backup_drive.sh - Mount the NewsBlur backup drive on the HA box
#
# Mounts with noatime to prevent unnecessary writes (access time updates)
# and sets a spindown timer so the drive stops spinning when idle.

DRIVE_UUID="ef981d62-7a0b-4858-9ee9-38db68f1e46f"
MOUNT_POINT="/media/newsblur-backup"

if mountpoint -q "${MOUNT_POINT}" 2>/dev/null; then
    echo "Already mounted at ${MOUNT_POINT}"
    exit 0
fi

mkdir -p "${MOUNT_POINT}"
mount -o noatime /dev/disk/by-uuid/${DRIVE_UUID} "${MOUNT_POINT}"
echo "Mounted ${MOUNT_POINT}"

# Set spindown after 30 minutes of inactivity
# hdparm -S 241 = 30 minutes (vendor-specific encoding for values > 240)
# The SSH add-on runs in a container without block device access, so we use a
# privileged Docker container with nsenter to run hdparm on the host.
DEVICE=$(readlink -f /dev/disk/by-uuid/${DRIVE_UUID})
docker run --rm --privileged --pid=host alpine \
    sh -c "apk add -q hdparm && nsenter -t 1 -m -- hdparm -S 241 ${DEVICE}" 2>/dev/null \
    && echo "Set spindown timer: 30 minutes" \
    || echo "WARNING: could not set spindown timer"
