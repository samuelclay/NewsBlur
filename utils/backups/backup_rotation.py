#!/usr/bin/python3
"""
Shared backup rotation module for NewsBlur S3 backups.

Provides upload and grandfather-father-son rotation for all backup types
(MongoDB, PostgreSQL, Redis). Retention policy:
- 7 daily backups (most recent)
- 4 weekly backups (1 per week beyond dailies)
- 6 monthly backups (1 per month beyond weeklies)
- Yearly backups kept forever (1 per year)
"""

import os
import re
import sys
import threading
from datetime import datetime, timedelta

import boto3

from newsblur_web import settings


class ProgressPercentage:
    def __init__(self, filename):
        self._filename = filename
        self._size = float(os.path.getsize(filename))
        self._seen_so_far = 0
        self._lock = threading.Lock()

    def __call__(self, bytes_amount):
        with self._lock:
            self._seen_so_far += bytes_amount
            percentage = (self._seen_so_far / self._size) * 100
            sys.stdout.write(
                "\r%s  %s / %s  (%.2f%%)" % (self._filename, self._seen_so_far, self._size, percentage)
            )
            sys.stdout.flush()


def upload_to_s3(file_path, bucket, key):
    """Upload a file to S3 with progress reporting."""
    client = boto3.client(
        "s3", aws_access_key_id=settings.S3_ACCESS_KEY, aws_secret_access_key=settings.S3_SECRET
    )
    print("Uploading %s to s3://%s/%s" % (file_path, bucket, key))
    client.upload_file(file_path, bucket, key, Callback=ProgressPercentage(file_path))
    print()  # newline after progress


def rotate_s3_backups(bucket_name, key_prefix, key_ext, dry_run=False, daily=7, weekly=4, monthly=6):
    """
    Grandfather-father-son rotation for S3 backups.

    Retention:
    - Keep the most recent `daily` backups
    - Keep 1 backup per week for `weekly` weeks beyond the daily window
    - Keep 1 backup per month for `monthly` months beyond the weekly window
    - Keep 1 backup per year forever

    Keys must match: {key_prefix}_YYYY-MM-DD-HH-MM{key_ext}

    Returns (kept_count, deleted_count).
    """
    session = boto3.Session(
        aws_access_key_id=settings.S3_ACCESS_KEY, aws_secret_access_key=settings.S3_SECRET
    )
    s3 = session.resource("s3")
    bucket = s3.Bucket(bucket_name)

    # Escape dots in extension for regex
    ext_escaped = re.escape(key_ext)
    regex = re.compile(
        r"^%s_(\d{4})-(\d{2})-(\d{2})-(\d{2})-(\d{2})%s$" % (re.escape(key_prefix), ext_escaped)
    )

    # Parse all backups
    all_backups = []
    for obj in bucket.objects.filter(Prefix=key_prefix):
        match = regex.match(obj.key)
        if not match:
            continue
        backup_date = datetime(
            int(match.group(1)),
            int(match.group(2)),
            int(match.group(3)),
            int(match.group(4)),
            int(match.group(5)),
        )
        all_backups.append((backup_date, obj.key))

    all_backups.sort(reverse=True)  # newest first

    if not all_backups:
        print("  No backups found matching %s_*%s" % (key_prefix, key_ext))
        return 0, 0

    print("  Found %d backups for %s" % (len(all_backups), key_prefix))

    now = datetime.utcnow()
    keep = set()

    # 1. Daily: keep the N most recent backups
    for backup_date, key in all_backups[:daily]:
        keep.add(key)

    # 2. Weekly: for each of the last `weekly` weeks before the daily window,
    #    keep the most recent backup in that week
    daily_cutoff = now - timedelta(days=daily)
    for week_offset in range(weekly):
        week_end = daily_cutoff - timedelta(weeks=week_offset)
        week_start = week_end - timedelta(weeks=1)
        for backup_date, key in all_backups:
            if week_start <= backup_date < week_end:
                keep.add(key)
                break  # most recent in this week (list is sorted newest-first)

    # 3. Monthly: for each of the last `monthly` months before the weekly window
    weekly_cutoff = daily_cutoff - timedelta(weeks=weekly)
    for month_offset in range(monthly):
        month_end = weekly_cutoff - timedelta(days=30 * month_offset)
        month_start = month_end - timedelta(days=30)
        for backup_date, key in all_backups:
            if month_start <= backup_date < month_end:
                keep.add(key)
                break

    # 4. Yearly: for all backups older than the monthly window,
    #    keep the most recent per calendar year
    monthly_cutoff = weekly_cutoff - timedelta(days=30 * monthly)
    years_seen = set()
    for backup_date, key in all_backups:
        if backup_date < monthly_cutoff and backup_date.year not in years_seen:
            years_seen.add(backup_date.year)
            keep.add(key)

    # Delete everything not in keep set
    deleted = 0
    for backup_date, key in all_backups:
        if key not in keep:
            if dry_run:
                print("  [DRY RUN] Would delete: %s (%s)" % (key, backup_date.strftime("%Y-%m-%d")))
            else:
                bucket.Object(key).delete()
                print("  Deleted: %s (%s)" % (key, backup_date.strftime("%Y-%m-%d")))
            deleted += 1

    kept = len(keep)
    prefix = "[DRY RUN] " if dry_run else ""
    print("  %sRotation complete: kept %d, deleted %d" % (prefix, kept, deleted))
    return kept, deleted


