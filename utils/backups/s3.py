from boto.s3.connection import S3Connection
from boto.s3.connection import OrdinaryCallingFormat
from boto.s3.key import Key
import os
import sys

if '/srv/newsblur' not in ' '.join(sys.path):
    sys.path.append("/srv/newsblur")

os.environ['DJANGO_SETTINGS_MODULE'] = 'settings'
from django.conf import settings

ACCESS_KEY  = settings.S3_ACCESS_KEY
SECRET      = settings.S3_SECRET
BUCKET_NAME = settings.S3_BACKUP_BUCKET  # Note that you need to create this bucket first

def save_file_in_s3(filename, name=None):
    conn   = S3Connection(ACCESS_KEY, SECRET, calling_format=OrdinaryCallingFormat())
    bucket = conn.get_bucket(BUCKET_NAME)
    k      = Key(bucket)
    k.key  = name or filename

    k.set_contents_from_filename(filename)

def get_file_from_s3(filename):
    conn   = S3Connection(ACCESS_KEY, SECRET, calling_format=OrdinaryCallingFormat())
    bucket = conn.get_bucket(BUCKET_NAME)
    k      = Key(bucket)
    k.key  = filename

    k.get_contents_to_filename(filename)

def list_backup_in_s3():
    conn   = S3Connection(ACCESS_KEY, SECRET, calling_format=OrdinaryCallingFormat())
    bucket = conn.get_bucket(BUCKET_NAME)

    for i, key in enumerate(bucket.get_all_keys()):
        print("[%s] %s" % (i, key.name))

def delete_all_backups():
    #FIXME: validate filename exists
    conn   = S3Connection(ACCESS_KEY, SECRET, calling_format=OrdinaryCallingFormat())
    bucket = conn.get_bucket(BUCKET_NAME)

    for i, key in enumerate(bucket.get_all_keys()):
        print("deleting %s" % (key.name))
        key.delete()

if __name__ == '__main__':
    import sys
    if len(sys.argv) < 3:
        print('Usage: %s <get/set/list/delete> <backup_filename>' % (sys.argv[0]))
    else:
        if sys.argv[1] == 'set':
            save_file_in_s3(sys.argv[2])
        elif sys.argv[1] == 'get':
            get_file_from_s3(sys.argv[2])
        elif sys.argv[1] == 'list':
            list_backup_in_s3()
        elif sys.argv[1] == 'delete':
            delete_all_backups()
        else:
            print('Usage: %s <get/set/list/delete> <backup_filename>' % (sys.argv[0]))
