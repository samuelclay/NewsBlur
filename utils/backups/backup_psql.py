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

# Allow hostname override via --hostname=NAME (e.g., when host's hostname
# doesn't match the ansible inventory name, like hdb-redis-secondary
# running postgres backups as hdb-postgres-secondary)
hostname = None
for arg in sys.argv:
    if arg.startswith("--hostname="):
        hostname = arg.split("=", 1)[1]
if not hostname:
    hostname = socket.gethostname()
hostname = hostname.replace("-", "_")

if not dry_run:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    full_path = args[0]
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
