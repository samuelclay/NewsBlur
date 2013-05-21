from fabric.api import cd, env, local, parallel, serial
from fabric.api import put, run, settings, sudo
from fabric.operations import prompt
# from fabric.colors import red, green, blue, cyan, magenta, white, yellow
from boto.s3.connection import S3Connection
from boto.s3.key import Key
from boto.ec2.connection import EC2Connection
from fabric.contrib import django
from vendor import yaml
from pprint import pprint
import os
import time
import sys
import re
try:
    import dop.client
except ImportError:
    print "Digital Ocean's API not loaded"


django.settings_module('settings')
try:
    from django.conf import settings as django_settings
except ImportError:
    print " ---> Django not installed yet."
    django_settings = None


# ============
# = DEFAULTS =
# ============

env.NEWSBLUR_PATH = "~/projects/newsblur"
env.SECRETS_PATH = "~/projects/secrets-newsblur"
env.VENDOR_PATH   = "~/projects/code"
env.user = 'sclay'

# =========
# = Roles =
# =========

try:
    hosts_path = os.path.expanduser(os.path.join(env.SECRETS_PATH, 'configs/hosts.yml'))
    roles = yaml.load(open(hosts_path))
    for role_name, hosts in roles.items():
        if isinstance(hosts, dict):
            roles[role_name] = [host for host in hosts.keys()]
    env.roledefs = roles
except:
    print " ***> No role definitions found in %s. Using default roles." % hosts_path
    env.roledefs = {
        'app'   : ['app01.newsblur.com'],
        'db'    : ['db01.newsblur.com'],
        'task'  : ['task01.newsblur.com'],
    }

def do_roledefs(split=False):
    doapi = dop.client.Client(django_settings.DO_CLIENT_KEY, django_settings.DO_API_KEY)
    droplets = doapi.show_active_droplets()
    for droplet in droplets:
        roledef = re.split(r"([0-9]+)", droplet.name)[0]
        if roledef not in env.roledefs:
            env.roledefs[roledef] = []
        if split:
            env.roledefs[roledef].append((droplet.name, droplet.ip_address))
        elif droplet.ip_address not in env.roledefs[roledef]:
            env.roledefs[roledef].append(droplet.ip_address)
    return droplets

def list_do():
    do(split=True)
    pprint(env.roledefs)

def host(name):
    droplets = do(split=True)
    for droplet in droplets:
        if name == droplet.name:
            env.hosts = [droplet.ip_address]
            break
    
# ================
# = Environments =
# ================

def do(split=False):
    env.NEWSBLUR_PATH = "/srv/newsblur"
    env.SECRETS_PATH  = "/srv/secrets-newsblur"
    env.VENDOR_PATH   = "/srv/code"
    droplets = do_roledefs(split=split)
    return droplets

def app():
    do()
    env.roles = ['app']

def work():
    do()
    env.roles = ['work']

def www():
    do()
    env.roles = ['www']

def dev():
    do()
    env.roles = ['dev']

def debug():
    do()
    env.roles = ['debug']

def node():
    do()
    env.roles = ['node']

def db():
    do()
    env.roles = ['db']

def task():
    do()
    env.roles = ['task']

def ec2task():
    ec2()
    env.roles = ['ec2task']

def ec2():
    env.user = 'ubuntu'
    env.key_filename = ['/Users/sclay/.ec2/sclay.pem']
    do()

def all():
    do()
    env.roles = ['app', 'dev', 'db', 'task', 'debug']

# ==========
# = Deploy =
# ==========

@parallel
def pull():
    with cd(env.NEWSBLUR_PATH):
        run('git pull')

def pre_deploy():
    compress_assets(bundle=True)

@serial
def post_deploy():
    cleanup_assets()

@parallel
def deploy(fast=False):
    deploy_code(copy_assets=False, fast=fast)

@parallel
def deploy_web(fast=False):
    deploy_code(copy_assets=True, fast=fast, full=False)

@parallel
def deploy_full(fast=False):
    deploy_code(copy_assets=True, fast=fast, full=True)

@parallel
def deploy_code(copy_assets=False, full=False, fast=False):
    with cd(env.NEWSBLUR_PATH):
        run('git pull')
        run('mkdir -p static')
        if full:
            run('rm -fr static/*')
        if copy_assets:
            transfer_assets()
        sudo('supervisorctl reload')
        if fast:
            with settings(warn_only=True):
                if env.user == 'ubuntu':
                    sudo('./utils/kill_gunicorn.sh')
                else:
                    run('./utils/kill_gunicorn.sh')

@parallel
def kill():
    sudo('supervisorctl reload')
    with settings(warn_only=True):
        if env.user == 'ubuntu':
            sudo('./utils/kill_gunicorn.sh')
        else:
            run('./utils/kill_gunicorn.sh')

def deploy_node():
    with cd(env.NEWSBLUR_PATH):
        run('sudo supervisorctl restart node_unread')
        run('sudo supervisorctl restart node_favicons')

def gunicorn_restart():
    restart_gunicorn()

def restart_gunicorn():
    with cd(env.NEWSBLUR_PATH), settings(warn_only=True):
        run('sudo supervisorctl restart gunicorn')

def gunicorn_stop():
    with cd(env.NEWSBLUR_PATH), settings(warn_only=True):
        run('sudo supervisorctl stop gunicorn')

def staging():
    with cd('~/staging'):
        run('git pull')
        run('kill -HUP `cat logs/gunicorn.pid`')
        run('curl -s http://dev.newsblur.com > /dev/null')
        run('curl -s http://dev.newsblur.com/m/ > /dev/null')

def staging_full():
    with cd('~/staging'):
        run('git pull')
        run('./manage.py migrate')
        run('kill -HUP `cat logs/gunicorn.pid`')
        run('curl -s http://dev.newsblur.com > /dev/null')
        run('curl -s http://dev.newsblur.com/m/ > /dev/null')

@parallel
def celery():
    celery_slow()

def celery_slow():
    with cd(env.NEWSBLUR_PATH):
        run('git pull')
    celery_stop()
    celery_start()

