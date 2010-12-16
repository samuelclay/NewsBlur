from fabric.api import env, run, require, sudo, settings
from boto.s3.connection import S3Connection
from boto.s3.key import Key
from django.conf import settings as django_settings

# =========
# = Roles =
# =========

env.user = 'conesus'
env.hosts = ['www.newsblur.com', 'db01.newsblur.com', 'db02.newsblur.com', 'db03.newsblur.com']
env.roledefs ={
    'web': ['www.newsblur.com'],
    'db': ['db01.newsblur.com'],
    'task': ['db02.newsblur.com', 'db03.newsblur.com'],
}

"""
Base configuration
"""
env.project_name = '$(project)'
env.database_password = '$(db_password)'
env.site_media_prefix = "site_media"
env.admin_media_prefix = "admin_media"
env.newsapps_media_prefix = "na_media"
env.path = '/home/conesus/%(project_name)s' % env
env.python = 'python2.6'

"""
Environments
"""
def production():
    """
    Work on production environment
    """
    env.settings = 'production'
    env.hosts = ['$(production_domain)']
    env.user = '$(production_user)'
    env.s3_bucket = '$(production_s3)'

def staging():
    """
    Work on staging environment
    """
    env.settings = 'staging'
    env.hosts = ['$(staging_domain)'] 
    env.user = '$(staging_user)'
    env.s3_bucket = '$(staging_s3)'
    
"""
Branches
"""
def stable():
    """
    Work on stable branch.
    """
    env.branch = 'stable'

def master():
    """
    Work on development branch.
    """
    env.branch = 'master'

def branch(branch_name):
    """
    Work on any specified branch.
    """
    env.branch = branch_name
    
    
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