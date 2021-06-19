#!/usr/bin/python3
import os
import sys

NEWSBLUR_DIR = '/srv/newsblur'
sys.path.insert(0, NEWSBLUR_DIR)
VENDOR_DIR = '/srv/newsblur/vendor'
sys.path.insert(0, VENDOR_DIR)
os.environ['DJANGO_SETTINGS_MODULE'] = 'newsblur_web.settings'

import time
import boto3
from django.conf import settings

db_name = 'newsblur'
db_pass = settings.DATABASES['default']['PASSWORD']
filename = '/backup/backup_postgresql_%s.sql.gz' % time.strftime('%Y-%m-%d-%H-%M')
cmd      = f'docker exec -it postgres export PGPASSWORD="{db_pass}"; /usr/lib/postgresql/13/bin/pg_dump -U newsblur -h 127.0.0.1 -Fc {db_name} > {filename}'
print('Backing up PostgreSQL: %s' % cmd)
os.system(cmd)

print('Uploading %s to S3...' % filename)

s3 = boto3.resource('s3') 
bucket = s3.Bucket(settings.get('S3_BACKUP_BUCKET'))
bucket.upload_file(filename, name="postgres/%s" % filename)
os.remove(filename)