@parallel
def celery_fast():
    with cd(env.NEWSBLUR_PATH):
        run('git pull')
    celery_reload()

@parallel
def celery_stop():
    with cd(env.NEWSBLUR_PATH):
        sudo('supervisorctl stop celery')
        with settings(warn_only=True):
            if env.user == 'ubuntu':
                sudo('./utils/kill_celery.sh')
            else:
                run('./utils/kill_celery.sh')

@parallel
def celery_start():
    with cd(env.NEWSBLUR_PATH):
        run('sudo supervisorctl start celery')
        run('tail logs/newsblur.log')

@parallel
def celery_reload():
    with cd(env.NEWSBLUR_PATH):
        run('sudo supervisorctl reload celery')
        run('tail logs/newsblur.log')

def kill_celery():
    with cd(env.NEWSBLUR_PATH):
        with settings(warn_only=True):
            if env.user == 'ubuntu':
                sudo('./utils/kill_celery.sh')
            else:
                run('./utils/kill_celery.sh')  

def compress_assets(bundle=False):
    local('jammit -c assets.yml --base-url http://www.newsblur.com --output static')
    local('tar -czf static.tgz static/*')

def transfer_assets():
    put('static.tgz', '%s/static/' % env.NEWSBLUR_PATH)
    run('tar -xzf static/static.tgz')
    run('rm -f static/static.tgz')

def cleanup_assets():
    local('rm -f static.tgz')

# ===========
# = Backups =
# ===========

def backup_mongo():
    with cd(os.path.join(env.NEWSBLUR_PATH, 'utils/backups')):
        # run('./mongo_backup.sh')
        run('python backup_mongo.py')

def backup_postgresql():
    # crontab for postgres master server
    # 0 4 * * * python /srv/newsblur/utils/backups/backup_psql.py
    # 0 * * * * sudo find /var/lib/postgresql/9.2/archive -mtime +1 -exec rm {} \;
    # 0 */4 * * * sudo find /var/lib/postgresql/9.2/archive -type f -mmin +360 -delete
    with cd(os.path.join(env.NEWSBLUR_PATH, 'utils/backups')):
        run('python backup_psql.py')

# ===============
# = Calibration =
# ===============

def sync_time():
    with settings(warn_only=True):
        sudo("/etc/init.d/ntp stop")
        sudo("ntpdate pool.ntp.org")
        sudo("/etc/init.d/ntp start")

def setup_time_calibration():
    sudo('apt-get -y install ntp')
    put('config/ntpdate.cron', '%s/' % env.NEWSBLUR_PATH)
    sudo('chown root.root %s/ntpdate.cron' % env.NEWSBLUR_PATH)
    sudo('chmod 755 %s/ntpdate.cron' % env.NEWSBLUR_PATH)
    sudo('mv %s/ntpdate.cron /etc/cron.hourly/ntpdate' % env.NEWSBLUR_PATH)
    with settings(warn_only=True):
        sudo('/etc/cron.hourly/ntpdate')

# =============
# = Bootstrap =
# =============

def setup_common():
    setup_installs()
    change_shell()
    setup_user()
    setup_sudoers()
    setup_ulimit()
    setup_repo()
    setup_repo_local_settings()
    setup_local_files()
    setup_time_calibration()
    setup_libxml()
    setup_python()
    # setup_psycopg()
    setup_supervisor()
    setup_hosts()
    config_pgbouncer()
    setup_mongoengine()
    setup_forked_mongoengine()
    setup_pymongo_repo()
    setup_logrotate()
    setup_nginx()
    setup_munin()

def setup_all():
    setup_common()
    setup_app(skip_common=True)
    setup_db(skip_common=True)
    setup_task(skip_common=True)

def setup_app(skip_common=False):
    if not skip_common:
        setup_common()
    setup_app_firewall()
    setup_app_motd()
    copy_app_settings()
    configure_nginx()
    setup_gunicorn(supervisor=True)
    update_gunicorn()
    setup_node()
    configure_node()
    pre_deploy()
    deploy()
    config_monit_app()

def setup_db(engine=None, skip_common=False):
    if not skip_common:
        setup_common()
    setup_db_firewall()
    setup_db_motd()
    copy_task_settings()
    # if engine == "memcached":
    #     setup_memcached()
    if engine == "postgres":
        setup_postgres(standby=False)
    elif engine == "postgres_slave":
        setup_postgres(standby=True)
    elif engine == "mongo":
        setup_mongo()
    elif engine == "redis":
        setup_redis()
    elif engine == "redis_slave":
        setup_redis(slave=True)
    setup_gunicorn(supervisor=False)
    setup_db_munin()

    # if env.user == 'ubuntu':
    #     setup_db_mdadm()

def setup_task(queue=None, skip_common=False):
    if not skip_common:
        setup_common()
    setup_task_firewall()
    setup_task_motd()
    copy_task_settings()
    enable_celery_supervisor(queue)
    setup_gunicorn(supervisor=False)
    update_gunicorn()
    config_monit_task()

# ==================
# = Setup - Common =
# ==================

def setup_installs():
    sudo('apt-get -y update')
    sudo('apt-get -y upgrade')
    sudo('apt-get -y install build-essential gcc scons libreadline-dev sysstat iotop git python-dev locate python-software-properties software-properties-common libpcre3-dev libncurses5-dev libdbd-pg-perl libssl-dev make pgbouncer python-psycopg2 libyaml-0-2 python-yaml python-numpy python-scipy python-imaging curl monit ufw')

    # sudo('add-apt-repository ppa:pitti/postgresql')
    sudo('apt-get -y update')
    sudo('apt-get -y install postgresql-client')
    sudo('mkdir -p /var/run/postgresql')
    sudo('chown postgres.postgres /var/run/postgresql')
    run('curl -O http://peak.telecommunity.com/dist/ez_setup.py')
    sudo('python ez_setup.py -U setuptools && rm ez_setup.py')
    with settings(warn_only=True):
        sudo('mkdir -p %s' % env.VENDOR_PATH)
        sudo('chown %s.%s %s' % (env.user, env.user, env.VENDOR_PATH))

