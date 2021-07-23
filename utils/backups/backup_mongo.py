#!/usr/bin/python3
import os
import shutil

from newsblur_web import settings
import boto3

filenames = [f for f in os.listdir('/opt/mongo/newsblur/backup/') if '.tgz' in f]

for filename in filenames:
    print('Uploading %s to S3...' % filename)
    try:
        s3 = boto3.resource('s3') 
        bucket = s3.Bucket(settings.S3_BACKUP_BUCKET)
        bucket.upload_file(filename, name="mongo/%s" % (filename))
    except Exception as e:
        print(" ****> Exceptions: %s" % e)
    shutil.rmtree(filename[:-4])
    os.remove(filename)
