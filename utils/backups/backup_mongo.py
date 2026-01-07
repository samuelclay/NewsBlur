#!/usr/bin/python3
import logging
import mimetypes
import os
import re
import shutil
import sys
import threading
from datetime import datetime, timedelta

import boto3
from boto3.s3.transfer import S3Transfer

from newsblur_web import settings

logger = logging.getLogger(__name__)


def main():
    BACKUP_DIR = "/srv/newsblur/backup/"
    filenames = [f for f in os.listdir(BACKUP_DIR) if ".tgz" in f]
    for filename in filenames:
        file_path = os.path.join(BACKUP_DIR, filename)
        basename = os.path.basename(file_path)
        key_prefix = "backup_db_mongo/"
        print("Uploading {0} to {1} on {2}".format(file_path, key_prefix, settings.S3_BACKUP_BUCKET))
        sys.stdout.flush()
        upload_rotate(file_path, settings.S3_BACKUP_BUCKET, key_prefix)

        # shutil.rmtree(filename[:-4])
        os.remove(file_path)


def upload_rotate(file_path, s3_bucket, s3_key_prefix):
    """
    Upload file_path to s3 bucket with prefix
    Ex. upload_rotate('/tmp/file-2015-01-01.tar.bz2', 'backups', 'foo.net/')
    would upload file to bucket backups with key=foo.net/file-2015-01-01.tar.bz2
    and then rotate all files starting with foo.net/file and with extension .tar.bz2
    Timestamps need to be present between the file root and the extension and in the same format as strftime("%Y-%m-%d").
    Ex file-2015-12-28.tar.bz2
    """
    key = "".join([s3_key_prefix, os.path.basename(file_path)])
    print("Uploading {0} to {1}".format(file_path, key))
    upload(file_path, s3_bucket, key)

    file_root, file_ext = splitext(os.path.basename(file_path))
    # strip timestamp from file_base
    regex = "(?P<filename>.*)_(?P<year>[\d]+?)-(?P<month>[\d]+?)-(?P<day>[\d]+?)-(?P<hour>[\d]+?)-(?P<minute>[\d]+?)"
    match = re.match(regex, file_root)
    if not match:
        raise Exception("File does not contain a timestamp")
    key_prefix = "".join([s3_key_prefix, match.group("filename")])
    print("Rotating files on S3 with key prefix {0} and extension {1}".format(key_prefix, file_ext))
    rotate(key_prefix, file_ext, s3_bucket)


def rotate(key_prefix, key_ext, bucket_name, daily_backups=7, weekly_backups=4):
    """Delete old files we've uploaded to S3 according to grandfather, father, sun strategy"""

    session = boto3.Session(
        aws_access_key_id=settings.S3_ACCESS_KEY, aws_secret_access_key=settings.S3_SECRET
    )
    s3 = session.resource("s3")
    bucket = s3.Bucket(bucket_name)
    keys = bucket.objects.filter(Prefix=key_prefix)

    regex = "{0}_(?P<year>[\d]+?)-(?P<month>[\d]+?)-(?P<day>[\d]+?)-(?P<hour>[\d]+?)-(?P<minute>[\d]+?){1}".format(
        key_prefix, key_ext
    )
    backups = []

    for key in keys:
        match = re.match(regex, str(key.key))
        if not match:
            continue
        year = int(match.group("year"))
        month = int(match.group("month"))
        day = int(match.group("day"))
        hour = int(match.group("hour"))
        minute = int(match.group("minute"))
        key_date = datetime(year, month, day, hour, minute)
        backups[:0] = [key_date]
    backups = sorted(backups, reverse=True)

    if len(backups) > daily_backups + 1 and backups[daily_backups] - backups[daily_backups + 1] < timedelta(
        days=7
    ):
        key = bucket.Object(
            "{0}{1}{2}".format(key_prefix, backups[daily_backups].strftime("_%Y-%m-%d-%H-%M"), key_ext)
        )
        logger.debug("[not] deleting daily {0}".format(key))
        # key.delete()
        del backups[daily_backups]

    month_offset = daily_backups + weekly_backups
    if len(backups) > month_offset + 1 and backups[month_offset] - backups[month_offset + 1] < timedelta(
        days=30
    ):
        key = bucket.Object(
            "{0}{1}{2}".format(key_prefix, backups[month_offset].strftime("_%Y-%m-%d-%H-%M"), key_ext)
        )
        logger.debug("[not] deleting weekly {0}".format(key))
        # key.delete()
        del backups[month_offset]


def splitext(filename):
    """Return the filename and extension according to the first dot in the filename.
    This helps date stamping .tar.bz2 or .ext.gz files properly.
    """
    index = filename.find(".")
    if index == 0:
        index = 1 + filename[1:].find(".")
    if index == -1:
        return filename, ""
    return filename[:index], filename[index:]
    return os.path.splitext(filename)


def upload(source_path, bucketname, keyname, acl="private", guess_mimetype=True):
    client = boto3.client(
        "s3", aws_access_key_id=settings.S3_ACCESS_KEY, aws_secret_access_key=settings.S3_SECRET
    )
    client.upload_file(source_path, bucketname, keyname, Callback=ProgressPercentage(source_path))


class ProgressPercentage(object):
    def __init__(self, filename):
        self._filename = filename
        self._size = float(os.path.getsize(filename))
        self._seen_so_far = 0
        self._lock = threading.Lock()

    def __call__(self, bytes_amount):
        # To simplify, assume this is hooked up to a single filename
        with self._lock:
            self._seen_so_far += bytes_amount
            percentage = (self._seen_so_far / self._size) * 100
            sys.stdout.write(
                "\r%s  %s / %s  (%.2f%%)" % (self._filename, self._seen_so_far, self._size, percentage)
            )
            sys.stdout.flush()


if __name__ == "__main__":
    main()
