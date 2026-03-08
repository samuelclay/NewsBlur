#!/usr/bin/env python3
"""Backup verification for NewsBlur offsite backups.

Runs on the HA box after offsite_pull.sh. Checks:
1. Size anomaly detection: alerts if newest backup is >40% smaller than previous
2. Staleness: alerts if no backup exists from the last 3 days
3. File integrity: gunzip -t for compressed files, pg_restore --list for postgres

Writes results to verify_status.json for offsite_status.py to display.
Sends email alert via Mailgun on any failure.
"""

import glob
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timedelta

BACKUP_DRIVE = "/media/newsblur-backup"
STATUS_FILE = os.path.join(BACKUP_DRIVE, "verify_status.json")
MAILGUN_CREDS_FILE = "/config/scripts/mailgun_credentials"
ALERT_EMAIL = "samuel@newsblur.com"

# Size drop threshold: alert if newest is less than this fraction of previous
SIZE_DROP_THRESHOLD = 0.60  # 40% drop

# Staleness: alert if no backup newer than this many days
STALENESS_DAYS = 3

# Same structure as offsite_status.py SERVICES
SERVICES = [
    {
        "name": "MongoDB",
        "directory": "mongo_full",
        "pattern": "mongodump_full_*.gz",
        "date_regex": r"mongodump_full_(\d{4}-\d{2}-\d{2})\.gz",
        "integrity_cmd": "gunzip",
    },
    {
        "name": "PostgreSQL",
        "directory": "postgres",
        "pattern": "backup_postgresql_*.sql*",
        "date_regex": r"backup_postgresql_(\d{4}-\d{2}-\d{2}(?:-\d{2}-\d{2})?)",
        "integrity_cmd": "pg_restore",
    },
    {
        "name": "Redis Story",
        "directory": "redis/backup_hdb_redis_story_2",
        "pattern": "*.rdb*",
        "date_regex": r"_(\d{4}-\d{2}-\d{2}-\d{2}-\d{2})\.rdb",
        "integrity_cmd": "rdb",
    },
    {
        "name": "Redis User",
        "directory": "redis/backup_hdb_redis_user_2",
        "pattern": "*.rdb*",
        "date_regex": r"_(\d{4}-\d{2}-\d{2}-\d{2}-\d{2})\.rdb",
        "integrity_cmd": "rdb",
    },
    {
        "name": "Redis Session",
        "directory": "redis/backup_hdb_redis_session_2",
        "pattern": "*.rdb*",
        "date_regex": r"_(\d{4}-\d{2}-\d{2}-\d{2}-\d{2})\.rdb",
        "integrity_cmd": "rdb",
    },
]


def format_size(size_bytes):
    if size_bytes >= 1024**3:
        return "%.1f GB" % (size_bytes / 1024**3)
    elif size_bytes >= 1024**2:
        return "%.1f MB" % (size_bytes / 1024**2)
    elif size_bytes >= 1024:
        return "%.1f KB" % (size_bytes / 1024)
    return "%d B" % size_bytes


def get_backups(directory, pattern, date_regex):
    """Get sorted list of (date_str, size_bytes, filepath) tuples, newest first."""
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
            backups.append((date_str, size, f))

    backups.sort(reverse=True)
    return backups


def parse_date(date_str):
    """Parse date string from backup filename."""
    for fmt in ["%Y-%m-%d-%H-%M", "%Y-%m-%d"]:
        try:
            return datetime.strptime(date_str, fmt)
        except ValueError:
            continue
    return None


def check_size_anomaly(service_name, backups):
    """Check if newest backup has suspicious size drop. Returns (ok, message)."""
    if len(backups) < 2:
        return True, "only %d backup(s), skipping size comparison" % len(backups)

    newest_date, newest_size, _ = backups[0]
    prev_date, prev_size, _ = backups[1]

    if prev_size == 0:
        return True, "previous backup is 0 bytes, skipping comparison"

    ratio = newest_size / prev_size
    newest_fmt = format_size(newest_size)
    prev_fmt = format_size(prev_size)

    if ratio < SIZE_DROP_THRESHOLD:
        drop_pct = (1 - ratio) * 100
        return False, "size: %s (vs prev %s) — %.0f%% DROP" % (newest_fmt, prev_fmt, drop_pct)

    return True, "size: %s (vs prev %s)" % (newest_fmt, prev_fmt)


def check_staleness(service_name, backups):
    """Check if most recent backup is too old. Returns (ok, message)."""
    if not backups:
        return False, "no backups found"

    newest_date_str = backups[0][0]
    newest_date = parse_date(newest_date_str)
    if not newest_date:
        return False, "could not parse date: %s" % newest_date_str

    cutoff = datetime.now() - timedelta(days=STALENESS_DAYS)
    if newest_date < cutoff:
        age_days = (datetime.now() - newest_date).days
        return False, "newest backup is %d days old (%s)" % (age_days, newest_date_str)

    return True, "fresh (%s)" % newest_date_str


# Skip gunzip -t for files larger than 50GB (too slow on HA box)
INTEGRITY_SIZE_LIMIT = 50 * 1024**3


