#!/usr/bin/env python3
"""Off-site backup status display for NewsBlur.

Shows the last 3 backups per service in an ASCII table, plus disk usage and
current mongodump progress. Runs on the HA box.
"""

import glob
import os
import re
import subprocess
import sys

BACKUP_DRIVE = "/media/newsblur-backup"
SHOW_N = 3

SERVICES = [
    ("MongoDB", "mongo_full", "mongodump_full_*.gz", r"mongodump_full_(\d{4}-\d{2}-\d{2})\.gz"),
    ("PostgreSQL", "postgres", "backup_postgresql_*.sql*", r"backup_postgresql_(\d{4}-\d{2}-\d{2}(?:-\d{2}-\d{2})?)"),
    ("Redis Story", "redis/backup_hdb_redis_story_2", "*.rdb.gz", r"_(\d{4}-\d{2}-\d{2}-\d{2}-\d{2})\.rdb\.gz"),
    ("Redis User", "redis/backup_hdb_redis_user_2", "*.rdb.gz", r"_(\d{4}-\d{2}-\d{2}-\d{2}-\d{2})\.rdb\.gz"),
    ("Redis Session", "redis/backup_hdb_redis_session_2", "*.rdb.gz", r"_(\d{4}-\d{2}-\d{2}-\d{2}-\d{2})\.rdb\.gz"),
]


def format_size(size_bytes):
    if size_bytes >= 1024 ** 3:
        return "%.1f GB" % (size_bytes / 1024 ** 3)
    elif size_bytes >= 1024 ** 2:
        return "%.1f MB" % (size_bytes / 1024 ** 2)
    elif size_bytes >= 1024:
        return "%.1f KB" % (size_bytes / 1024)
    return "%d B" % size_bytes


def format_date(date_str):
    # "2026-03-04" or "2026-03-04-09-00" → "Mar 04" or "Mar 04 09:00"
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    parts = date_str.split("-")
    month = months[int(parts[1]) - 1]
    day = parts[2]
    if len(parts) >= 5:
        return "%s %s %s:%s" % (month, day, parts[3], parts[4])
    return "%s %s" % (month, day)


def get_backups(directory, pattern, date_regex):
    full_dir = os.path.join(BACKUP_DRIVE, directory)
    if not os.path.isdir(full_dir):
        return []

    files = glob.glob(os.path.join(full_dir, pattern))
    backups = []
    for f in files:
        if f.endswith(".partial"):
            continue
        basename = os.path.basename(f)
        match = re.search(date_regex, basename)
        if match:
            date_str = match.group(1)
            size = os.path.getsize(f)
            backups.append((date_str, size, basename))

    backups.sort(reverse=True)
    return backups[:SHOW_N]


def get_partial():
    partials = glob.glob(os.path.join(BACKUP_DRIVE, "mongo_full", "*.partial"))
    if partials:
        f = partials[0]
        basename = os.path.basename(f)
        # Extract date from mongodump_full_2026-03-04.gz.partial
        match = re.search(r"mongodump_full_(\d{4}-\d{2}-\d{2})\.gz\.partial", basename)
        date_str = match.group(1) if match else None
        return date_str, format_size(os.path.getsize(f))
    return None, None


def get_mongodump_progress():
    run_log = os.path.join(BACKUP_DRIVE, "backup_run.log")
    if not os.path.exists(run_log):
        return None
    try:
        # Read last 20 lines looking for progress
        result = subprocess.run(
            ["tail", "-20", run_log], capture_output=True, text=True
        )
        lines = result.stdout.strip().split("\n")
        for line in reversed(lines):
            if "newsblur.stories" in line and "%" in line:
                match = re.search(r"\((\d+\.\d+)%\)", line)
                if match:
                    return match.group(1) + "%"
        # Check for "done dumping"
        for line in reversed(lines):
            if "done dumping newsblur.stories" in line:
                return "complete"
    except Exception:
        pass
    return None


def get_disk_usage():
    try:
        result = subprocess.run(
            ["df", "-h", BACKUP_DRIVE], capture_output=True, text=True
        )
        lines = result.stdout.strip().split("\n")
        if len(lines) >= 2:
            parts = lines[1].split()
            return {"total": parts[1], "used": parts[2], "avail": parts[3], "pct": parts[4]}
    except Exception:
        pass
    return None


def print_table():
    # Header
    print()
    print("  \033[1mNewsBlur Off-site Backup Status\033[0m")
    print("  \033[2m%s\033[0m" % ("─" * 52))

    for service_name, directory, pattern, date_regex in SERVICES:
        backups = get_backups(directory, pattern, date_regex)

        # Service header
        print()
        print("  \033[1;36m%s\033[0m" % service_name)

        # For MongoDB, prepend in-progress partial as the first row
        partial_row = None
        if service_name == "MongoDB":
            partial_date, partial_size = get_partial()
            if partial_date:
                progress = get_mongodump_progress()
                if progress and progress != "complete":
                    note = "  \033[33m◀ %s\033[0m" % progress
                else:
                    note = "  \033[33m◀ streaming…\033[0m"
                partial_row = (partial_date, partial_size, note)

        if not backups and not partial_row:
            print("  \033[2m  (no backups found)\033[0m")
            continue

        # Table
        print("  ┌──────────────┬──────────┐")
        print("  │ \033[1mDate\033[0m         │ \033[1mSize\033[0m     │")
        print("  ├──────────────┼──────────┤")

        if partial_row:
            print("  │ %-12s │ %8s │%s" % (
                format_date(partial_row[0]), partial_row[1], partial_row[2]))

        for date_str, size, filename in backups:
            date_display = format_date(date_str)
            size_display = format_size(size)
            print("  │ %-12s │ %8s │" % (date_display, size_display))

        print("  └──────────────┴──────────┘")

    # Disk usage
    disk = get_disk_usage()
    if disk:
        print()
        print("  \033[2mDisk: %s used / %s total (%s free)\033[0m" % (
            disk["used"], disk["total"], disk["avail"]))

    print()


if __name__ == "__main__":
    print_table()
