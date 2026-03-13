#!/usr/bin/env python3
"""Off-site backup status display for NewsBlur.

Shows the last 3 backups per service in an ASCII table, plus disk usage and
current mongodump progress. Runs on the HA box.
"""

import glob
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta

BACKUP_DRIVE = "/media/newsblur-backup"
SHOW_N = 3
VERIFY_STATUS_FILE = os.path.join(BACKUP_DRIVE, "verify_status.json")
PROGRESS_FILE = os.path.join(BACKUP_DRIVE, "download_progress.json")

SERVICES = [
    ("MongoDB", "mongo_full", "mongodump_full_*.gz", r"mongodump_full_(\d{4}-\d{2}-\d{2})\.gz"),
    (
        "PostgreSQL",
        "postgres",
        "backup_postgresql_*.sql*",
        r"backup_postgresql_(\d{4}-\d{2}-\d{2}(?:-\d{2}-\d{2})?)",
    ),
    (
        "Redis Story",
        "redis/backup_hdb_redis_story_2",
        "*.rdb*",
        r"_(\d{4}-\d{2}-\d{2}-\d{2}-\d{2})\.rdb",
    ),
    ("Redis User", "redis/backup_hdb_redis_user_2", "*.rdb*", r"_(\d{4}-\d{2}-\d{2}-\d{2}-\d{2})\.rdb"),
    (
        "Redis Session",
        "redis/backup_hdb_redis_session_2",
        "*.rdb*",
        r"_(\d{4}-\d{2}-\d{2}-\d{2}-\d{2})\.rdb",
    ),
]


def format_size(size_bytes):
    if size_bytes >= 1024**3:
        return "%.1f GB" % (size_bytes / 1024**3)
    elif size_bytes >= 1024**2:
        return "%.1f MB" % (size_bytes / 1024**2)
    elif size_bytes >= 1024:
        return "%.1f KB" % (size_bytes / 1024)
    return "%d B" % size_bytes


def format_date(date_str):
    # "2026-03-04" or "2026-03-04-09-00" → "Mar 04" or "Mar 04 09:00"
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
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


def format_duration(seconds):
    seconds = int(seconds)
    if seconds < 60:
        return "%ds" % seconds
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    if hours > 0:
        return "%dh %dm" % (hours, minutes)
    return "%dm" % minutes


def get_mongo_start_time():
    """Parse the most recent 'Streaming full mongodump' timestamp from backup.log."""
    log_file = os.path.join(BACKUP_DRIVE, "backup.log")
    if not os.path.exists(log_file):
        return None
    try:
        result = subprocess.run(
            ["grep", "-n", "Streaming full mongodump", log_file], capture_output=True, text=True
        )
        lines = result.stdout.strip().split("\n")
        if lines and lines[-1]:
            # "2026-03-04 08:26:25 Streaming full mongodump from ..."
            match = re.match(r"(\d+:\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})", lines[-1])
            if match:
                ts_str = match.group(1).split(":", 1)[1]
                return datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S")
    except Exception:
        pass
    return None


def get_partial():
    partials = glob.glob(os.path.join(BACKUP_DRIVE, "mongo_full", "*.partial"))
    if partials:
        f = partials[0]
        basename = os.path.basename(f)
        # Extract date from mongodump_full_2026-03-04.gz.partial
        match = re.search(r"mongodump_full_(\d{4}-\d{2}-\d{2})\.gz\.partial", basename)
        date_str = match.group(1) if match else None
        size = os.path.getsize(f)
        # Elapsed time from mongodump start in backup.log
        start = get_mongo_start_time()
        elapsed = (datetime.now() - start).total_seconds() if start else 0
        return date_str, size, elapsed
    return None, None, None


