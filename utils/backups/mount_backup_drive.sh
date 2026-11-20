#!/usr/bin/env bash
# mount_backup_drive.sh - Mount the NewsBlur backup drive on the HA box
#
# Mounts with noatime to prevent unnecessary writes (access time updates).
#
# Exits non-zero unless the drive really is mounted afterwards. Callers
# (run_offsite_backup.sh, `make offsite-backup-status`) depend on that: the
# mount point is also a plain directory on HA's own 115 GB eMMC, so anything
# that carries on after a failed mount reads or writes the eMMC instead. Until
# October 2026 a failed mount still exited 0 and the status check reported
# "last backup March 31" from the empty directory while backups were fine.
#
# All ops run via nsenter on the host, since both the SSH add-on and HA Core
# containers lack direct mount namespace access.
# The host path /mnt/data/supervisor/media/ maps to /media/ inside containers.

DRIVE_UUID="ef981d62-7a0b-4858-9ee9-38db68f1e46f"
DRIVE_DEV="/dev/disk/by-uuid/${DRIVE_UUID}"
USB_DEVICE="2-1"  # USB port the drive is on (see: readlink /sys/block/sda)
HOST_MOUNT_POINT="/mnt/data/supervisor/media/newsblur-backup"
MOUNT_ATTEMPTS=3
DRIVE_WAIT_SECONDS=60

nsenter_run() {
    docker run --rm --privileged --pid=host alpine nsenter -t 1 -m -- "$@"
}

# Power the drive back on after unmount_backup_drive.sh deauthorized it.
# Authorizing starts a probe while the drive is still spinning up, and that
# probe can't read the drive's cache mode ("Asking for cache data failed", so
# the kernel assumes write-through and never flushes the drive's write cache)
# and sometimes not even its partition table. Unbind+bind re-probes the drive
# once it has spun up. The unbind blocks until the first probe finishes.
wake_usb_device() {
    echo "Waking USB device..."
    nsenter_run sh -c "echo 1 > /sys/bus/usb/devices/${USB_DEVICE}/authorized"
    sleep 1
    nsenter_run sh -c "echo ${USB_DEVICE} > /sys/bus/usb/drivers/usb/unbind" 2>/dev/null
    sleep 1
    nsenter_run sh -c "echo ${USB_DEVICE} > /sys/bus/usb/drivers/usb/bind" 2>/dev/null
}

# Wait for udev to finish handling the drive's events and for the filesystem's
# by-uuid link to resolve to a block device.
wait_for_drive() {
    local deadline=$((SECONDS + DRIVE_WAIT_SECONDS))
    while (( SECONDS < deadline )); do
        if nsenter_run sh -c "udevadm settle --timeout=10; test -b '${DRIVE_DEV}'"; then
            return 0
        fi
        sleep 1
    done
    return 1
}

if nsenter_run mountpoint -q "${HOST_MOUNT_POINT}" 2>/dev/null; then
    echo "Already mounted"
    exit 0
fi

AUTH=$(nsenter_run cat "/sys/bus/usb/devices/${USB_DEVICE}/authorized" 2>/dev/null)
if [ "$AUTH" = "0" ]; then
    wake_usb_device
fi

nsenter_run mkdir -p "${HOST_MOUNT_POINT}"

# The by-uuid link from the first probe can still be there when the re-probe
# tears the disk down, so a single mount sometimes failed with "Can't lookup
# blockdev". Retry after udev settles, and re-probe if the drive never shows up.
for attempt in $(seq 1 "${MOUNT_ATTEMPTS}"); do
    if ! wait_for_drive; then
        echo "Drive did not appear within ${DRIVE_WAIT_SECONDS}s (attempt ${attempt}/${MOUNT_ATTEMPTS})" >&2
        wake_usb_device
        continue
    fi
    if nsenter_run mount -o noatime "${DRIVE_DEV}" "${HOST_MOUNT_POINT}"; then
        break
    fi
    echo "Mount failed (attempt ${attempt}/${MOUNT_ATTEMPTS}), retrying" >&2
    sleep 5
done

if ! nsenter_run mountpoint -q "${HOST_MOUNT_POINT}"; then
    echo "ERROR: could not mount backup drive ${DRIVE_UUID} at ${HOST_MOUNT_POINT}" >&2
    exit 1
fi
echo "Mounted ${HOST_MOUNT_POINT}"