def check_integrity(service_name, backups, integrity_cmd):
    """Run integrity check on the most recent backup. Returns (ok, message)."""
    if not backups:
        return True, "no file to check"

    filepath = backups[0][2]
    file_size = backups[0][1]

    if integrity_cmd == "gunzip" and file_size > INTEGRITY_SIZE_LIMIT:
        return True, "skipped gunzip -t (%s too large)" % format_size(file_size)

    if integrity_cmd == "gunzip":
        try:
            result = subprocess.run(["gunzip", "-t", filepath], capture_output=True, text=True, timeout=3600)
            if result.returncode == 0:
                return True, "gunzip -t: passed"
            else:
                return False, "gunzip -t: FAILED — %s" % result.stderr.strip()
        except subprocess.TimeoutExpired:
            return False, "gunzip -t: timed out (1h)"
        except FileNotFoundError:
            return True, "gunzip not available, skipped"

    elif integrity_cmd == "rdb":
        # Verify RDB file by checking magic bytes header
        try:
            with open(filepath, "rb") as f:
                magic = f.read(5)
            if magic == b"REDIS":
                return True, "RDB magic bytes: valid"
            else:
                return False, "RDB magic bytes: INVALID (got %r)" % magic
        except IOError as e:
            return False, "could not read file: %s" % e

    elif integrity_cmd == "pg_restore":
        if not shutil.which("pg_restore"):
            return True, "pg_restore not available, skipped"
        try:
            result = subprocess.run(
                ["pg_restore", "--list", filepath], capture_output=True, text=True, timeout=60
            )
            if result.returncode == 0:
                lines = result.stdout.strip().split("\n")
                return True, "pg_restore --list: passed (%d entries)" % len(lines)
            else:
                return False, "pg_restore --list: FAILED — %s" % result.stderr.strip()[:200]
        except subprocess.TimeoutExpired:
            return False, "pg_restore --list: timed out"
        except FileNotFoundError:
            return True, "pg_restore not available, skipped"

    return True, "no integrity check for this type"


def send_alert(failures):
    """Send email alert via Mailgun for failed checks."""
    if not os.path.exists(MAILGUN_CREDS_FILE):
        print("WARNING: Mailgun credentials not found at %s, cannot send alert" % MAILGUN_CREDS_FILE)
        return

    try:
        with open(MAILGUN_CREDS_FILE) as f:
            lines = f.read().strip().split("\n")
            api_key = lines[0].strip()
            domain = lines[1].strip()
    except (IndexError, IOError) as e:
        print("WARNING: Could not read Mailgun credentials: %s" % e)
        return

    subject = "NewsBlur Backup Verification FAILED: %s" % ", ".join(f["name"] for f in failures)

    body_lines = ["NewsBlur backup verification failed on %s\n" % datetime.now().strftime("%Y-%m-%d %H:%M")]
    for f in failures:
        body_lines.append("=== %s ===" % f["name"])
        for check in f["checks"]:
            body_lines.append("  %s" % check)
        body_lines.append("")

    body = "\n".join(body_lines)

    try:
        import requests

        requests.post(
            "https://api.mailgun.net/v3/%s/messages" % domain,
            auth=("api", api_key),
            data={
                "from": "NewsBlur Backup Verify <admin@%s>" % domain,
                "to": [ALERT_EMAIL],
                "subject": subject,
                "text": body,
            },
        )
        print("Alert email sent to %s" % ALERT_EMAIL)
    except Exception as e:
        print("WARNING: Failed to send alert email: %s" % e)


def main():
    results = {}
    failures = []

    for service in SERVICES:
        name = service["name"]
        backups = get_backups(service["directory"], service["pattern"], service["date_regex"])

        checks = []
        all_ok = True

        # 1. Staleness
        ok, msg = check_staleness(name, backups)
        checks.append(("PASS" if ok else "FAIL") + " " + msg)
        if not ok:
            all_ok = False

        # 2. Size anomaly
        ok, msg = check_size_anomaly(name, backups)
        checks.append(("PASS" if ok else "FAIL") + " " + msg)
        if not ok:
            all_ok = False

        # 3. Integrity
        ok, msg = check_integrity(name, backups, service["integrity_cmd"])
        checks.append(("PASS" if ok else "FAIL") + " " + msg)
        if not ok:
            all_ok = False

        status = "OK" if all_ok else "FAILED"
        print("[%s] %s" % (status, name))
        for check in checks:
            print("  %s" % check)

        results[name] = {"ok": all_ok, "checks": [c for c in checks]}

        if not all_ok:
            failures.append({"name": name, "checks": checks})

    # Write status file
    status_data = {
        "timestamp": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
        "results": results,
    }
    try:
        with open(STATUS_FILE, "w") as f:
            json.dump(status_data, f, indent=2)
    except IOError as e:
        print("WARNING: Could not write status file: %s" % e)

    # Send alert if any failures
    if failures:
        print("\n%d service(s) FAILED verification" % len(failures))
        send_alert(failures)
        return 1
    else:
        print("\nAll services passed verification")
        return 0


if __name__ == "__main__":
    sys.exit(main())