def cleanup_s3_prefix(bucket_name, prefix, keep=1, dry_run=False):
    """
    One-time cleanup of an S3 prefix. Keeps the N most recent objects, deletes the rest.
    Used for cleaning up backups from decommissioned servers.
    """
    session = boto3.Session(
        aws_access_key_id=settings.S3_ACCESS_KEY, aws_secret_access_key=settings.S3_SECRET
    )
    s3 = session.resource("s3")
    bucket = s3.Bucket(bucket_name)

    objects = []
    for obj in bucket.objects.filter(Prefix=prefix):
        objects.append((obj.last_modified, obj.key, obj.size))

    objects.sort(reverse=True)  # newest first

    if not objects:
        print("No objects found with prefix: %s" % prefix)
        return 0, 0

    total_size = sum(o[2] for o in objects)
    print("Found %d objects (%.2f GB) with prefix: %s" % (len(objects), total_size / 1024 / 1024 / 1024, prefix))

    # Keep the N most recent
    to_keep = objects[:keep]
    to_delete = objects[keep:]

    delete_size = sum(o[2] for o in to_delete)
    print("Keeping %d, deleting %d (%.2f GB)" % (len(to_keep), len(to_delete), delete_size / 1024 / 1024 / 1024))

    deleted = 0
    for _, key, size in to_delete:
        if dry_run:
            print("  [DRY RUN] Would delete: %s (%.2f MB)" % (key, size / 1024 / 1024))
        else:
            bucket.Object(key).delete()
            deleted += 1
            if deleted % 100 == 0:
                print("  Deleted %d / %d objects..." % (deleted, len(to_delete)))

    prefix_label = "[DRY RUN] " if dry_run else ""
    print("%sCleanup complete: kept %d, deleted %d" % (prefix_label, len(to_keep), deleted))
    return len(to_keep), deleted


if __name__ == "__main__":
    """
    CLI for testing rotation and cleanup in dry-run mode.

    Usage (run from a server with S3 access):
      python backup_rotation.py dry-run          # Dry-run rotation on all backup prefixes
      python backup_rotation.py rotate            # Actually rotate all backup prefixes
      python backup_rotation.py cleanup-secondary # Clean up dead backup_hdb_redis_secondary/ prefix
    """
    import socket

    if len(sys.argv) < 2 or sys.argv[1] not in ("dry-run", "rotate", "cleanup-secondary"):
        print("Usage: python backup_rotation.py [dry-run|rotate|cleanup-secondary]")
        sys.exit(1)

    command = sys.argv[1]
    bucket = settings.S3_BACKUP_BUCKET
    dry = command == "dry-run"

    if command in ("dry-run", "rotate"):
        hostname = socket.gethostname().replace("-", "_")

        print("\n=== MongoDB backups ===")
        rotate_s3_backups(bucket, "backup_db_mongo/backup_mongo", ".tgz", dry_run=dry)

        print("\n=== PostgreSQL backups (.sql) ===")
        rotate_s3_backups(bucket, "backup_%s/backup_postgresql" % hostname, ".sql", dry_run=dry)

        print("\n=== PostgreSQL backups (.sql.sql - old format) ===")
        rotate_s3_backups(bucket, "backup_%s/backup_postgresql" % hostname, ".sql.sql", dry_run=dry)

        print("\n=== Redis backups ===")
        rotate_s3_backups(bucket, "backup_%s/backup_%s" % (hostname, hostname), ".rdb.gz", dry_run=dry)

        print("\nDone. %s" % ("[DRY RUN - no files deleted]" if dry else "Files deleted."))

    elif command == "cleanup-secondary":
        print("\n=== Cleaning up backup_hdb_redis_secondary/ (dead server) ===")
        cleanup_s3_prefix(bucket, "backup_hdb_redis_secondary/", keep=1, dry_run=True)
        print("\nThis was a dry run. To actually delete, edit this script or call cleanup_s3_prefix() directly.")