def change_shell():
    sudo('apt-get -y install zsh')
    with settings(warn_only=True):
        run('git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh')
    sudo('chsh %s -s /bin/zsh' % env.user)

def setup_user():
    # run('useradd -c "NewsBlur" -m newsblur -s /bin/zsh')
    # run('openssl rand -base64 8 | tee -a ~conesus/.password | passwd -stdin conesus')
    run('mkdir -p ~/.ssh && chmod 700 ~/.ssh')
    run('rm -fr ~/.ssh/id_dsa*')
    run('ssh-keygen -t dsa -f ~/.ssh/id_dsa -N ""')
    run('touch ~/.ssh/authorized_keys')
    put("~/.ssh/id_dsa.pub", "authorized_keys")
    run('echo `cat authorized_keys` >> ~/.ssh/authorized_keys')
    run('rm authorized_keys')

def add_machine_to_ssh():
    put("~/.ssh/id_dsa.pub", "local_keys")
    run("echo `cat local_keys` >> .ssh/authorized_keys")
    run("rm local_keys")

def setup_repo():
    sudo('mkdir -p /srv')
    sudo('chown -R %s.%s /srv' % (env.user, env.user))
    with settings(warn_only=True):
        run('git clone https://github.com/samuelclay/NewsBlur.git %s' % env.NEWSBLUR_PATH)
    with settings(warn_only=True):
        sudo('ln -sfn /srv/code /home/%s/code' % env.user)
        sudo('ln -sfn /srv/newsblur /home/%s/newsblur' % env.user)

def setup_repo_local_settings():
    with cd(env.NEWSBLUR_PATH):
        run('cp local_settings.py.template local_settings.py')
        run('mkdir -p logs')
        run('touch logs/newsblur.log')

def copy_local_settings():
    with cd(env.NEWSBLUR_PATH):
        put('local_settings.py.server', 'local_settings.py')

def setup_local_files():
    put("config/toprc", "./.toprc")
    put("config/zshrc", "./.zshrc")
    put('config/gitconfig.txt', './.gitconfig')
    put('config/ssh.conf', './.ssh/config')

def setup_libxml():
    sudo('apt-get -y install libxml2-dev libxslt1-dev python-lxml')

def setup_libxml_code():
    with cd(env.VENDOR_PATH):
        run('git clone git://git.gnome.org/libxml2')
        run('git clone git://git.gnome.org/libxslt')

    with cd(os.path.join(env.VENDOR_PATH, 'libxml2')):
        run('./configure && make && sudo make install')

    with cd(os.path.join(env.VENDOR_PATH, 'libxslt')):
        run('./configure && make && sudo make install')

def setup_psycopg():
    sudo('easy_install -U psycopg2')

def setup_python():
    # sudo('easy_install -U pip')
    sudo('easy_install -U $(<%s)' %
         os.path.join(env.NEWSBLUR_PATH, 'config/requirements.txt'))
    put('config/pystartup.py', '.pystartup')

    # with cd(os.path.join(env.NEWSBLUR_PATH, 'vendor/cjson')):
    #     sudo('python setup.py install')

    with settings(warn_only=True):
        sudo('su -c \'echo "import sys; sys.setdefaultencoding(\\\\"utf-8\\\\")" > /usr/lib/python2.7/sitecustomize.py\'')

    if env.user == 'ubuntu':
        with settings(warn_only=True):
            sudo('chown -R ubuntu.ubuntu /home/ubuntu/.python-eggs')

# PIL - Only if python-imaging didn't install through apt-get, like on Mac OS X.
def setup_imaging():
    sudo('easy_install pil')

def setup_supervisor():
    sudo('apt-get -y install supervisor')
    put('config/supervisord.conf', '/etc/supervisor/supervisord.conf', use_sudo=True)
    sudo('/etc/init.d/supervisor stop')
    sudo('sleep 2')
    sudo('/etc/init.d/supervisor start')

@parallel
def setup_hosts():
    put('../secrets-newsblur/configs/hosts', '/etc/hosts', use_sudo=True)

def config_pgbouncer():
    put('config/pgbouncer.conf', '/etc/pgbouncer/pgbouncer.ini', use_sudo=True)
    put('../secrets-newsblur/configs/pgbouncer_auth.conf', '/etc/pgbouncer/userlist.txt', use_sudo=True)
    sudo('echo "START=1" > /etc/default/pgbouncer')
    sudo('su postgres -c "/etc/init.d/pgbouncer stop"', pty=False)
    with settings(warn_only=True):
        sudo('pkill -9 pgbouncer')
        run('sleep 2')
    sudo('/etc/init.d/pgbouncer start', pty=False)

def bounce_pgbouncer():
    sudo('su postgres -c "/etc/init.d/pgbouncer stop"', pty=False)
    run('sleep 4')
    with settings(warn_only=True):
        sudo('pkill pgbouncer')
        run('sleep 4')
    run('sudo /etc/init.d/pgbouncer start', pty=False)
    run('sleep 2')

def config_monit_task():
    put('config/monit_task.conf', '/etc/monit/conf.d/celery.conf', use_sudo=True)
    sudo('echo "startup=1" > /etc/default/monit')
    sudo('/etc/init.d/monit restart')

def config_monit_app():
    put('config/monit_app.conf', '/etc/monit/conf.d/gunicorn.conf', use_sudo=True)
    sudo('echo "startup=1" > /etc/default/monit')
    sudo('/etc/init.d/monit restart')

def config_monit_db():
    put('config/monit_db.conf', '/etc/monit/conf.d/celery.conf', use_sudo=True)
    sudo('echo "startup=1" > /etc/default/monit')
    sudo('/etc/init.d/monit restart')

def setup_mongoengine():
    with cd(env.VENDOR_PATH), settings(warn_only=True):
        run('rm -fr mongoengine')
        run('git clone https://github.com/MongoEngine/mongoengine.git')
        sudo('rm -fr /usr/local/lib/python2.7/dist-packages/mongoengine')
        sudo('rm -fr /usr/local/lib/python2.7/dist-packages/mongoengine-*')
        sudo('ln -sfn %s /usr/local/lib/python2.7/dist-packages/mongoengine' %
             os.path.join(env.VENDOR_PATH, 'mongoengine/mongoengine'))

