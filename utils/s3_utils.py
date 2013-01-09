import os
import sys
import time
import mimetypes
from boto.s3.connection import S3Connection
from boto.s3.key import Key
from utils.image_functions import ImageOps

if '/home/sclay/newsblur' not in ' '.join(sys.path):
    sys.path.append("/home/sclay/newsblur")

os.environ['DJANGO_SETTINGS_MODULE'] = 'settings'
from django.conf import settings

ACCESS_KEY  = settings.S3_ACCESS_KEY
SECRET      = settings.S3_SECRET
BUCKET_NAME = settings.S3_BACKUP_BUCKET  # Note that you need to create this bucket first

def save_file_in_s3(filename):
    conn   = S3Connection(ACCESS_KEY, SECRET)
    bucket = conn.get_bucket(BUCKET_NAME)
    k      = Key(bucket)
    k.key  = filename

    k.set_contents_from_filename(filename)

def get_file_from_s3(filename):
    conn   = S3Connection(ACCESS_KEY, SECRET)
    bucket = conn.get_bucket(BUCKET_NAME)
    k      = Key(bucket)
    k.key  = filename

    k.get_contents_to_filename(filename)

def list_backup_in_s3():
    conn   = S3Connection(ACCESS_KEY, SECRET)
    bucket = conn.get_bucket(BUCKET_NAME)

    for i, key in enumerate(bucket.get_all_keys()):
        print "[%s] %s" % (i, key.name)

def delete_all_backups():
    #FIXME: validate filename exists
    conn   = S3Connection(ACCESS_KEY, SECRET)
    bucket = conn.get_bucket(BUCKET_NAME)

    for i, key in enumerate(bucket.get_all_keys()):
        print "deleting %s" % (key.name)
        key.delete()

if __name__ == '__main__':
    import sys
    if len(sys.argv) < 3:
        print 'Usage: %s <get/set/list/delete> <backup_filename>' % (sys.argv[0])
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
            print 'Usage: %s <get/set/list/delete> <backup_filename>' % (sys.argv[0])


class S3Store:
    
    def __init__(self, bucket_name=settings.S3_AVATARS_BUCKET_NAME):
        self.s3 = S3Connection(ACCESS_KEY, SECRET)
        self.bucket = self.create_bucket(bucket_name)
    
    def create_bucket(self, bucket_name):
        return self.s3.create_bucket(bucket_name)
        
    def save_profile_picture(self, user_id, filename, image_body):
        mimetype, extension = self._extract_mimetype(filename)
        if not mimetype or not extension:
            return
            
        image_name = 'profile_%s.%s' % (int(time.time()), extension)
        
        image = ImageOps.resize_image(image_body, 'fullsize', fit_to_size=False)
        if image:
            key = 'avatars/%s/large_%s' % (user_id, image_name)
            self._save_object(key, image, mimetype=mimetype)

        image = ImageOps.resize_image(image_body, 'thumbnail', fit_to_size=True)
        if image:
            key = 'avatars/%s/thumbnail_%s' % (user_id, image_name)
            self._save_object(key, image, mimetype=mimetype)
        
        return image and image_name

    def _extract_mimetype(self, filename):
        mimetype = mimetypes.guess_type(filename)[0]
        extension = None
        
        if mimetype == 'image/jpeg':
            extension = 'jpg'
        elif mimetype == 'image/png':
            extension = 'png'
        elif mimetype == 'image/gif':
            extension = 'gif'
            
        return mimetype, extension
        
    def _make_key(self):
        return Key(bucket=self.bucket)
    
    def _save_object(self, key, file_object, mimetype=None):
        k = self._make_key()
        k.key = key
        file_object.seek(0)
        
        if mimetype:
            k.set_contents_from_file(file_object, headers={
                'Content-Type': mimetype,
            })
        else:
            k.set_contents_from_file(file_object)
        k.set_acl('public-read')
        
