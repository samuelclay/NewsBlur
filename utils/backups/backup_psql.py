import os
import sys
import time
import s3
from django.conf import settings

db_name      = 'newsblur'
db_pass      = settings.DATABASES['default']['PASSWORD']
CURRENT_DIR  = os.path.dirname(__file__)
NEWSBLUR_DIR = ''.join([CURRENT_DIR, '../../'])

os.environ['DJANGO_SETTINGS_MODULE'] = 'settings'
os.environ['PGPASSWORD'] = db_pass
sys.path.insert(0, NEWSBLUR_DIR)

filename = 'backup_postgresql_%s.sql.gz' % time.strftime('%Y-%m-%d-%H-%M')
cmd      = 'pg_dump -U newsblur -Fc %s > %s' % (db_name, filename)
os.system(cmd)

s3.save_file_in_s3(filename)
os.remove(filename)