def setup_pymongo_repo():
    with cd(env.VENDOR_PATH), settings(warn_only=True):
        run('git clone git://github.com/mongodb/mongo-python-driver.git pymongo')
    # with cd(os.path.join(env.VENDOR_PATH, 'pymongo')):
    #     sudo('python setup.py install')
    sudo('rm -fr /usr/local/lib/python2.7/dist-packages/pymongo*')
    sudo('rm -fr /usr/local/lib/python2.7/dist-packages/bson*')
    sudo('rm -fr /usr/local/lib/python2.7/dist-packages/gridfs*')
    sudo('ln -sfn %s /usr/local/lib/python2.7/dist-packages/' %
         os.path.join(env.VENDOR_PATH, 'pymongo/{pymongo,bson,gridfs}'))

def setup_forked_mongoengine():
    with cd(os.path.join(env.VENDOR_PATH, 'mongoengine')), settings(warn_only=True):
        run('git remote add clay https://github.com/samuelclay/mongoengine.git')
        run('git pull')
        run('git fetch clay')
        run('git checkout -b clay_master clay/master')

def switch_forked_mongoengine():
    with cd(os.path.join(env.VENDOR_PATH, 'mongoengine')):
        run('git co dev')
        run('git pull %s dev --force' % env.user)
        # run('git checkout .')
        # run('git checkout master')
        # run('get branch -D dev')
        # run('git checkout -b dev origin/dev')

def setup_logrotate():
    put('config/logrotate.conf', '/etc/logrotate.d/newsblur', use_sudo=True)
    put('config/logrotate.mongo.conf', '/etc/logrotate.d/mongodb', use_sudo=True)

def setup_ulimit():
    # Increase File Descriptor limits.
    run('export FILEMAX=`sysctl -n fs.file-max`', pty=False)
    sudo('mv /etc/security/limits.conf /etc/security/limits.conf.bak', pty=False)
    sudo('touch /etc/security/limits.conf', pty=False)
    sudo('chmod 666 /etc/security/limits.conf', pty=False)
    run('echo "root soft nofile 100000" >> /etc/security/limits.conf', pty=False)
    run('echo "root hard nofile 100000" >> /etc/security/limits.conf', pty=False)
    run('echo "* soft nofile 100000" >> /etc/security/limits.conf', pty=False)
    run('echo "* hard nofile 100090" >> /etc/security/limits.conf', pty=False)
    sudo('chmod 644 /etc/security/limits.conf', pty=False)
    sudo('chmod 666 /etc/sysctl.conf', pty=False)
    run('echo "fs.file-max = 100000" >> /etc/sysctl.conf', pty=False)
    sudo('chmod 644 /etc/sysctl.conf', pty=False)
    sudo('sysctl -p')

    # run('touch /home/ubuntu/.bash_profile')
    # run('echo "ulimit -n $FILEMAX" >> /home/ubuntu/.bash_profile')

    # Increase Ephemeral Ports.
    # sudo chmod 666 /etc/sysctl.conf
    # echo "net.ipv4.ip_local_port_range = 1024 65535" >> /etc/sysctl.conf
    # sudo chmod 644 /etc/sysctl.conf

def setup_sudoers(user=None):
    sudo('su - root -c "echo \\\\"%s ALL=(ALL) NOPASSWD: ALL\\\\" >> /etc/sudoers"' % (user or env.user))

def setup_nginx():
    NGINX_VERSION = '1.4.1'
    with cd(env.VENDOR_PATH), settings(warn_only=True):
        sudo("groupadd nginx")
        sudo("useradd -g nginx -d /var/www/htdocs -s /bin/false nginx")
        run('wget http://nginx.org/download/nginx-%s.tar.gz' % NGINX_VERSION)
        run('tar -xzf nginx-%s.tar.gz' % NGINX_VERSION)
        run('rm nginx-%s.tar.gz' % NGINX_VERSION)
        with cd('nginx-%s' % NGINX_VERSION):
            run('./configure --with-http_ssl_module --with-http_stub_status_module --with-http_gzip_static_module')
            run('make')
            sudo('make install')
    configure_nginx()

def configure_nginx():
    put("config/nginx.conf", "/usr/local/nginx/conf/nginx.conf", use_sudo=True)
    sudo("mkdir -p /usr/local/nginx/conf/sites-enabled")
    sudo("mkdir -p /var/log/nginx")
    put("config/nginx.newsblur.conf", "/usr/local/nginx/conf/sites-enabled/newsblur.conf", use_sudo=True)
    put("config/nginx-init", "/etc/init.d/nginx", use_sudo=True)
    sudo('sed -i -e s/nginx_none/`cat /etc/hostname`/g /usr/local/nginx/conf/sites-enabled/newsblur.conf')
    sudo("chmod 0755 /etc/init.d/nginx")
    sudo("/usr/sbin/update-rc.d -f nginx defaults")
    sudo("/etc/init.d/nginx restart")
    copy_certificates()

# ===============
# = Setup - App =
# ===============

def setup_app_firewall():
    sudo('ufw default deny')
    sudo('ufw allow ssh')       # ssh
    sudo('ufw allow 80')        # http
    sudo('ufw allow 8000')      # gunicorn
    sudo('ufw allow 8888')      # socket.io
    sudo('ufw allow 8889')      # socket.io ssl
    sudo('ufw allow 443')       # https
    sudo('ufw --force enable')

def setup_app_motd():
    put('config/motd_app.txt', '/etc/motd.tail', use_sudo=True)

def setup_gunicorn(supervisor=True):
    if supervisor:
        put('config/supervisor_gunicorn.conf', '/etc/supervisor/conf.d/gunicorn.conf', use_sudo=True)
    with cd(env.VENDOR_PATH):
        sudo('rm -fr gunicorn')
        run('git clone git://github.com/benoitc/gunicorn.git')
    with cd(os.path.join(env.VENDOR_PATH, 'gunicorn')):
        run('git pull')
        sudo('python setup.py develop')


