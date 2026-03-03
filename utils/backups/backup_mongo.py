#!/usr/bin/python3
import os
import sys

from newsblur_web import settings
from utils.backups.backup_rotation import rotate_s3_backups, upload_to_s3


def main():
    dry_run = "--dry-run" in sys.argv

    if not dry_run:
        BACKUP_DIR = "/srv/newsblur/backup/"
        filenames = [f for f in os.listdir(BACKUP_DIR) if ".tgz" in f]
        for filename in filenames:
            file_path = os.path.join(BACKUP_DIR, filename)
            key = "backup_db_mongo/%s" % os.path.basename(file_path)
            print("Uploading %s to %s on %s" % (file_path, key, settings.S3_BACKUP_BUCKET))
            sys.stdout.flush()
            upload_to_s3(file_path, settings.S3_BACKUP_BUCKET, key)
            os.remove(file_path)

    print("Rotating MongoDB backups on S3...")
    rotate_s3_backups(settings.S3_BACKUP_BUCKET, "backup_db_mongo/backup_mongo", ".tgz", dry_run=dry_run)


if __name__ == "__main__":
    main()
