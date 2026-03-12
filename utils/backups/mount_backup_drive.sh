#!/usr/bin/env bash
# mount_backup_drive.sh - Mount the NewsBlur backup drive on the HA box
#
# Mounts with noatime to prevent unnecessary writes (access time updates)
# and sets a spindown timer so the drive stops spinning when idle.
#
# All mount/umount/hdparm ops run via nsenter on the host, since both the
# SSH add-on and HA Core containers lack direct mount namespace access.
# The host path /mnt/data/supervisor/media/ maps to /media/ inside containers.

DRIVE_UUID="ef981d62-7a0b-4858-9ee9-38db68f1e46f"
HOST_MOUNT_POINT="/mnt/data/supervisor/media/newsblur-backup"

nsenter_run() {
    docker run --rm --privileged --pid=host alpine nsenter -t 1 -m -- "$@"
}

if nsenter_run mountpoint -q "${HOST_MOUNT_POINT}" 2>/dev/null; then
    echo "Already mounted"
    exit 0
fi

nsenter_run mkdir -p "${HOST_MOUNT_POINT}"
nsenter_run mount -o noatime "/dev/disk/by-uuid/${DRIVE_UUID}" "${HOST_MOUNT_POINT}"
echo "Mounted ${HOST_MOUNT_POINT}"

# Set spindown after 30 minutes of inactivity
# hdparm -S 241 = 30 minutes (vendor-specific encoding for values > 240)
DEVICE=$(nsenter_run readlink -f "/dev/disk/by-uuid/${DRIVE_UUID}")
docker run --rm --privileged --pid=host alpine \
    sh -c "apk add -q hdparm && nsenter -t 1 -m -- hdparm -S 241 ${DEVICE}" 2>/dev/null \
    && echo "Set spindown timer: 30 minutes" \
    || echo "WARNING: could not set spindown timer"