def update_gunicorn():
    with cd(os.path.join(env.VENDOR_PATH, 'gunicorn')):
        run('git pull')
        sudo('python setup.py develop')

def setup_staging():
    run('git clone https://github.com/samuelclay/NewsBlur.git staging')
    with cd('~/staging'):
        run('cp ../newsblur/local_settings.py local_settings.py')
        run('mkdir -p logs')
        run('touch logs/newsblur.log')

def setup_node():
    sudo('add-apt-repository -y ppa:chris-lea/node.js')
    sudo('apt-get update')
    sudo('apt-get install -y nodejs')
    run('curl -L https://npmjs.org/install.sh | sudo sh')
    sudo('npm install -g supervisor')
    sudo('ufw allow 8888')

def configure_node():
    sudo('rm -fr /etc/supervisor/conf.d/node.conf')
    put('config/supervisor_node_unread.conf', '/etc/supervisor/conf.d/node_unread.conf', use_sudo=True)
    put('config/supervisor_node_unread_ssl.conf', '/etc/supervisor/conf.d/node_unread_ssl.conf', use_sudo=True)
    put('config/supervisor_node_favicons.conf', '/etc/supervisor/conf.d/node_favicons.conf', use_sudo=True)
    sudo('supervisorctl reload')

@parallel
def copy_app_settings():
    put('../secrets-newsblur/settings/app_settings.py', '%s/local_settings.py' % env.NEWSBLUR_PATH)
    run('echo "\nSERVER_NAME = \\\\"`hostname`\\\\"" >> %s/local_settings.py' % env.NEWSBLUR_PATH)

def copy_certificates():
    cert_path = '%s/config/certificates/' % env.NEWSBLUR_PATH
    run('mkdir -p %s' % cert_path)
    put('../secrets-newsblur/certificates/newsblur.com.crt', cert_path)
    put('../secrets-newsblur/certificates/newsblur.com.key', cert_path)
    run('cat %s/newsblur.com.crt > %s/newsblur.pem' % (cert_path, cert_path))
    run('cat %s/newsblur.com.key >> %s/newsblur.pem' % (cert_path, cert_path))
    # put('../secrets-newsblur/certificates/comodo/EssentialSSLCA_2.crt', '%s/config/certificates/intermediate.crt' % env.NEWSBLUR_PATH)

@parallel
def maintenance_on():
    put('templates/maintenance_off.html', '%s/templates/maintenance_off.html' % env.NEWSBLUR_PATH)
    with cd(env.NEWSBLUR_PATH):
        run('mv templates/maintenance_off.html templates/maintenance_on.html')

@parallel
def maintenance_off():
    with cd(env.NEWSBLUR_PATH):
        run('mv templates/maintenance_on.html templates/maintenance_off.html')
        run('git checkout templates/maintenance_off.html')

def setup_haproxy(debug=False):
    sudo('ufw allow 81')    # nginx moved
    sudo('ufw allow 1936')  # haproxy stats
    sudo('apt-get install -y haproxy')
    sudo('apt-get remove -y haproxy')
    with cd(env.VENDOR_PATH):
        run('wget http://haproxy.1wt.eu/download/1.5/src/devel/haproxy-1.5-dev17.tar.gz')
        run('tar -xf haproxy-1.5-dev17.tar.gz')
        with cd('haproxy-1.5-dev17'):
            run('make TARGET=linux2628 USE_PCRE=1 USE_OPENSSL=1 USE_ZLIB=1')
            sudo('make install')
    put('config/haproxy-init', '/etc/init.d/haproxy', use_sudo=True)
    sudo('chmod u+x /etc/init.d/haproxy')
    sudo('mkdir -p /etc/haproxy')
    if debug:
        put('config/debug_haproxy.conf', '/etc/haproxy/haproxy.cfg', use_sudo=True)
    else:
        put('../secrets-newsblur/configs/haproxy.conf', '/etc/haproxy/haproxy.cfg', use_sudo=True)
    sudo('echo "ENABLED=1" > /etc/default/haproxy')
    cert_path = "%s/config/certificates" % env.NEWSBLUR_PATH
    run('cat %s/newsblur.com.crt > %s/newsblur.pem' % (cert_path, cert_path))
    run('cat %s/newsblur.com.key >> %s/newsblur.pem' % (cert_path, cert_path))
    put('config/haproxy_rsyslog.conf', '/etc/rsyslog.d/49-haproxy.conf', use_sudo=True)
    sudo('restart rsyslog')

    sudo('/etc/init.d/haproxy stop')
    sudo('/etc/init.d/haproxy start')

def config_haproxy(debug=False):
    if debug:
        put('config/debug_haproxy.conf', '/etc/haproxy/haproxy.cfg', use_sudo=True)
    else:
        put('../secrets-newsblur/configs/haproxy.conf', '/etc/haproxy/haproxy.cfg', use_sudo=True)
    sudo('/etc/init.d/haproxy reload')

def upgrade_django():
    with cd(env.NEWSBLUR_PATH), settings(warn_only=True):
        sudo('supervisorctl stop gunicorn')
        run('./utils/kill_gunicorn.sh')
        sudo('easy_install -U django gunicorn')
        pull()
        sudo('supervisorctl reload')
def upgrade_pil():
    with cd(env.NEWSBLUR_PATH):
        sudo('easy_install pillow')
        # celery_stop()
        pull()
        sudo('apt-get remove -y python-imaging')
        kill()

def downgrade_pil():
    with cd(env.NEWSBLUR_PATH):
        sudo('apt-get install -y python-imaging')
        sudo('rm -fr /usr/local/lib/python2.7/dist-packages/Pillow*')
        pull()
        kill()

# ==============
# = Setup - DB =
# ==============

