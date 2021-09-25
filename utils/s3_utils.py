import os
import sys
import time
import mimetypes
from utils.image_functions import ImageOps

if '/srv/newsblur' not in ' '.join(sys.path):
    sys.path.append("/srv/newsblur")

os.environ['DJANGO_SETTINGS_MODULE'] = 'newsblur_web.settings'
from django.conf import settings

ACCESS_KEY  = settings.S3_ACCESS_KEY
SECRET      = settings.S3_SECRET
BUCKET_NAME = settings.S3_BACKUP_BUCKET  # Note that you need to create this bucket first


class S3Store:
    
    def __init__(self, bucket_name=settings.S3_AVATARS_BUCKET_NAME):
        # if settings.DEBUG:
        #     import ssl

        #     try:
        #         _create_unverified_https_context = ssl._create_unverified_context
        #     except AttributeError:
        #         # Legacy Python that doesn't verify HTTPS certificates by default
        #         pass
        #     else:
        #         # Handle target environment that doesn't support HTTPS verification
        #         ssl._create_default_https_context = _create_unverified_https_context
        self.bucket_name = bucket_name
        self.s3 = settings.S3_CONN
        
    def create_bucket(self, bucket_name):
        return self.s3.create_bucket(Bucket=bucket_name)
        
    def save_profile_picture(self, user_id, filename, image_body):
        content_type, extension = self._extract_content_type(filename)
        if not content_type or not extension:
            return
            
        image_name = 'profile_%s.%s' % (int(time.time()), extension)
        
        image = ImageOps.resize_image(image_body, 'fullsize', fit_to_size=False)
        if image:
            key = 'avatars/%s/large_%s' % (user_id, image_name)
            self._save_object(key, image, content_type=content_type)

        image = ImageOps.resize_image(image_body, 'thumbnail', fit_to_size=True)
        if image:
            key = 'avatars/%s/thumbnail_%s' % (user_id, image_name)
            self._save_object(key, image, content_type=content_type)
        
        return image and image_name

    def _extract_content_type(self, filename):
        content_type = mimetypes.guess_type(filename)[0]
        extension = None
        
        if content_type == 'image/jpeg':
            extension = 'jpg'
        elif content_type == 'image/png':
            extension = 'png'
        elif content_type == 'image/gif':
            extension = 'gif'
            
        return content_type, extension
        
    def _save_object(self, key, file_object, content_type=None):
        file_object.seek(0)
        s3_object = self.s3.Object(bucket_name=self.bucket_name, key=key)

        if content_type:
            s3_object.put(Body=file_object, 
                ContentType=content_type,
                ACL='public-read'
            )
        else:
            s3_object.put(Body=file_object)
        