def get_s3_partial(directory, date_regex):
    """Check for in-progress S3 download for this service."""
    full_dir = os.path.join(BACKUP_DRIVE, directory)
    if not os.path.isdir(full_dir):
        return None

    partials = glob.glob(os.path.join(full_dir, "*.partial"))
    if not partials:
        return None

    partial_file = partials[0]
    partial_size = os.path.getsize(partial_file)
    basename = os.path.basename(partial_file).replace(".partial", "")

    match = re.search(date_regex, basename)
    date_str = match.group(1) if match else None
    if not date_str:
        return None

    # Read progress JSON for total size and start time
    total_bytes = None
    start_time = None
    if os.path.exists(PROGRESS_FILE):
        try:
            with open(PROGRESS_FILE) as f:
                progress = json.load(f)
            if progress.get("local_dir", "").rstrip("/") == full_dir.rstrip("/"):
                total_bytes = progress.get("total_bytes")
                start_time = progress.get("start_time")
        except (IOError, json.JSONDecodeError):
            pass

    return date_str, partial_size, total_bytes, start_time


def get_mongodump_progress():
    """Returns progress as a float (0-100), 'complete', or None."""
    run_log = os.path.join(BACKUP_DRIVE, "backup_run.log")
    if not os.path.exists(run_log):
        return None
    try:
        result = subprocess.run(["tail", "-50", run_log], capture_output=True, text=True)
        lines = result.stdout.strip().split("\n")
        for line in reversed(lines):
            if "newsblur.stories" in line and "%" in line:
                match = re.search(r"\((\d+\.\d+)%\)", line)
                if match:
                    return float(match.group(1))
            # These markers mean a new dump started but hasn't reached
            # newsblur.stories yet — any older progress is stale
            if "done dumping newsblur.stories" in line:
                return "complete"
            if "Streaming full mongodump" in line or "--- MongoDB full dump" in line:
                return None
    except Exception:
        pass
    return None


