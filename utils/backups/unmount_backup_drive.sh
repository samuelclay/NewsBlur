#!/usr/bin/env bash
# unmount_backup_drive.sh - Unmount and power off the NewsBlur backup drive
#
# Runs via nsenter on the host so it works from any container.
# Deauthorizes the USB device to cut power — unbind alone doesn't stick
# because udev re-binds it. Neither hdparm nor sg_start work through
# the Sabrent USB-SATA bridge.
#
# Power is only cut after a clean unmount. If something still has files open
# on the drive, it is left mounted and powered and this exits non-zero. This
# used to fall back to a lazy unmount and deauthorize anyway, which pulls power
# out from under a filesystem that is still live. From September to October
# 2026 that aborted the ext4 journal with I/O errors after every nightly pull,
# because the cron job's log redirect kept a file open on the drive (see
# run_offsite_backup.sh, which now owns the mount/unmount around a pull).

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
            echo "ERROR: ${HOST_MOUNT_POINT} still busy after 5 attempts, leaving the drive mounted and powered on" >&2
            echo "Processes with files open on it:" >&2
            nsenter_run fuser -vm "${HOST_MOUNT_POINT}" >&2
            exit 1
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
