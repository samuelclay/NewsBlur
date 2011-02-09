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
    with cd('~/newsblur'):
        run('git pull')
        run('kill -HUP `cat logs/gunicorn.pid`')

@roles('app')
def deploy_full():
    with cd('~/newsblur'):
        run('git pull')
        run('./manage.py migrate')
        run('sudo supervisorctl restart gunicorn')

@roles('app')
def staging():
    with cd('~/staging'):
        run('git pull')
        run('kill -HUP `cat /var/run/gunicorn/gunicorn_staging.pid`')

@roles('app')
def staging_full():
    with cd('~/staging'):
        run('git pull')
        run('./manage.py migrate')
        run('kill -HUP `cat /var/run/gunicorn/gunicorn_staging.pid`')

@roles('task')
def celery():
    with cd('~/newsblur'):
        run('git pull')
        run('sudo supervisorctl restart celery')
        run('tail logs/newsblur.log')

@roles('task')
def force_celery():
    with cd('~/newsblur'):
        run('git pull')
        run('ps aux | grep celeryd | egrep -v grep | awk \'{print $2}\' | sudo xargs kill -9')
        # run('sudo supervisorctl start celery && tail logs/newsblur.log')

# ===========
# = Backups =
# ===========

@roles('app')
def backup_mongo():
    with cd('~/newsblur/utils/backups'):
        run('./mongo_backup.sh')

@roles('db')
def backup_postgresql():
    with cd('~/newsblur/utils/backups'):
        run('./postgresql_backup.sh')

# =============
# = Bootstrap =
# =============

def setup_app():
    setup_common()
    setup_gunicorn()
    update_gunicorn()
    setup_nginx()

def setup_db():
    setup_postgres()
    
def setup_task():
    setup_celery()

def setup_common():
    setup_installs()
    # setup_user()
    setup_server()
    setup_repo()
    setup_python()
    setup_libxml()
    setup_mongoengine()
    setup_supervisor()

def setup_user():
    run('useradd -c "NewsBlur" -m conesus -s /bin/zsh')
    run('openssl rand -base64 8 | tee -a ~conesus/.password | passwd -stdin conesus')
    run('mkdir ~conesus/.ssh && chmod 700 ~conesus/.ssh')
    
def setup_server():
    sudo('hostname app02')
    
def setup_installs():
    sudo('apt-get -y update')
    sudo('apt-get -y upgrade')
    sudo('apt-get -y install gcc sysstat git zsh python-dev locate python-software-properties libpcre3-dev libssl-dev make pgbouncer python-psycopg2 libmemcache0 memcached python-memcache libyaml-0-2 python-yaml python-numpy python-scipy python-imaging')
    sudo('add-apt-repository ppa:pitti/postgresql')
    sudo('apt-get -y update')
    sudo('apt-get -y install postgresql-client-9.0')
    run('git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh')
    run('curl -O http://peak.telecommunity.com/dist/ez_setup.py')
    sudo('python ez_setup.py -U setuptools && rm ez_setup.py')

def setup_repo():
    run('mkdir -p ~/code')
    run('git clone https://github.com/samuelclay/NewsBlur.git newsblur')
    with cd('~/newsblur'):
        run('cp local_settings.py.template local_settings.py')
        run('mkdir -p logs')

def setup_python():
    sudo('easy_install pip')
    sudo('easy_install django django-celery django-compress South django-devserver django-extensions guppy psycopg2 BeautifulSoup pyyaml nltk lxml oauth2 pytz boto')
    sudo('su -c \'echo "import sys; sys.setdefaultencoding(\"utf-8\")" > /usr/lib/python2.6/sitecustomize.py\'')
    
def setup_libxml():
    sudo('apt-get -y install libxml2-dev libxslt1-dev python-lxml')
    # with cd('~/code'):
    #     run('git clone git://git.gnome.org/libxml2')
    #     run('git clone git://git.gnome.org/libxslt')
    # 
    # with cd('~/code/libxml2'):
    #     run('./configure && make && sudo make install')
    #     
    # with cd('~/code/libxslt'):
    #     run('./configure && make && sudo make install')
        
def setup_gunicorn():
    with cd('~/code'):
        run('git clone git://github.com/benoitc/gunicorn.git')
        sudo('ln -s ~/code/gunicorn/gunicorn /usr/local/lib/python2.6/dist-packages/gunicorn')

def update_gunicorn():
    with cd('~/code/gunicorn'):
        run('git pull')
        sudo('python setup.py install')

def setup_nginx():
    with cd('~/code'):
        run('wget http://sysoev.ru/nginx/nginx-0.9.4.tar.gz')
        run('tar -xzf nginx-0.9.4.tar.gz')
        run('rm nginx-0.9.4.tar.gz')
        with cd('~/code/nginx-0.9.4'):
            run('./configure --with-http_ssl_module --with-http_stub_status_module --with-http_gzip_static_module')
            run('make')
            run('sudo make isntall')
            
def setup_mongoengine():
    with cd('~/code'):
        run('https://github.com/hmarr/mongoengine.git')
        sudo('ln -s ~/code/mongoengine/mongoengine /usr/local/lib/python2.6/dist-packages/mongoengine')
        
def setup_supervisor():
    sudo('apt-get -y install supervisor')
    
    
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