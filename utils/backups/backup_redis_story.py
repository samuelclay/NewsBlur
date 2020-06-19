import os
import sys

CURRENT_DIR  = os.path.dirname(__file__)
NEWSBLUR_DIR = ''.join([CURRENT_DIR, '/../../'])
sys.path.insert(0, NEWSBLUR_DIR)
os.environ['DJANGO_SETTINGS_MODULE'] = 'settings'

import time
import s3
from django.conf import settings

filename = 'redis_story/backup_redis_story_%s.rdb.gz' % time.strftime('%Y-%m-%d-%H-%M')
path = '/var/lib/redis/dump.rdb'
print('Uploading %s (from %s) to S3...' % (filename, path))
s3.save_file_in_s3(path, name=filename)