@parallel
def setup_db_firewall():
    ports = [
        5432,   # PostgreSQL
        27017,  # MongoDB
        28017,  # MongoDB web
        6379,   # Redis
        # 11211,  # Memcached
        3060,   # Node original page server
        9200,   # Elasticsearch
    ]
    sudo('ufw default deny')
    sudo('ufw allow ssh')
    sudo('ufw allow 80')

    # DigitalOcean
    for ip in set(env.roledefs['app'] +
                  env.roledefs['db'] +
                  env.roledefs['dev'] +
                  env.roledefs['debug'] +
                  env.roledefs['task'] +
                  env.roledefs['node']):
        sudo('ufw allow proto tcp from %s to any port %s' % (
            ip,
            ','.join(map(str, ports))
        ))

    # EC2
    for host in set(env.roledefs['ec2task']):
        ip = re.search('ec2-(\d+-\d+-\d+-\d+)', host).group(1).replace('-', '.')
        sudo('ufw allow proto tcp from %s to any port %s' % (
            ip,
            ','.join(map(str, ports))
        ))

    sudo('ufw --force enable')

def setup_db_motd():
    put('config/motd_db.txt', '/etc/motd.tail', use_sudo=True)

def setup_rabbitmq():
    sudo('echo "deb http://www.rabbitmq.com/debian/ testing main" >> /etc/apt/sources.list')
    run('wget http://www.rabbitmq.com/rabbitmq-signing-key-public.asc')
    sudo('apt-key add rabbitmq-signing-key-public.asc')
    run('rm rabbitmq-signing-key-public.asc')
    sudo('apt-get update')
    sudo('apt-get install -y rabbitmq-server')
    sudo('rabbitmqctl add_user newsblur newsblur')
    sudo('rabbitmqctl add_vhost newsblurvhost')
    sudo('rabbitmqctl set_permissions -p newsblurvhost newsblur ".*" ".*" ".*"')

# def setup_memcached():
#     sudo('apt-get -y install memcached')

def setup_postgres(standby=False):
    # shmmax = 1140047872
    sudo('add-apt-repository ppa:pitti/postgresql')
    sudo('apt-get update')
    sudo('apt-get -y install postgresql-9.2 postgresql-client postgresql-contrib libpq-dev')
    put('config/postgresql%s.conf' % (
        ('_standby' if standby else ''),
    ), '/etc/postgresql/9.2/main/postgresql.conf', use_sudo=True)
    # sudo('echo "%s" > /proc/sys/kernel/shmmax' % shmmax)
    # sudo('echo "\nkernel.shmmax = %s" > /etc/sysctl.conf' % shmmax)
    # sudo('sysctl -p')

    if standby:
        put('config/postgresql_recovery.conf', '/var/lib/postgresql/9.1/recovery.conf', use_sudo=True)

    sudo('/etc/init.d/postgresql stop')
    sudo('/etc/init.d/postgresql start')

def copy_postgres_to_standby():
    slave = 'db12.newsblur.com'
    # Make sure you can ssh from master to slave and back.
    # Need to give postgres accounts keys in authroized_keys.

    # sudo('su postgres -c "psql -c \\"SELECT pg_start_backup(\'label\', true)\\""', pty=False)
    sudo('su postgres -c \"rsync -a --stats --progress /var/lib/postgresql/9.1/main postgres@%s:/var/lib/postgresql/9.1/ --exclude postmaster.pid\"' % slave, pty=False)
    # sudo('su postgres -c "psql -c \\"SELECT pg_stop_backup()\\""', pty=False)

def setup_mongo():
    sudo('apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10')
    # sudo('echo "deb http://downloads.mongodb.org/distros/ubuntu 10.10 10gen" >> /etc/apt/sources.list.d/10gen.list')
    sudo('echo "deb http://downloads-distro.mongodb.org/repo/debian-sysvinit dist 10gen" >> /etc/apt/sources.list')
    sudo('apt-get update')
    sudo('apt-get -y install mongodb-10gen')
    put('config/mongodb.%s.conf' % ('prod' if env.user != 'ubuntu' else 'ec2'),
        '/etc/mongodb.conf', use_sudo=True)
    run('echo "ulimit -n 10000" > mongodb.defaults')
    sudo('mv mongodb.defaults /etc/default/mongodb')
    sudo('/etc/init.d/mongodb restart')
    put('config/logrotate.mongo.conf', '/etc/logrotate.d/mongodb', use_sudo=True)

def setup_mongo_mms():
    pull()
    put('../secrets-newsblur/settings/mongo_mms_settings.py', '%s/vendor/mms-agent/settings.py' % env.NEWSBLUR_PATH)
    with cd(env.NEWSBLUR_PATH):
        put('config/supervisor_mongomms.conf', '/etc/supervisor/conf.d/mongomms.conf', use_sudo=True)
    sudo('supervisorctl reread')
    sudo('supervisorctl update')


def setup_redis(slave=False):
    redis_version = '2.6.12'
    with cd(env.VENDOR_PATH):
        run('wget http://redis.googlecode.com/files/redis-%s.tar.gz' % redis_version)
        run('tar -xzf redis-%s.tar.gz' % redis_version)
        run('rm redis-%s.tar.gz' % redis_version)
    with cd(os.path.join(env.VENDOR_PATH, 'redis-%s' % redis_version)):
        sudo('make install')
    put('config/redis-init', '/etc/init.d/redis', use_sudo=True)
    sudo('chmod u+x /etc/init.d/redis')
    put('config/redis.conf', '/etc/redis.conf', use_sudo=True)
    if slave:
        put('config/redis_slave.conf', '/etc/redis_server.conf', use_sudo=True)
    else:
        put('config/redis_master.conf', '/etc/redis_server.conf', use_sudo=True)
    sudo('chmod 666 /proc/sys/vm/overcommit_memory', pty=False)
    run('echo "1" > /proc/sys/vm/overcommit_memory', pty=False)
    sudo('chmod 644 /proc/sys/vm/overcommit_memory', pty=False)
    sudo('mkdir -p /var/lib/redis')
    sudo('update-rc.d redis defaults')
    sudo('/etc/init.d/redis stop')
    sudo('/etc/init.d/redis start')

