import os
import sys

CURRENT_DIR  = os.path.dirname(__file__)
NEWSBLUR_DIR = ''.join([CURRENT_DIR, '/../../'])
sys.path.insert(0, NEWSBLUR_DIR)
os.environ['DJANGO_SETTINGS_MODULE'] = 'settings'

import time
import s3
from django.conf import settings

COLLECTIONS = "classifier_tag classifier_author classifier_feed classifier_title userstories starred_stories"

date = time.strftime('%Y-%m-%d-%H-%M')
collections = ' '.split(COLLECTIONS)
db_name = settings.MONGO_DB.get('NAME')
db_pass = settings.MONGO_DB.get('PASSWORD')
dir_name = 'backup_mongo_%s' % date
filename = '%s.tgz' % dir_name

for collection in collections:
    print "Dumping %s" % collection
    filename = 'backup_mongo_%s.sql.gz' % date
    cmd = 'mongodump  --db %s --collection %s -o %s' % (db_name, collection, dir_name)
    os.system(cmd)
    
cmd = 'tar -jcf %s %s' % (filename, dir_name)
os.system(cmd)

print 'Uploading %s to S3...' % filename
s3.save_file_in_s3(filename)
os.removedirs(dir_name)