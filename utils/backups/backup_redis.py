#!/usr/bin/python3
import os
import sys
import socket
CURRENT_DIR  = os.path.dirname(__file__)
NEWSBLUR_DIR = ''.join([CURRENT_DIR, '/../../'])
sys.path.insert(0, NEWSBLUR_DIR)
os.environ['DJANGO_SETTINGS_MODULE'] = 'newsblur_web.settings'

import time
import boto3
from django.conf import settings

s3 = boto3.resource('s3') 
bucket = s3.Bucket(settings.get('S3_BACKUP_BUCKET'))

hostname = socket.gethostname().replace('-','_')
filename = f'backup_{hostname}/backup_{hostname}_{time.strftime("%Y-%m-%d-%H-%M")}.rdb.gz'
path = '/var/lib/redis/dump.rdb'
print('Uploading %s (from %s) to S3...' % (filename, path))
bucket.upload_file(path, name=filename)