def setup_munin():
    # sudo('apt-get update')
    sudo('apt-get install -y munin munin-node munin-plugins-extra spawn-fcgi')
    put('config/munin.conf', '/etc/munin/munin.conf', use_sudo=True)
    put('config/spawn_fcgi_munin_graph.conf', '/etc/init.d/spawn_fcgi_munin_graph', use_sudo=True)
    put('config/spawn_fcgi_munin_html.conf', '/etc/init.d/spawn_fcgi_munin_html', use_sudo=True)
    sudo('chmod u+x /etc/init.d/spawn_fcgi_munin_graph')
    sudo('chmod u+x /etc/init.d/spawn_fcgi_munin_html')
    with settings(warn_only=True):
        sudo('chown nginx.www-data munin-cgi*')
    with settings(warn_only=True):
        sudo('/etc/init.d/spawn_fcgi_munin_graph stop')
        sudo('/etc/init.d/spawn_fcgi_munin_graph start')
        sudo('update-rc.d spawn_fcgi_munin_graph defaults')
        sudo('/etc/init.d/spawn_fcgi_munin_html stop')
        sudo('/etc/init.d/spawn_fcgi_munin_html start')
        sudo('update-rc.d spawn_fcgi_munin_html defaults')
    sudo('/etc/init.d/munin-node restart')
    with settings(warn_only=True):
        sudo('chown nginx.www-data munin-cgi*')
        sudo('chmod a+rw /var/log/munin/*')
    with settings(warn_only=True):
        sudo('/etc/init.d/spawn_fcgi_munin_graph start')
        sudo('/etc/init.d/spawn_fcgi_munin_html start')


def setup_db_munin():
    sudo('cp -frs %s/config/munin/mongo* /etc/munin/plugins/' % env.NEWSBLUR_PATH)
    sudo('cp -frs %s/config/munin/pg_* /etc/munin/plugins/' % env.NEWSBLUR_PATH)
    with cd(env.VENDOR_PATH), settings(warn_only=True):
        run('git clone git://github.com/samuel/python-munin.git')
    with cd(os.path.join(env.VENDOR_PATH, 'python-munin')):
        run('sudo python setup.py install')
    sudo('/etc/init.d/munin-node restart')

def enable_celerybeat():
    with cd(env.NEWSBLUR_PATH):
        run('mkdir -p data')
    put('config/supervisor_celerybeat.conf', '/etc/supervisor/conf.d/celerybeat.conf', use_sudo=True)
    put('config/supervisor_celeryd_work_queue.conf', '/etc/supervisor/conf.d/celeryd_work_queue.conf', use_sudo=True)
    put('config/supervisor_celeryd_beat.conf', '/etc/supervisor/conf.d/celeryd_beat.conf', use_sudo=True)
    put('config/supervisor_celeryd_beat_feeds.conf', '/etc/supervisor/conf.d/celeryd_beat_feeds.conf', use_sudo=True)
    sudo('supervisorctl reread')
    sudo('supervisorctl update')

def setup_db_mdadm():
    sudo('apt-get -y install xfsprogs mdadm')
    sudo('yes | mdadm --create /dev/md0 --level=0 -c256 --raid-devices=4 /dev/xvdf /dev/xvdg /dev/xvdh /dev/xvdi')
    sudo('mkfs.xfs /dev/md0')
    sudo('mkdir -p /srv/db')
    sudo('mount -t xfs -o rw,nobarrier,noatime,nodiratime /dev/md0 /srv/db')
    sudo('mkdir -p /srv/db/mongodb')
    sudo('chown mongodb.mongodb /srv/db/mongodb')
    sudo("echo 'DEVICE /dev/xvdf /dev/xvdg /dev/xvdh /dev/xvdi' | sudo tee -a /etc/mdadm/mdadm.conf")
    sudo("mdadm --examine --scan | sudo tee -a /etc/mdadm/mdadm.conf")
    sudo("echo '/dev/md0   /srv/db xfs   rw,nobarrier,noatime,nodiratime,noauto   0 0' | sudo tee -a  /etc/fstab")
    sudo("sudo update-initramfs -u -v -k `uname -r`")

def setup_original_page_server():
    setup_node()
    sudo('mkdir -p /srv/originals')
    sudo('chown %s.%s -R /srv/originals' % (env.user, env.user))        # We assume that the group is the same name as the user. It's common on linux
    put('config/supervisor_node_original.conf',
        '/etc/supervisor/conf.d/node_original.conf', use_sudo=True)
    sudo('supervisorctl reread')
    sudo('supervisorctl reload')

def setup_elasticsearch():
    ES_VERSION = "0.90.0"
    sudo('apt-get update')
    sudo('apt-get install openjdk-7-jre -y')

    with cd(env.VENDOR_PATH):
        run('mkdir elasticsearch-%s' % ES_VERSION)
    with cd(os.path.join(env.VENDOR_PATH, 'elasticsearch-%s' % ES_VERSION)):
        run('wget http://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-%s.deb' % ES_VERSION)
        sudo('dpkg -i elasticsearch-%s.deb' % ES_VERSION)

# ================
# = Setup - Task =
# ================

def setup_task_firewall():
    sudo('ufw default deny')
    sudo('ufw allow ssh')
    sudo('ufw allow 80')
    sudo('ufw --force enable')

def setup_task_motd():
    put('config/motd_task.txt', '/etc/motd.tail', use_sudo=True)

def enable_celery_supervisor(queue=None):
    if not queue:
        put('config/supervisor_celeryd.conf', '/etc/supervisor/conf.d/celeryd.conf', use_sudo=True)
    else:
        put('config/supervisor_celeryd_%s.conf' % queue, '/etc/supervisor/conf.d/celeryd.conf', use_sudo=True)

    sudo('supervisorctl reread')
    sudo('supervisorctl update')

@parallel
def copy_task_settings():
    server_hostname = run('hostname')
    if 'task' in server_hostname:
        host = server_hostname
    elif env.host:
        host = env.host.split('.', 2)[0]
    else:
        host = env.host_string.split('.', 2)[0]

    with settings(warn_only=True):
        put('../secrets-newsblur/settings/task_settings.py', '%s/local_settings.py' % env.NEWSBLUR_PATH)
        run('echo "\nSERVER_NAME = \\\\"%s\\\\"" >> %s/local_settings.py' % (host, env.NEWSBLUR_PATH))

