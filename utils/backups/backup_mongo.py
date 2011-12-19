import os
import sys
import shutil

CURRENT_DIR  = os.path.dirname(os.getcwd())
NEWSBLUR_DIR = ''.join([CURRENT_DIR, '/../../'])
sys.path.insert(0, NEWSBLUR_DIR)
os.environ['DJANGO_SETTINGS_MODULE'] = 'settings'

import time
import s3
from django.conf import settings

COLLECTIONS = "classifier_tag classifier_author classifier_feed classifier_title userstories starred_stories"

date = time.strftime('%Y-%m-%d-%H-%M')
collections = COLLECTIONS.split(' ')
db_name = 'newsblur'
dir_name = 'backup_mongo_%s' % date
filename = '%s.tgz' % dir_name

os.mkdir(dir_name)

for collection in collections:
    cmd = 'mongodump  --db %s --collection %s -o %s' % (db_name, collection, dir_name)
    print "Dumping %s: %s" % (collection, cmd)
    os.system(cmd)

cmd = 'tar -jcf %s %s' % (filename, dir_name)
os.system(cmd)

print 'Uploading %s to S3...' % filename
s3.save_file_in_s3(filename)
shutil.rmtree(dir_name)
os.remove(filename)