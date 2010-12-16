from fabric.api import abort, cd, env, get, hide, hosts, local, prompt
from fabric.api import put, require, roles, run, runs_once, settings, show, sudo, warn
from fabric.colors import red, green, blue, cyan, magenta, white, yellow
from boto.s3.connection import S3Connection
from boto.s3.key import Key
from fabric.contrib import django
import os, sys

django.settings_module('settings')
from django.conf import settings as django_settings

# =========
# = Roles =
# =========

env.user = 'conesus'
# env.hosts = ['www.newsblur.com', 'db01.newsblur.com', 'db02.newsblur.com', 'db03.newsblur.com']
env.roledefs ={
    'app': ['www.newsblur.com'],
    'db': ['db01.newsblur.com'],
    'task': ['db02.newsblur.com', 'db03.newsblur.com'],
}

"""
Base configuration
"""

"""
Environments
"""
def app():
    env.roles = ['app']
def db():
    env.roles = ['db']
def task():
    env.roles = ['task']

# ==========
# = Deploy =
# ==========

@roles('app')
def deploy():
    run('cd ~/newsblur && git pull && kill -HUP `cat /var/run/gunicorn/gunicorn.pid`')

@roles('task')
def celery():
    run('cd ~/newsblur && git pull && sudo supervisorctl restart celery && tail logs/newsblur.log')

@roles('task')
def force_celery():
    run('cd ~/newsblur && git pull')
    run('ps aux | grep celeryd | egrep -v grep | awk \'{print $2}\' | sudo xargs kill -9')
    # run('sudo supervisorctl start celery && tail logs/newsblur.log')

# ===========
# = Backups =
# ===========

@roles('app')
def backup_mongo():
    run('cd ~/newsblur/utils/backups')
    run('./mongo_backup.sh')

@roles('db')
def backup_postgresql():
    run('cd ~/newsblur/utils/backups')
    run('./postgresql_backup.sh')

# ======
# = S3 =
# ======

ACCESS_KEY  = django_settings.S3_ACCESS_KEY
SECRET      = django_settings.S3_SECRET
BUCKET_NAME = django_settings.S3_BACKUP_BUCKET  # Note that you need to create this bucket first

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