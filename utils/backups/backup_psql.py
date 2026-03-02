#!/usr/bin/python3
import os
import socket
import sys

CURRENT_DIR = os.path.dirname(__file__)
NEWSBLUR_DIR = "".join([CURRENT_DIR, "/../../"])
sys.path.insert(0, NEWSBLUR_DIR)
os.environ["DJANGO_SETTINGS_MODULE"] = "newsblur_web.settings"

from django.conf import settings

from utils.backups.backup_rotation import rotate_s3_backups, upload_to_s3

dry_run = "--dry-run" in sys.argv
hostname = socket.gethostname().replace("-", "_")

if not dry_run:
    full_path = sys.argv[1]
    backup_filename = os.path.basename(full_path)
    s3_object_name = "backup_%s/%s" % (hostname, backup_filename)

    print("Uploading %s to %s on S3 bucket %s" % (full_path, s3_object_name, settings.S3_BACKUP_BUCKET))
    upload_to_s3(full_path, settings.S3_BACKUP_BUCKET, s3_object_name)

    # Don't delete local file — the existing ansible cron (postgres_backup_cleaner) handles cleanup
    # of files older than 12.5 days, and offsite backup pulls from local files too.

print("Rotating PostgreSQL backups on S3...")
# Rotate both .sql (new format) and .sql.sql (old double-extension bug) backups
rotate_s3_backups(
    settings.S3_BACKUP_BUCKET, "backup_%s/backup_postgresql" % hostname, ".sql", dry_run=dry_run
)
rotate_s3_backups(
    settings.S3_BACKUP_BUCKET, "backup_%s/backup_postgresql" % hostname, ".sql.sql", dry_run=dry_run
)