def _parse_log_timestamp(log_line):
    """Extract datetime from a log line (format: '2026-03-04 08:26:25 ...')."""
    match = re.match(r"(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})", log_line)
    if not match:
        return None
    try:
        return datetime.strptime(match.group(1), "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None


# Max age (hours) before a phase marker is considered stale.
# If the backup process crashed, the marker stays in the log forever;
# these thresholds let us stop reporting it as "running".
_PHASE_MAX_AGE_HOURS = {
    "MongoDB": 25,  # mongodump streams for 12+ hours; timeout is 24h
}
_DEFAULT_MAX_AGE_HOURS = 1  # PostgreSQL, Redis, cleanup, etc. finish quickly


def _phase_is_stale(log_line, phase_name):
    """Check if a phase marker's timestamp is too old for that phase to still be running."""
    ts = _parse_log_timestamp(log_line)
    if ts is None:
        return True
    max_hours = _PHASE_MAX_AGE_HOURS.get(phase_name, _DEFAULT_MAX_AGE_HOURS)
    return (datetime.now() - ts) > timedelta(hours=max_hours)


def get_active_phase():
    """Determine if a backup is currently running and which phase it's in."""
    log_file = os.path.join(BACKUP_DRIVE, "backup.log")
    if not os.path.exists(log_file):
        return None
    try:
        result = subprocess.run(["tail", "-50", log_file], capture_output=True, text=True)
        lines = result.stdout.strip().split("\n")
        for line in reversed(lines):
            if "=== Backup pull complete ===" in line:
                return None
            if "--- Verifying backup integrity ---" in line:
                return None if _phase_is_stale(line, "verifying") else "verifying"
            if "--- Running local retention cleanup ---" in line:
                return None if _phase_is_stale(line, "cleanup") else "cleanup"
            if "--- MongoDB full dump" in line:
                return None if _phase_is_stale(line, "MongoDB") else "MongoDB"
            if "--- Redis backups from S3 ---" in line:
                return None if _phase_is_stale(line, "Redis") else "Redis"
            if "--- PostgreSQL backup from S3 ---" in line:
                return None if _phase_is_stale(line, "PostgreSQL") else "PostgreSQL"
            if "=== Starting NewsBlur off-site backup pull ===" in line:
                return None if _phase_is_stale(line, "starting") else "starting"
    except Exception:
        pass
    return None


BACKUP_SCHEDULE_HOUR = 6  # HA automation runs at 06:00 daily


def format_relative_time(dt):
    """Format a datetime as a human-readable relative string (e.g., '2h ago', 'in 5h 30m')."""
    now = datetime.now()
    delta = abs(now - dt)
    total_seconds = int(delta.total_seconds())
    if total_seconds < 60:
        rel = "just now"
    elif total_seconds < 3600:
        minutes = total_seconds // 60
        rel = "%dm" % minutes
    elif total_seconds < 86400:
        hours = total_seconds // 3600
        minutes = (total_seconds % 3600) // 60
        rel = "%dh %dm" % (hours, minutes) if minutes else "%dh" % hours
    else:
        days = total_seconds // 86400
        hours = (total_seconds % 86400) // 3600
        rel = "%dd %dh" % (days, hours) if hours else "%dd" % days

    if rel == "just now":
        return rel
    return "%s ago" % rel if dt < now else "in %s" % rel


def get_last_backup_time():
    """Find the timestamp of the most recent '=== Backup pull complete ===' in backup.log."""
    log_file = os.path.join(BACKUP_DRIVE, "backup.log")
    if not os.path.exists(log_file):
        return None
    try:
        result = subprocess.run(
            ["grep", "-n", "=== Backup pull complete ===", log_file], capture_output=True, text=True
        )
        lines = result.stdout.strip().split("\n")
        if lines and lines[-1]:
            ts = _parse_log_timestamp(lines[-1].split(":", 1)[1] if ":" in lines[-1] else lines[-1])
            return ts
    except Exception:
        pass
    return None


def get_next_backup_time():
    """Calculate the next scheduled backup (daily at BACKUP_SCHEDULE_HOUR:00)."""
    now = datetime.now()
    next_run = now.replace(hour=BACKUP_SCHEDULE_HOUR, minute=0, second=0, microsecond=0)
    if next_run <= now:
        next_run += timedelta(days=1)
    return next_run


def get_disk_usage():
    try:
        result = subprocess.run(["df", "-h", BACKUP_DRIVE], capture_output=True, text=True)
        lines = result.stdout.strip().split("\n")
        if len(lines) >= 2:
            parts = lines[1].split()
            return {"total": parts[1], "used": parts[2], "avail": parts[3], "pct": parts[4]}
    except Exception:
        pass
    return None


def load_verify_status():
    """Load verification results from JSON status file."""
    if not os.path.exists(VERIFY_STATUS_FILE):
        return None
    try:
        with open(VERIFY_STATUS_FILE) as f:
            return json.load(f)
    except (IOError, json.JSONDecodeError):
        return None


def format_verify_status(verify_data, service_name):
    """Return colored status string for a service's verification result."""
    if not verify_data:
        return "\033[2mnot verified\033[0m"

    results = verify_data.get("results", {})
    if service_name not in results:
        return "\033[2mnot verified\033[0m"

    result = results[service_name]
    if result.get("ok"):
        return "\033[32m✓ verified\033[0m"
    else:
        # Show first failing check
        checks = result.get("checks", [])
        fail = next((c for c in checks if c.startswith("FAIL")), "unknown failure")
        fail_msg = fail.replace("FAIL ", "", 1)[:40]
        return "\033[31m✗ %s\033[0m" % fail_msg


def print_table():
    # Header
    print()
    print("  \033[1mNewsBlur Off-site Backup Status\033[0m")
    print("  \033[2m%s\033[0m" % ("─" * 52))

    last = get_last_backup_time()
    if last:
        print(
            "  \033[2mLast backup: %s (%s)\033[0m"
            % (last.strftime("%Y-%m-%d %H:%M"), format_relative_time(last))
        )

    active = get_active_phase()
    if not active:
        next_run = get_next_backup_time()
        print(
            "  \033[2mNext backup: %s (%s)\033[0m"
            % (next_run.strftime("%Y-%m-%d %H:%M"), format_relative_time(next_run))
        )

    verify_data = load_verify_status()
    if verify_data:
        ts = verify_data.get("timestamp", "")
        print("  \033[2mLast verified: %s\033[0m" % ts)

    if active:
        if active == "starting":
            print("  \033[33m◀ Backup starting...\033[0m")
        elif active in ("cleanup", "verifying"):
            print("  \033[33m◀ Backup %s...\033[0m" % active)
        else:
            print("  \033[33m◀ Backup running (%s phase)\033[0m" % active)

    for service_name, directory, pattern, date_regex in SERVICES:
        backups = get_backups(directory, pattern, date_regex)

        # Service header
        print()
        print("  \033[1;36m%s\033[0m" % service_name)

        # For MongoDB, prepend in-progress partial as the first row
        partial_row = None
        if service_name == "MongoDB":
            partial_date, partial_bytes, elapsed = get_partial()
            if partial_date:
                progress = get_mongodump_progress()
                partial_size = format_size(partial_bytes)
                if partial_bytes > 0 and elapsed > 0:
                    elapsed_str = format_duration(elapsed)
                    bw = partial_bytes / elapsed
                    bw_str = format_size(bw) + "/s"
                    # Estimate remaining based on previous dump size
                    prev_size = backups[0][1] if backups else None
                    if prev_size and prev_size > partial_bytes:
                        remaining = (prev_size - partial_bytes) / bw
                        remaining_str = "~%s left" % format_duration(remaining)
                    else:
                        remaining_str = ""
                    pct_str = "%.1f%%" % progress if isinstance(progress, float) else ""
                    parts = [p for p in [pct_str, elapsed_str + " elapsed", remaining_str, bw_str] if p]
                    note = "  \033[33m◀ %s\033[0m" % " · ".join(parts)
                elif progress == "complete":
                    note = "  \033[32m◀ complete, finalizing…\033[0m"
                else:
                    elapsed_str = format_duration(elapsed) if elapsed else ""
                    note = "  \033[33m◀ starting… · %s elapsed\033[0m" % elapsed_str
                partial_row = (partial_date, partial_size, note)
        else:
            s3_info = get_s3_partial(directory, date_regex)
            if s3_info:
                p_date, p_bytes, p_total, p_start = s3_info
                p_size_str = format_size(p_bytes)
                elapsed = time.time() - p_start if p_start else 0
                parts = []
                if p_total and p_total > 0:
                    pct = (p_bytes / p_total) * 100
                    parts.append("%.1f%%" % pct)
                if elapsed > 0:
                    parts.append(format_duration(elapsed) + " elapsed")
                    bw = p_bytes / elapsed if elapsed > 0 else 0
                    if bw > 0:
                        parts.append(format_size(bw) + "/s")
                        if p_total and p_total > p_bytes:
                            remaining = (p_total - p_bytes) / bw
                            parts.append("~%s left" % format_duration(remaining))
                note = (
                    "  \033[33m◀ %s\033[0m" % " · ".join(parts)
                    if parts
                    else "  \033[33m◀ downloading...\033[0m"
                )
                partial_row = (p_date, p_size_str, note)

        if not backups and not partial_row:
            print("  \033[2m  (no backups found)\033[0m")
            continue

        # Table
        print("  ┌──────────────┬──────────┐")
        print("  │ \033[1mDate\033[0m         │ \033[1mSize\033[0m     │")
        print("  ├──────────────┼──────────┤")

        if partial_row:
            print("  │ %-12s │ %8s │%s" % (format_date(partial_row[0]), partial_row[1], partial_row[2]))

        for date_str, size, filename in backups:
            date_display = format_date(date_str)
            size_display = format_size(size)
            print("  │ %-12s │ %8s │" % (date_display, size_display))

        print("  └──────────────┴──────────┘")
        print("  %s" % format_verify_status(verify_data, service_name))

    # Disk usage
    disk = get_disk_usage()
    if disk:
        print()
        print(
            "  \033[2mDisk: %s used / %s total (%s free)\033[0m"
            % (disk["used"], disk["total"], disk["avail"])
        )

    print()


if __name__ == "__main__":
    print_table()
