#!/usr/bin/env bash
# mount_backup_drive.sh - Mount the NewsBlur backup drive on the HA box
#
# Mounts with noatime to prevent unnecessary writes (access time updates).
#
# All ops run via nsenter on the host, since both the SSH add-on and HA Core
# containers lack direct mount namespace access.
# The host path /mnt/data/supervisor/media/ maps to /media/ inside containers.

DRIVE_UUID="ef981d62-7a0b-4858-9ee9-38db68f1e46f"
USB_DEVICE="2-1"  # USB port the drive is on (see: readlink /sys/block/sda)
HOST_MOUNT_POINT="/mnt/data/supervisor/media/newsblur-backup"

nsenter_run() {
    docker run --rm --privileged --pid=host alpine nsenter -t 1 -m -- "$@"
}

if nsenter_run mountpoint -q "${HOST_MOUNT_POINT}" 2>/dev/null; then
    echo "Already mounted"
    exit 0
fi

# Wake up USB device if it was deauthorized (by unmount_backup_drive.sh).
# Re-authorizing alone doesn't trigger storage enumeration, so we unbind+bind
# to force a full USB reset after authorizing.
AUTH=$(nsenter_run cat "/sys/bus/usb/devices/${USB_DEVICE}/authorized" 2>/dev/null)
if [ "$AUTH" = "0" ]; then
    echo "Waking USB device..."
    nsenter_run sh -c "echo 1 > /sys/bus/usb/devices/${USB_DEVICE}/authorized"
    sleep 1
    nsenter_run sh -c "echo ${USB_DEVICE} > /sys/bus/usb/drivers/usb/unbind" 2>/dev/null
    sleep 1
    nsenter_run sh -c "echo ${USB_DEVICE} > /sys/bus/usb/drivers/usb/bind" 2>/dev/null
    # Wait for the block device to appear (drive needs to spin up)
    for i in $(seq 1 30); do
        if nsenter_run test -e "/dev/disk/by-uuid/${DRIVE_UUID}"; then
            break
        fi
        sleep 1
    done
    if ! nsenter_run test -e "/dev/disk/by-uuid/${DRIVE_UUID}"; then
        echo "ERROR: drive did not appear after USB wake (waited 30s)"
        exit 1
    fi
fi

nsenter_run mkdir -p "${HOST_MOUNT_POINT}"
nsenter_run mount -o noatime "/dev/disk/by-uuid/${DRIVE_UUID}" "${HOST_MOUNT_POINT}"
echo "Mounted ${HOST_MOUNT_POINT}"
