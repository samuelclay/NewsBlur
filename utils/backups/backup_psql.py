import os
import sys

CURRENT_DIR  = os.path.dirname(__file__)
NEWSBLUR_DIR = ''.join([CURRENT_DIR, '/../../'])
sys.path.insert(0, NEWSBLUR_DIR)
os.environ['DJANGO_SETTINGS_MODULE'] = 'settings'

import time
import s3
from django.conf import settings

db_name = 'newsblur'
db_pass = settings.DATABASES['default']['PASSWORD']
os.environ['PGPASSWORD'] = db_pass
filename = 'backup_postgresql_%s.sql.gz' % time.strftime('%Y-%m-%d-%H-%M')
cmd      = '/usr/lib/postgresql/9.2/bin -U newsblur -h 127.0.0.1 -Fc %s > %s' % (db_name, filename)
print 'Backing up PostgreSQL: %s' % cmd
os.system(cmd)

print 'Uploading %s to S3...' % filename
s3.save_file_in_s3(filename)
os.remove(filename)