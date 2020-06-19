import os
import sys

NEWSBLUR_DIR = '/srv/newsblur'
sys.path.insert(0, NEWSBLUR_DIR)
VENDOR_DIR = '/srv/newsblur/vendor'
sys.path.insert(0, VENDOR_DIR)
os.environ['DJANGO_SETTINGS_MODULE'] = 'settings'

import time
import s3
from django.conf import settings

db_name = 'newsblur'
db_pass = settings.DATABASES['default']['PASSWORD']
os.environ['PGPASSWORD'] = db_pass
filename = 'backup_postgresql_%s.sql.gz' % time.strftime('%Y-%m-%d-%H-%M')
cmd      = '/usr/lib/postgresql/9.4/bin/pg_dump -U newsblur -h 127.0.0.1 -Fc %s > %s' % (db_name, filename)
print('Backing up PostgreSQL: %s' % cmd)
os.system(cmd)

print('Uploading %s to S3...' % filename)
s3.save_file_in_s3(filename, name="postgres/%s" % filename)
os.remove(filename)