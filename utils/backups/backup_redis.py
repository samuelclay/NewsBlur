#!/usr/bin/python3
import os
import socket
import sys
import time

CURRENT_DIR = os.path.dirname(__file__)
NEWSBLUR_DIR = "".join([CURRENT_DIR, "/../../"])
sys.path.insert(0, NEWSBLUR_DIR)
os.environ["DJANGO_SETTINGS_MODULE"] = "newsblur_web.settings"

from django.conf import settings

from utils.backups.backup_rotation import rotate_s3_backups, upload_to_s3

dry_run = "--dry-run" in sys.argv
hostname = socket.gethostname().replace("-", "_")

if not dry_run:
    timestamp = time.strftime("%Y-%m-%d-%H-%M")
    s3_object_name = "backup_%s/backup_%s_%s.rdb.gz" % (hostname, hostname, timestamp)
    path = "/data/dump.rdb"

    print("Uploading %s (from %s) to S3..." % (s3_object_name, path))
    upload_to_s3(path, settings.S3_BACKUP_BUCKET, s3_object_name)

print("Rotating Redis backups on S3...")
rotate_s3_backups(
    settings.S3_BACKUP_BUCKET, "backup_%s/backup_%s" % (hostname, hostname), ".rdb.gz", dry_run=dry_run
)