# =========================
# = Setup - Digital Ocean =
# =========================

def setup_do(name, size=2):
    INSTANCE_SIZE = "%sGB" % size
    IMAGE_NAME = "Ubuntu 12.10 x64 Server"
    doapi = dop.client.Client(django_settings.DO_CLIENT_KEY, django_settings.DO_API_KEY)
    sizes = dict((s.name, s.id) for s in doapi.sizes())
    size_id = sizes[INSTANCE_SIZE]
    ssh_key_id = doapi.all_ssh_keys()[0].id
    region_id = doapi.regions()[0].id
    images = dict((s.name, s.id) for s in doapi.images())
    image_id = images[IMAGE_NAME]
    name = do_name(name)
    instance = doapi.create_droplet(name=name,
                                    size_id=size_id,
                                    image_id=image_id,
                                    region_id=region_id,
                                    ssh_key_ids=[str(ssh_key_id)],
                                    virtio=True)
    print "Booting droplet: %s/%s (size: %s)" % (instance.id, IMAGE_NAME, INSTANCE_SIZE)

    instance = doapi.show_droplet(instance.id)
    i = 0
    while True:
        if instance.status == 'active':
            print "...booted: %s" % instance.ip_address
            time.sleep(5)
            break
        elif instance.status == 'new':
            print ".",
            sys.stdout.flush()
            instance = doapi.show_droplet(instance.id)
            i += 1
            time.sleep(i)
        else:
            print "!!! Error: %s" % instance.status
            return

    host = instance.ip_address
    env.host_string = host
    time.sleep(10)
    add_user_to_do()

def do_name(name):
    if re.search(r"[0-9]", name):
        print " ---> Using %s as hostname" % name
        return name
    else:
        hosts = do_roledefs(split=False)
        hostnames = [host.name for host in hosts]
        existing_hosts = [hostname for hostname in hostnames if name in hostname]
        for i in range(10, 50):
            try_host = "%s%02d" % (name, i)
            if try_host not in existing_hosts:
                print " ---> %s hosts in %s (%s). %s is unused." % (len(existing_hosts), name, 
                                                                    ', '.join(existing_hosts), try_host)
                return try_host
        
    
def add_user_to_do():
    env.user = "root"
    repo_user = "sclay"
    with settings(warn_only=True):
        run('useradd -m %s' % (repo_user))
        setup_sudoers("%s" % (repo_user))
    run('mkdir -p ~%s/.ssh && chmod 700 ~%s/.ssh' % (repo_user, repo_user))
    run('rm -fr ~%s/.ssh/id_dsa*' % (repo_user))
    run('ssh-keygen -t dsa -f ~%s/.ssh/id_dsa -N ""' % (repo_user))
    run('touch ~%s/.ssh/authorized_keys' % (repo_user))
    put("~/.ssh/id_dsa.pub", "authorized_keys")
    run('echo `cat authorized_keys` >> ~%s/.ssh/authorized_keys' % (repo_user))
    run('rm authorized_keys')
    run('chown %s.%s -R ~%s/.ssh' % (repo_user, repo_user, repo_user))
    env.user = repo_user

# ===============
# = Setup - EC2 =
# ===============

def setup_ec2():
    AMI_NAME = 'ami-834cf1ea'       # Ubuntu 64-bit 12.04 LTS
    # INSTANCE_TYPE = 'c1.medium'
    INSTANCE_TYPE = 'c1.medium'
    conn = EC2Connection(django_settings.AWS_ACCESS_KEY_ID, django_settings.AWS_SECRET_ACCESS_KEY)
    reservation = conn.run_instances(AMI_NAME, instance_type=INSTANCE_TYPE,
                                     key_name=env.user,
                                     security_groups=['db-mongo'])
    instance = reservation.instances[0]
    print "Booting reservation: %s/%s (size: %s)" % (reservation, instance, INSTANCE_TYPE)
    i = 0
    while True:
        if instance.state == 'pending':
            print ".",
            sys.stdout.flush()
            instance.update()
            i += 1
            time.sleep(i)
        elif instance.state == 'running':
            print "...booted: %s" % instance.public_dns_name
            time.sleep(5)
            break
        else:
            print "!!! Error: %s" % instance.state
            return

    host = instance.public_dns_name
    env.host_string = host



# ==============
# = Tasks - DB =
# ==============

def restore_postgres(port=5433):
    backup_date = '2013-01-29-09-00'
    yes = prompt("Dropping and creating NewsBlur PGSQL db. Sure?")
    if yes != 'y':
        return
    # run('PYTHONPATH=%s python utils/backups/s3.py get backup_postgresql_%s.sql.gz' % (env.NEWSBLUR_PATH, backup_date))
    # sudo('su postgres -c "createuser -p %s -U newsblur"' % (port,))
    run('dropdb newsblur -p %s -U postgres' % (port,), pty=False)
    run('createdb newsblur -p %s -O newsblur' % (port,), pty=False)
    run('pg_restore -p %s --role=newsblur --dbname=newsblur /Users/sclay/Documents/backups/backup_postgresql_%s.sql.gz' % (port, backup_date), pty=False)

def restore_mongo():
    backup_date = '2012-07-24-09-00'
    run('PYTHONPATH=/home/%s/newsblur python s3.py get backup_mongo_%s.tgz' % (env.user, backup_date))
    run('tar -xf backup_mongo_%s.tgz' % backup_date)
    run('mongorestore backup_mongo_%s' % backup_date)

# ======
# = S3 =
# ======

if django_settings:
    try:
        ACCESS_KEY  = django_settings.S3_ACCESS_KEY
        SECRET      = django_settings.S3_SECRET
        BUCKET_NAME = django_settings.S3_BACKUP_BUCKET  # Note that you need to create this bucket first
    except:
        print " ---> You need to fix django's settings. Enter python and type `import settings`."

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

def add_revsys_keys():
    put("~/Downloads/revsys-keys.pub", "revsys_keys")
    run('cat revsys_keys >> ~/.ssh/authorized_keys')
    run('rm revsys_keys')
