#!/usr/bin/python3
import os
import sys

NEWSBLUR_DIR = '/srv/newsblur'
sys.path.insert(0, NEWSBLUR_DIR)


import boto3

filename = sys.argv[1]

print('Uploading %s to S3...' % filename)

s3 = boto3.resource('s3') 
bucket = sys.argv[2]
bucket.upload_file(filename, name="postgres/%s" % filename.split("/")[1])
os.remove(filename)
