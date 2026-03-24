#!/usr/bin/env bash
# unmount_backup_drive.sh - Unmount and power off the NewsBlur backup drive
#
# Runs via nsenter on the host so it works from any container.
# Deauthorizes the USB device to cut power — unbind alone doesn't stick
# because udev re-binds it. Neither hdparm nor sg_start work through
# the Sabrent USB-SATA bridge.

USB_DEVICE="2-1"  # USB port the drive is on (see: readlink /sys/block/sda)
HOST_MOUNT_POINT="/mnt/data/supervisor/media/newsblur-backup"

nsenter_run() {
    docker run --rm --privileged --pid=host alpine nsenter -t 1 -m -- "$@"
}

if nsenter_run mountpoint -q "${HOST_MOUNT_POINT}" 2>/dev/null; then
    nsenter_run sync
    # Retry unmount a few times — processes that just finished reading may
    # still hold brief references to the mount.
    for attempt in 1 2 3 4 5; do
        if nsenter_run umount "${HOST_MOUNT_POINT}" 2>/dev/null; then
            echo "Unmounted ${HOST_MOUNT_POINT}"
            break
        fi
        if [ "$attempt" -eq 5 ]; then
            echo "WARNING: regular unmount failed after 5 attempts, using lazy unmount"
            nsenter_run umount -l "${HOST_MOUNT_POINT}" \
                && echo "Lazy-unmounted ${HOST_MOUNT_POINT}" \
                || { echo "ERROR: could not unmount ${HOST_MOUNT_POINT}"; exit 1; }
        fi
        sleep 1
    done
else
    echo "Not mounted"
fi

# Deauthorize the USB device to power it off and prevent udev from re-binding
if nsenter_run test -d "/sys/bus/usb/devices/${USB_DEVICE}"; then
    nsenter_run sh -c "echo 0 > /sys/bus/usb/devices/${USB_DEVICE}/authorized" \
        && echo "USB device deauthorized (drive powered off)" \
        || echo "WARNING: could not deauthorize USB device"
else
    echo "USB device not present"
fi
