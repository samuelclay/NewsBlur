#!/usr/bin/python3
import os
import socket
import sys

CURRENT_DIR  = os.path.dirname(__file__)
NEWSBLUR_DIR = ''.join([CURRENT_DIR, '/../../'])
sys.path.insert(0, NEWSBLUR_DIR)
os.environ['DJANGO_SETTINGS_MODULE'] = 'newsblur_web.settings'

import threading


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
                "\r%s  %s / %s  (%.2f%%)" % (
                    self._filename, self._seen_so_far, self._size,
                    percentage))
            sys.stdout.flush()

import time

import boto3
from django.conf import settings

BACKUP_DIR = '/srv/newsblur/backup/'

s3 = boto3.client('s3', aws_access_key_id=settings.S3_ACCESS_KEY, aws_secret_access_key=settings.S3_SECRET) 

hostname = socket.gethostname().replace('-','_')
full_path = sys.argv[1]
backup_filename = os.path.basename(full_path)
s3_object_name = f'backup_{hostname}/{backup_filename}.sql'
print('Uploading %s to %s on S3 bucket %s' % (full_path, s3_object_name, settings.S3_BACKUP_BUCKET))
s3.upload_file(full_path, settings.S3_BACKUP_BUCKET, s3_object_name, Callback=ProgressPercentage(full_path))
os.remove(full_path)
