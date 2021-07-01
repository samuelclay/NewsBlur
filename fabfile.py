from fabric.api import cd, lcd, env, local, parallel, serial
from fabric.api import put, run, settings, sudo, prefix
from fabric.operations import prompt
from fabric.contrib import django
from fabric.contrib import files
from fabric.state import connections
# from fabric.colors import red, green, blue, cyan, magenta, white, yellow
from boto.s3.connection import S3Connection
from boto.s3.key import Key
from boto.ec2.connection import EC2Connection
import yaml
from pprint import pprint
from collections import defaultdict
from contextlib import contextmanager as _contextmanager
import os
import time
import sys
import re

# django.setup()

try:
    import digitalocean
except ImportError:
    print("Digital Ocean's API not loaded. Install python-digitalocean.")


django.settings_module('newsblur_web.settings')
try:
    from django.conf import settings as django_settings
except ImportError:
    print(" ---> Django not installed yet.")
    django_settings = None

# ============
# = DEFAULTS =
# ============

env.NEWSBLUR_PATH = "/srv/newsblur"
env.SECRETS_PATH  = "/srv/secrets-newsblur"
env.VENDOR_PATH   = "/srv/code"
env.user = 'sclay'
env.key_filename = os.path.join(env.SECRETS_PATH, 'keys/newsblur.key')
env.connection_attempts = 10
env.do_ip_to_hostname = {}
env.colorize_errors = True

# =========
# = Roles =
# =========

try:
    hosts_path = os.path.expanduser(os.path.join(env.SECRETS_PATH, 'configs/hosts.yml'))
    roles = yaml.load(open(hosts_path))
    for role_name, hosts in list(roles.items()):
        if isinstance(hosts, dict):
            roles[role_name] = [host for host in list(hosts.keys())]
    env.roledefs = roles
except:
    print(" ***> No role definitions found in %s. Using default roles." % hosts_path)
    env.roledefs = {
        'app'   : ['app01.newsblur.com'],
        'db'    : ['db01.newsblur.com'],
        'task'  : ['task01.newsblur.com'],
    }

def do_roledefs(split=False, debug=False):
    doapi = digitalocean.Manager(token=django_settings.DO_TOKEN_FABRIC)
    droplets = doapi.get_all_droplets()
    env.do_ip_to_hostname = {}
    hostnames = {}
    for droplet in droplets:
        roledef = re.split(r"([0-9]+)", droplet.name)[0]
        if roledef not in env.roledefs:
            env.roledefs[roledef] = []
        if roledef not in hostnames:
            hostnames[roledef] = []
        if droplet.ip_address not in hostnames[roledef]:
            hostnames[roledef].append({'name': droplet.name, 'address': droplet.ip_address})
            env.do_ip_to_hostname[droplet.ip_address] = droplet.name
        if droplet.ip_address not in env.roledefs[roledef]:
            env.roledefs[roledef].append(droplet.ip_address)

    if split:
        return hostnames
    return droplets

def list_do():
    droplets = assign_digitalocean_roledefs(split=True)
    pprint(droplets)

    # Uncomment below to print all IP addresses
    # for group in droplets.values():
    #     for server in group:
    #         if 'address' in server:
    #             print(server['address'])
    
    doapi = digitalocean.Manager(token=django_settings.DO_TOKEN_FABRIC)
    droplets = doapi.get_all_droplets()
    sizes = doapi.get_all_sizes()
    sizes = dict((size.slug, size.price_monthly) for size in sizes)
    role_costs = defaultdict(int)
    total_cost = 0
    for droplet in droplets:
        roledef = re.split(r"([0-9]+)", droplet.name)[0]
        cost = droplet.size['price_monthly']
        role_costs[roledef] += cost
        total_cost += cost
    
    print("\n\n Costs:")
    pprint(dict(role_costs))
    print(" ---> Total cost: $%s/month" % total_cost)
    
def host(*names):
    env.hosts = []
    env.doname = ','.join(names)
    hostnames = assign_digitalocean_roledefs(split=True)
    for role, hosts in list(hostnames.items()):
        for host in hosts:
            if isinstance(host, dict) and host['name'] in names:
                env.hosts.append(host['address'])
    print(" ---> Using %s as hosts" % env.hosts)
    
# ================
# = Environments =
# ================

def server():
    env.NEWSBLUR_PATH = "/srv/newsblur"
    env.VENDOR_PATH   = "/srv/code"

def assign_digitalocean_roledefs(split=False):
    server()
    droplets = do_roledefs(split=split)
    if split:
        for roledef, hosts in list(env.roledefs.items()):
            if roledef not in droplets:
                droplets[roledef] = hosts
    
    return droplets

def app():
    assign_digitalocean_roledefs()
    env.roles = ['app']

def web():
    assign_digitalocean_roledefs()
    env.roles = ['app', 'push', 'work', 'search']

def work():
    assign_digitalocean_roledefs()
    env.roles = ['work']

def www():
    assign_digitalocean_roledefs()
    env.roles = ['www']

def dev():
    assign_digitalocean_roledefs()
    env.roles = ['dev']

def debug():
    assign_digitalocean_roledefs()
    env.roles = ['debug']

def node():
    assign_digitalocean_roledefs()
    env.roles = ['node']

def push():
    assign_digitalocean_roledefs()
    env.roles = ['push']

def db():
    assign_digitalocean_roledefs()
    env.roles = ['db', 'search']

def task():
    assign_digitalocean_roledefs()
    env.roles = ['task']

def ec2task():
    ec2()
    env.roles = ['ec2task']

def ec2():
    env.user = 'ubuntu'
    env.key_filename = ['/Users/sclay/.ec2/sclay.pem']
    assign_digitalocean_roledefs()

def all():
    assign_digitalocean_roledefs()
    env.roles = ['app', 'db', 'debug', 'node', 'push', 'work', 'www', 'search']

# =============
# = Bootstrap =
# =============

def setup_common():
    setup_installs()
    change_shell()
    setup_user()
    setup_sudoers()
    setup_ulimit()
    setup_do_monitoring()
    setup_libxml()
    setup_psql_client()
    setup_repo()
    setup_local_files()
    setup_time_calibration()
    setup_pip()
    setup_virtualenv()
    setup_repo_local_settings()
    pip()
    setup_supervisor()
    setup_hosts()
    setup_pgbouncer()
    config_pgbouncer()
    setup_mongoengine_repo()
    # setup_forked_mongoengine()
    # setup_pymongo_repo()
    setup_logrotate()
    copy_certificates()
    setup_nginx()
    setup_munin()

def setup_all():
    setup_common()
    setup_app(skip_common=True)
    setup_db(skip_common=True)
    setup_task(skip_common=True)

def setup_app_docker(skip_common=False):
    if not skip_common:
        setup_common()
    setup_app_firewall()
    setup_motd('app')

    change_shell()
    setup_user()
    setup_sudoers()
    setup_ulimit()
    setup_do_monitoring()
    setup_repo()
    setup_local_files()
    # setup_time_calibration()

    setup_docker()

    done()
    sudo('reboot')

def setup_app(skip_common=False, node=False):
    if not skip_common:
        setup_common()
    setup_app_firewall()
    setup_motd('app')
    copy_app_settings()
    config_nginx()
    setup_gunicorn(supervisor=True)
    if node:
        setup_node()
    deploy_web()
    config_monit_app()
    setup_usage_monitor()
    done()
    sudo('reboot')

def setup_app_image():
    copy_app_settings()
    setup_hosts()
    config_pgbouncer()
    pull()
    pip()
    deploy_web()
    done()
    sudo('reboot')

def setup_node():
    setup_node_app()
    config_node(full=True)
    
def setup_db(engine=None, skip_common=False, skip_benchmark=False):
    if not skip_common:
        setup_common()
        setup_db_firewall()
    setup_motd('db')
    copy_db_settings()
    if engine == "postgres":
        setup_postgres(standby=False)
        setup_postgres_backups()
    elif engine == "postgres_slave":
        setup_postgres(standby=True)
    elif engine and engine.startswith("mongo"):
        setup_mongo()
        # setup_mongo_mms()
        setup_mongo_backups()
    elif engine == "redis":
        setup_redis()
        setup_redis_backups()
        setup_redis_monitor()
    elif engine == "redis_slave":
        setup_redis(slave=True)
        setup_redis_monitor()
    elif engine == "elasticsearch":
        setup_elasticsearch()
        setup_db_search()
    setup_gunicorn(supervisor=False)
    setup_db_munin()
    setup_db_monitor()
    setup_usage_monitor()
    if not skip_benchmark:
        benchmark()
    done()

    # if env.user == 'ubuntu':
    #     setup_db_mdadm()

def setup_task(queue=None, skip_common=False):
    if not skip_common:
        setup_common()
    setup_task_firewall()
    setup_motd('task')
    copy_task_settings()
    enable_celery_supervisor(queue)
    setup_gunicorn(supervisor=False)
    config_monit_task()
    setup_usage_monitor()
    done()
    sudo('reboot')

def setup_task_image():
    setup_installs()
    copy_task_settings()
    setup_hosts()
    config_pgbouncer()
    pull()
    pip()
    deploy(reload=True)
    done()
    sudo('reboot')

# ==================
# = Setup - Docker =
# ==================

def setup_docker():
    packages = [
        'build-essential',
    ]
    sudo('DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install %s' % ' '.join(packages))

    sudo('apt install -fy docker docker-compose')
    sudo('usermod -aG docker ${USER}')
    sudo('su - ${USER}')

    copy_certificates()
    
# ==================
# = Setup - Common =
# ==================

def done():
    print("\n\n\n\n-----------------------------------------------------")
    print("\n\n    %s / %s IS SUCCESSFULLY BOOTSTRAPPED" % (env.get('doname') or env.host_string, env.host_string))
    print("\n\n-----------------------------------------------------\n\n\n\n")

def setup_installs():
    packages = [
        'build-essential',
        'gcc',
        'scons',
        'libreadline-dev',
        'sysstat',
        'iotop',
        'git',
        'python2',
        'python2.7-dev',
        'locate',
        'software-properties-common',
        'libpcre3-dev',
        'libncurses5-dev',
        'libdbd-pg-perl',
        'libssl-dev',
        'libffi-dev',
        'libevent-dev',
        'make',
        'postgresql-common',
        'ssl-cert',
        'python-setuptools',
        'libyaml-0-2',
        'pgbouncer',
        'python-yaml',
        'python-numpy',
        'curl',
        'monit',
        'ufw',
        'libjpeg8',
        'libjpeg62-dev',
        'libfreetype6',
        'libfreetype6-dev',
        'libmysqlclient-dev',
        'libblas-dev',
        'liblapack-dev',
        'libatlas-base-dev',
        'gfortran',
        'libpq-dev',
    ]
    # sudo("sed -i -e 's/archive.ubuntu.com\|security.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list")
    put("config/apt_sources.conf", "/etc/apt/sources.list", use_sudo=True)
    run('sleep 10') # Dies on a lock, so just delay
    sudo('apt-get -y update')
    run('sleep 10') # Dies on a lock, so just delay
    sudo('DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade')
    run('sleep 10') # Dies on a lock, so just delay
    sudo('DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install %s' % ' '.join(packages))
    
    with settings(warn_only=True):
        sudo("ln -s /usr/lib/x86_64-linux-gnu/libjpeg.so /usr/lib")
        sudo("ln -s /usr/lib/x86_64-linux-gnu/libfreetype.so /usr/lib")
        sudo("ln -s /usr/lib/x86_64-linux-gnu/libz.so /usr/lib")
    
    with settings(warn_only=True):
        sudo('mkdir -p %s' % env.VENDOR_PATH)
        sudo('chown %s.%s %s' % (env.user, env.user, env.VENDOR_PATH))

def change_shell():
    sudo('apt-get -fy install zsh')
    with settings(warn_only=True):
        run('git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh')
        run('git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting')
    sudo('chsh %s -s /bin/zsh' % env.user)

def setup_user():
    # run('useradd -c "NewsBlur" -m newsblur -s /bin/zsh')
    # run('openssl rand -base64 8 | tee -a ~conesus/.password | passwd -stdin conesus')
    run('mkdir -p ~/.ssh && chmod 700 ~/.ssh')
    run('rm -fr ~/.ssh/id_dsa*')
    run('ssh-keygen -t dsa -f ~/.ssh/id_dsa -N ""')
    run('touch ~/.ssh/authorized_keys')
    put("~/.ssh/id_dsa.pub", "authorized_keys")
    run("echo \"\n\" >> ~sclay/.ssh/authorized_keys")
    run('echo `cat authorized_keys` >> ~sclay/.ssh/authorized_keys')
    run('rm authorized_keys')

def copy_ssh_keys(username='sclay', private=False):
    sudo('mkdir -p ~%s/.ssh' % username)
    
    put(os.path.join(env.SECRETS_PATH, 'keys/newsblur.key.pub'), 'local.key.pub')
    sudo('mv local.key.pub ~%s/.ssh/id_rsa.pub' % username)
    if private:
        put(os.path.join(env.SECRETS_PATH, 'keys/newsblur.key'), 'local.key')
        sudo('mv local.key ~%s/.ssh/id_rsa' % username)
    
    sudo("echo \"\n\" >> ~%s/.ssh/authorized_keys" % username)
    sudo("echo `cat ~%s/.ssh/id_rsa.pub` >> ~%s/.ssh/authorized_keys" % (username, username))
    sudo('chown -R %s.%s ~%s/.ssh' % (username, username, username))
    sudo('chmod 700 ~%s/.ssh' % username)
    sudo('chmod 600 ~%s/.ssh/id_rsa*' % username)

def setup_repo():
    sudo('mkdir -p /srv')
    sudo('chown -R %s.%s /srv' % (env.user, env.user))
    with settings(warn_only=True):
        run('git clone https://github.com/samuelclay/NewsBlur.git %s' % env.NEWSBLUR_PATH)
    with settings(warn_only=True):
        sudo('ln -sfn /srv/code /home/%s/code' % env.user)
        sudo('ln -sfn /srv/newsblur /home/%s/newsblur' % env.user)

def setup_repo_local_settings():
    with virtualenv():
        run('cp newsblur/local_settings.py.template newsblur/local_settings.py')
        run('mkdir -p logs')
        run('touch logs/newsblur.log')

def setup_local_files():
    run('mkdir -p ~/.config/procps')
    put("config/toprc", "~/.config/procps/toprc")
    run('rm -f ~/.toprc')
    put("config/zshrc", "~/.zshrc")
    put('config/gitconfig.txt', '~/.gitconfig')
    put('config/ssh.conf', '~/.ssh/config')

def setup_psql_client():
    sudo('apt-get -y install postgresql-client')
    sudo('mkdir -p /var/run/postgresql')
    with settings(warn_only=True):
        sudo('chown postgres.postgres /var/run/postgresql')

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

def setup_virtualenv():
    sudo('rm -fr ~/.cache') # Clean `sudo pip`
    sudo('pip install --upgrade virtualenv')
    sudo('pip install --upgrade virtualenvwrapper')
    setup_local_files()
    with prefix('WORKON_HOME=%s' % os.path.join(env.NEWSBLUR_PATH, 'venv')):
        with prefix('source /usr/local/bin/virtualenvwrapper.sh'):
            with cd(env.NEWSBLUR_PATH):
                # sudo('rmvirtualenv newsblur')
                # sudo('rm -fr venv')
                with settings(warn_only=True):
                    run('mkvirtualenv newsblur')
                # run('echo "import sys; sys.setdefaultencoding(\'utf-8\')" | sudo tee venv/newsblur/lib/python2.7/sitecustomize.py')
                # run('echo "/srv/newsblur" | sudo tee venv/newsblur/lib/python2.7/site-packages/newsblur.pth')
    
@_contextmanager
def virtualenv():
    with prefix('WORKON_HOME=%s' % os.path.join(env.NEWSBLUR_PATH, 'venv')):
        with prefix('source /usr/local/bin/virtualenvwrapper.sh'):
            with cd(env.NEWSBLUR_PATH):
                with prefix('workon newsblur'):
                    yield

def setup_pip():
    with cd(env.VENDOR_PATH), settings(warn_only=True):
        run('curl https://bootstrap.pypa.io/2.6/get-pip.py | sudo python2')
        # sudo('python2 get-pip.py')


@parallel
def pip():
    role = role_for_host()

    pull()
    with virtualenv():
        if role == "task":
            with settings(warn_only=True):
                sudo('fallocate -l 4G /swapfile')
                sudo('chmod 600 /swapfile')
                sudo('mkswap /swapfile')
                sudo('swapon /swapfile')
        sudo('chown %s.%s -R %s' % (env.user, env.user, os.path.join(env.NEWSBLUR_PATH, 'venv')))
        # run('easy_install -U pip')
        # run('pip install --upgrade pip')
        # run('pip install --upgrade setuptools')
        run('pip install -r requirements.txt')
        if role == "task":
            with settings(warn_only=True):
                sudo('swapoff /swapfile')

def solo_pip(role):
    if role == "app":
        gunicorn_stop()
        pip()
        deploy_code(reload=True)
    elif role == "task":
        celery_stop()
        copy_task_settings()
        pip()
        celery()
    
def setup_supervisor():
    sudo('apt-get update')
    sudo('apt-get -y install supervisor')
    put('config/supervisord.conf', '/etc/supervisor/supervisord.conf', use_sudo=True)
    sudo('/etc/init.d/supervisor stop')
    sudo('sleep 2')
    sudo('ulimit -n 100000 && /etc/init.d/supervisor start')
    sudo("/usr/sbin/update-rc.d -f supervisor defaults")
    sudo('systemctl enable supervisor')
    sudo('systemctl start supervisor')

@parallel
def setup_hosts():
    put(os.path.join(env.SECRETS_PATH, 'configs/hosts'), '/etc/hosts', use_sudo=True)
    sudo('echo "\n\n127.0.0.1   `hostname`" | sudo tee -a /etc/hosts')

def setup_pgbouncer():
    sudo('apt-get remove -y pgbouncer')
    sudo('apt-get install -y libevent-dev pkg-config libc-ares2 libc-ares-dev')
    PGBOUNCER_VERSION = '1.15.0'
    with cd(env.VENDOR_PATH), settings(warn_only=True):
        run('wget https://pgbouncer.github.io/downloads/files/%s/pgbouncer-%s.tar.gz' % (PGBOUNCER_VERSION, PGBOUNCER_VERSION))
        run('tar -xzf pgbouncer-%s.tar.gz' % PGBOUNCER_VERSION)
        run('rm pgbouncer-%s.tar.gz' % PGBOUNCER_VERSION)
        with cd('pgbouncer-%s' % PGBOUNCER_VERSION):
            run('./configure --prefix=/usr/local')
            run('make')
            sudo('make install')
            sudo('ln -s /usr/local/bin/pgbouncer /usr/sbin/pgbouncer')
    config_pgbouncer()
    
def config_pgbouncer():
    sudo('mkdir -p /etc/pgbouncer')
    put('config/pgbouncer.conf', 'pgbouncer.conf')
    sudo('mv pgbouncer.conf /etc/pgbouncer/pgbouncer.ini')
    put(os.path.join(env.SECRETS_PATH, 'configs/pgbouncer_auth.conf'), 'userlist.txt')
    sudo('mv userlist.txt /etc/pgbouncer/userlist.txt')
    sudo('echo "START=1" | sudo tee /etc/default/pgbouncer')
    # sudo('su postgres -c "/etc/init.d/pgbouncer stop"', pty=False)
    with settings(warn_only=True):
        sudo('/etc/init.d/pgbouncer stop')
        sudo('pkill -9 pgbouncer -e')
        run('sleep 2')
    sudo('/etc/init.d/pgbouncer start', pty=False)

@parallel
def kill_pgbouncer(stop=False):
    # sudo('su postgres -c "/etc/init.d/pgbouncer stop"', pty=False)
    with settings(warn_only=True):
        sudo('/etc/init.d/pgbouncer stop')
    run('sleep 2')
    sudo('rm /var/log/postgresql/pgbouncer.pid')
    with settings(warn_only=True):
        sudo('pkill -9 pgbouncer')
        run('sleep 2')
    if not stop:
        run('sudo /etc/init.d/pgbouncer start', pty=False)

def config_monit_task():
    put('config/monit_task.conf', '/etc/monit/conf.d/celery.conf', use_sudo=True)
    sudo('echo "START=yes" | sudo tee /etc/default/monit')
    sudo('/etc/init.d/monit restart')

def config_monit_node():
    put('config/monit_node.conf', '/etc/monit/conf.d/node.conf', use_sudo=True)
    sudo('echo "START=yes" | sudo tee /etc/default/monit')
    sudo('/etc/init.d/monit restart')

def config_monit_original():
    put('config/monit_original.conf', '/etc/monit/conf.d/node_original.conf', use_sudo=True)
    sudo('echo "START=yes" | sudo tee /etc/default/monit')
    sudo('/etc/init.d/monit restart')

def config_monit_app():
    put('config/monit_app.conf', '/etc/monit/conf.d/gunicorn.conf', use_sudo=True)
    sudo('echo "START=yes" | sudo tee /etc/default/monit')
    sudo('/etc/init.d/monit restart')

def config_monit_work():
    put('config/monit_work.conf', '/etc/monit/conf.d/work.conf', use_sudo=True)
    sudo('echo "START=yes" | sudo tee /etc/default/monit')
    sudo('/etc/init.d/monit restart')

def config_monit_redis():
    sudo('chown root.root /etc/init.d/redis')
    sudo('chmod a+x /etc/init.d/redis')
    put('config/monit_debug.sh', '/etc/monit/monit_debug.sh', use_sudo=True)
    sudo('chmod a+x /etc/monit/monit_debug.sh')
    put('config/monit_redis.conf', '/etc/monit/conf.d/redis.conf', use_sudo=True)
    sudo('echo "START=yes" | sudo tee /etc/default/monit')
    sudo('/etc/init.d/monit restart')

def setup_mongoengine_repo():
    with cd(env.VENDOR_PATH), settings(warn_only=True):
        run('rm -fr mongoengine')
        run('git clone https://github.com/MongoEngine/mongoengine.git')
        sudo('rm -fr /usr/local/lib/python2.7/dist-packages/mongoengine')
        sudo('rm -fr /usr/local/lib/python2.7/dist-packages/mongoengine-*')
        sudo('ln -sfn %s /usr/local/lib/python2.7/dist-packages/mongoengine' %
             os.path.join(env.VENDOR_PATH, 'mongoengine/mongoengine'))
    with cd(os.path.join(env.VENDOR_PATH, 'mongoengine')), settings(warn_only=True):
        run('git co v0.8.2')

def clear_pymongo_repo():
    sudo('rm -fr /usr/local/lib/python2.7/dist-packages/pymongo*')
    sudo('rm -fr /usr/local/lib/python2.7/dist-packages/bson*')
    sudo('rm -fr /usr/local/lib/python2.7/dist-packages/gridfs*')
    
def setup_pymongo_repo():
    with cd(env.VENDOR_PATH), settings(warn_only=True):
        run('git clone git://github.com/mongodb/mongo-python-driver.git pymongo')
    # with cd(os.path.join(env.VENDOR_PATH, 'pymongo')):
    #     sudo('python setup.py install')
    clear_pymongo_repo()
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

def setup_logrotate(clear=True):
    if clear:
        run('find /srv/newsblur/logs/*.log | xargs tee')
        with settings(warn_only=True):
            sudo('find /var/log/mongodb/*.log | xargs tee')
    put('config/logrotate.conf', '/etc/logrotate.d/newsblur', use_sudo=True)
    put('config/logrotate.mongo.conf', '/etc/logrotate.d/mongodb', use_sudo=True)
    put('config/logrotate.nginx.conf', '/etc/logrotate.d/nginx', use_sudo=True)
    sudo('chown root.root /etc/logrotate.d/{newsblur,mongodb,nginx}')
    sudo('chmod 644 /etc/logrotate.d/{newsblur,mongodb,nginx}')
    with settings(warn_only=True):
        sudo('chown sclay.sclay /srv/newsblur/logs/*.log')
    sudo('logrotate -f /etc/logrotate.d/newsblur')
    sudo('logrotate -f /etc/logrotate.d/nginx')
    sudo('logrotate -f /etc/logrotate.d/mongodb')

def setup_ulimit():
    # Increase File Descriptor limits.
    run('export FILEMAX=`sysctl -n fs.file-max`', pty=False)
    sudo('mv /etc/security/limits.conf /etc/security/limits.conf.bak', pty=False)
    sudo('touch /etc/security/limits.conf', pty=False)
    run('echo "root soft nofile 100000\n" | sudo tee -a /etc/security/limits.conf', pty=False)
    run('echo "root hard nofile 100000\n" | sudo tee -a /etc/security/limits.conf', pty=False)
    run('echo "* soft nofile 100000\n" | sudo tee -a /etc/security/limits.conf', pty=False)
    run('echo "* hard nofile 100090\n" | sudo tee -a /etc/security/limits.conf', pty=False)
    run('echo "fs.file-max = 100000\n" | sudo tee -a /etc/sysctl.conf', pty=False)
    sudo('sysctl -p')
    sudo('ulimit -n 100000')
    connections.connect(env.host_string)
    
    # run('touch /home/ubuntu/.bash_profile')
    # run('echo "ulimit -n $FILEMAX" >> /home/ubuntu/.bash_profile')

    # Increase Ephemeral Ports.
    # sudo chmod 666 /etc/sysctl.conf
    # echo "net.ipv4.ip_local_port_range = 1024 65535" >> /etc/sysctl.conf
    # sudo chmod 644 /etc/sysctl.conf

def setup_do_monitoring():
    run('curl -sSL https://agent.digitalocean.com/install.sh | sh')
    
def setup_syncookies():
    sudo('echo 1 | sudo tee /proc/sys/net/ipv4/tcp_syncookies')
    sudo('sudo /sbin/sysctl -w net.ipv4.tcp_syncookies=1')

def setup_sudoers(user=None):
    sudo('echo "%s ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/sclay' % (user or env.user))
    sudo('chmod 0440 /etc/sudoers.d/sclay')

def setup_nginx():
    NGINX_VERSION = '1.19.5'
    with cd(env.VENDOR_PATH), settings(warn_only=True):
        sudo("groupadd nginx")
        sudo("useradd -g nginx -d /var/www/htdocs -s /bin/false nginx")
        run('wget http://nginx.org/download/nginx-%s.tar.gz' % NGINX_VERSION)
        run('tar -xzf nginx-%s.tar.gz' % NGINX_VERSION)
        run('rm nginx-%s.tar.gz' % NGINX_VERSION)
        with cd('nginx-%s' % NGINX_VERSION):
            run('./configure --with-http_ssl_module --with-http_stub_status_module --with-http_gzip_static_module --with-http_realip_module ')
            run('make')
            sudo('make install')
    config_nginx()

def config_nginx():
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

def remove_gunicorn():
    with cd(env.VENDOR_PATH):
        sudo('rm -fr gunicorn')
    
def setup_gunicorn(supervisor=True, restart=True):
    if supervisor:
        put('config/supervisor_gunicorn.conf', '/etc/supervisor/conf.d/gunicorn.conf', use_sudo=True)
        sudo('supervisorctl reread')
        if restart:
            sudo('supervisorctl update')
    # with cd(env.VENDOR_PATH):
    #     sudo('rm -fr gunicorn')
    #     run('git clone git://github.com/benoitc/gunicorn.git')
    # with cd(os.path.join(env.VENDOR_PATH, 'gunicorn')):
    #     run('git pull')
    #     sudo('python setup.py develop')


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

def setup_node_app():
    sudo('curl -sL https://deb.nodesource.com/setup_14.x | sudo bash -')
    sudo('apt-get install -y nodejs')
    # run('curl -L https://npmjs.org/install.sh | sudo sh')
    # sudo('apt-get install npm')
    sudo('sudo npm install -g npm')
    sudo('npm install -g supervisor')
    sudo('ufw allow 8888')
    sudo('ufw allow 4040')

def config_node(full=False):
    sudo('rm -f /etc/supervisor/conf.d/gunicorn.conf')
    sudo('rm -f /etc/supervisor/conf.d/node.conf')
    put('config/supervisor_node_unread.conf', '/etc/supervisor/conf.d/node_unread.conf', use_sudo=True)
    put('config/supervisor_node_unread_ssl.conf', '/etc/supervisor/conf.d/node_unread_ssl.conf', use_sudo=True)
    put('config/supervisor_node_favicons.conf', '/etc/supervisor/conf.d/node_favicons.conf', use_sudo=True)
    put('config/supervisor_node_text.conf', '/etc/supervisor/conf.d/node_text.conf', use_sudo=True)
    
    if full:
        run("rm -fr /srv/newsblur/node/node_modules")
        with cd(os.path.join(env.NEWSBLUR_PATH, "node")):
            run("npm install")
    
    sudo('supervisorctl reload')

@parallel
def copy_app_settings():
    run('rm -f %s/local_settings.py' % env.NEWSBLUR_PATH)
    put(os.path.join(env.SECRETS_PATH, 'settings/app_settings.py'), 
        '%s/newsblur/local_settings.py' % env.NEWSBLUR_PATH)
    run('echo "\nSERVER_NAME = \\\\"`hostname`\\\\"" >> %s/newsblur/local_settings.py' % env.NEWSBLUR_PATH)

def assemble_certificates():
    with lcd(os.path.join(env.SECRETS_PATH, 'certificates/comodo')):
        local('pwd')
        local('cat STAR_newsblur_com.crt EssentialSSLCA_2.crt ComodoUTNSGCCA.crt UTNAddTrustSGCCA.crt AddTrustExternalCARoot.crt > newsblur.com.crt')
        
def copy_certificates(copy=False):
    cert_path = os.path.join(env.NEWSBLUR_PATH, 'config/certificates')
    run('mkdir -p %s' % cert_path)
    fullchain_path = "/etc/letsencrypt/live/newsblur.com/fullchain.pem"
    privkey_path = "/etc/letsencrypt/live/newsblur.com/privkey.pem"

    if copy:
        sudo('mkdir -p %s' % os.path.dirname(fullchain_path))
        put(os.path.join(env.SECRETS_PATH, 'certificates/newsblur.com.pem'), fullchain_path, use_sudo=True)
        put(os.path.join(env.SECRETS_PATH, 'certificates/newsblur.com.key'), privkey_path, use_sudo=True)

    run('ln -fs %s %s' % (fullchain_path, os.path.join(cert_path, 'newsblur.com.crt')))
    run('ln -fs %s %s' % (fullchain_path, os.path.join(cert_path, 'newsblur.com.pem'))) # For backwards compatibility with hard-coded nginx configs
    run('ln -fs %s %s' % (privkey_path, os.path.join(cert_path, 'newsblur.com.key')))
    run('ln -fs %s %s' % (privkey_path, os.path.join(cert_path, 'newsblur.com.crt.key'))) # HAProxy
    put(os.path.join(env.SECRETS_PATH, 'certificates/comodo/dhparams.pem'), cert_path)
    put(os.path.join(env.SECRETS_PATH, 'certificates/ios/aps_development.pem'), cert_path)

    # Export aps.cer from Apple issued certificate using Keychain Assistant
    # openssl x509 -in aps.cer -inform DER -outform PEM -out aps.pem
    put(os.path.join(env.SECRETS_PATH, 'certificates/ios/aps.pem'), cert_path)
    # Export aps.p12 from aps.cer using Keychain Assistant
    # openssl pkcs12 -in aps.p12 -out aps.p12.pem -nodes
    put(os.path.join(env.SECRETS_PATH, 'certificates/ios/aps.p12.pem'), cert_path)
    
def setup_certbot():
    sudo('snap install --classic certbot')
    sudo('snap set certbot trust-plugin-with-root=ok')
    sudo('snap install certbot-dns-dnsimple')
    sudo('ln -fs /snap/bin/certbot /usr/bin/certbot')
    put(os.path.join(env.SECRETS_PATH, 'configs/certbot.conf'), 
        os.path.join(env.NEWSBLUR_PATH, 'certbot.conf'))
    sudo('chmod 0600 %s' % os.path.join(env.NEWSBLUR_PATH, 'certbot.conf'))
    sudo('certbot certonly -n --agree-tos '
         ' --dns-dnsimple --dns-dnsimple-credentials %s'
         ' --email samuel@newsblur.com --domains newsblur.com '
         ' -d "*.newsblur.com" -d "popular.global.newsblur.com"' % 
         (os.path.join(env.NEWSBLUR_PATH, 'certbot.conf')))
    sudo('chmod 0755 /etc/letsencrypt/{live,archive}')
    sudo('chmod 0755 /etc/letsencrypt/archive/newsblur.com/privkey1.pem')
    
# def setup_certbot_old():
#     sudo('add-apt-repository -y universe')
#     sudo('add-apt-repository -y ppa:certbot/certbot')
#     sudo('apt-get update')
#     sudo('apt-get install -y certbot')
#     sudo('apt-get install -y python3-certbot-dns-dnsimple')
#     put(os.path.join(env.SECRETS_PATH, 'configs/certbot.conf'), 
#         os.path.join(env.NEWSBLUR_PATH, 'certbot.conf'))
#     sudo('chmod 0600 %s' % os.path.join(env.NEWSBLUR_PATH, 'certbot.conf'))
#     sudo('certbot certonly -n --agree-tos '
#          ' --dns-dnsimple --dns-dnsimple-credentials %s'
#          ' --email samuel@newsblur.com --domains newsblur.com '
#          ' -d "*.newsblur.com" -d "global.popular.newsblur.com"' % 
#          (os.path.join(env.NEWSBLUR_PATH, 'certbot.conf')))
#     sudo('chmod 0755 /etc/letsencrypt/{live,archive}')
#     sudo('chmod 0755 /etc/letsencrypt/archive/newsblur.com/privkey1.pem')
    
@parallel
def maintenance_on():
    role = role_for_host()
    if role in ['work', 'search']:
        sudo('supervisorctl stop all')
    else:
        put('templates/maintenance_off.html', '%s/templates/maintenance_off.html' % env.NEWSBLUR_PATH)
        with virtualenv():
            run('mv templates/maintenance_off.html templates/maintenance_on.html')

@parallel
def maintenance_off():
    role = role_for_host()
    if role in ['work', 'search']:
        sudo('supervisorctl start all')
    else:
        with virtualenv():
            run('mv templates/maintenance_on.html templates/maintenance_off.html')
            run('git checkout templates/maintenance_off.html')

def setup_haproxy(debug=False):
    version = "2.3.3"
    sudo('ufw allow 81')    # nginx moved
    sudo('ufw allow 1936')  # haproxy stats
    # sudo('apt-get install -y haproxy')
    # sudo('apt-get remove -y haproxy')
    with cd(env.VENDOR_PATH):
        run('wget http://www.haproxy.org/download/2.3/src/haproxy-%s.tar.gz' % version)
        run('tar -xf haproxy-%s.tar.gz' % version)
        with cd('haproxy-%s' % version):
            run('make TARGET=linux-glibc USE_PCRE=1 USE_OPENSSL=1 USE_ZLIB=1')
            sudo('make install')
    put('config/haproxy-init', '/etc/init.d/haproxy', use_sudo=True)
    sudo('chmod u+x /etc/init.d/haproxy')
    sudo('mkdir -p /etc/haproxy')
    if debug:
        put('config/debug_haproxy.conf', '/etc/haproxy/haproxy.cfg', use_sudo=True)
    else:
        build_haproxy()
        put(os.path.join(env.SECRETS_PATH, 'configs/haproxy.conf'), 
            '/etc/haproxy/haproxy.cfg', use_sudo=True)
    sudo('echo "ENABLED=1" | sudo tee /etc/default/haproxy')
    cert_path = "%s/config/certificates" % env.NEWSBLUR_PATH
    run('cat %s/newsblur.com.crt > %s/newsblur.pem' % (cert_path, cert_path))
    run('cat %s/newsblur.com.key >> %s/newsblur.pem' % (cert_path, cert_path))
    run('ln -s %s/newsblur.com.key %s/newsblur.pem.key' % (cert_path, cert_path))
    put('config/haproxy_rsyslog.conf', '/etc/rsyslog.d/49-haproxy.conf', use_sudo=True)
    # sudo('restart rsyslog')
    sudo('update-rc.d -f haproxy defaults')

    sudo('/etc/init.d/haproxy stop')
    run('sleep 5')
    sudo('/etc/init.d/haproxy start')

def config_haproxy(debug=False):
    if debug:
        put('config/debug_haproxy.conf', '/etc/haproxy/haproxy.cfg', use_sudo=True)
    else:
        build_haproxy()
        put(os.path.join(env.SECRETS_PATH, 'configs/haproxy.conf'), 
            '/etc/haproxy/haproxy.cfg', use_sudo=True)

    haproxy_check = run('haproxy -c -f /etc/haproxy/haproxy.cfg')
    if haproxy_check.return_code == 0:
        sudo('/etc/init.d/haproxy reload')
    else:
        print(" !!!> Uh-oh, HAProxy config doesn't check out: %s" % haproxy_check.return_code)

def build_haproxy():
    droplets = assign_digitalocean_roledefs(split=True)
    servers = defaultdict(list)
    gunicorn_counts_servers = ['app22', 'app26']
    gunicorn_refresh_servers = ['app20', 'app21']
    maintenance_servers = ['app20']
    node_socket3_servers = ['node02', 'node03']
    ignore_servers = []
    
    for group_type in ['app', 'push', 'work', 'node_socket', 'node_socket3', 'node_favicon', 'node_text', 'www']:
        group_type_name = group_type
        if 'node' in group_type:
            group_type_name = 'node'
        for server in droplets[group_type_name]:
            droplet_nums = re.findall(r'\d+', server['name'])
            droplet_num = droplet_nums[0] if droplet_nums else ''
            server_type = group_type
            port = 80
            check_inter = 3000
            
            if server['name'] in ignore_servers:
                print(" ---> Ignoring %s" % server['name'])
                continue
            if server['name'] in node_socket3_servers and group_type != 'node_socket3':
                continue
            if server['name'] not in node_socket3_servers and group_type == 'node_socket3':
                continue
            if server_type == 'www':
                port = 81
            if group_type == 'node_socket':
                port = 8888
            if group_type == 'node_socket3':
                port = 8888
            if group_type == 'node_text':
                port = 4040
            if group_type in ['app', 'push']:
                port = 8000
            address = "%s:%s" % (server['address'], port)

            if server_type == 'app':
                nginx_address = "%s:80" % (server['address'])
                servers['nginx'].append("  server nginx%-15s %-22s check inter 3000ms" % (droplet_num, nginx_address))
            if server['name'] in maintenance_servers:
                nginx_address = "%s:80" % (server['address'])
                servers['maintenance'].append("  server nginx%-15s %-22s check inter 3000ms" % (droplet_num, nginx_address))
            
            if server['name'] in gunicorn_counts_servers:
                server_type = 'gunicorn_counts'
                check_inter = 15000
            elif server['name'] in gunicorn_refresh_servers:
                server_type = 'gunicorn_refresh'
                check_inter = 30000
            
            server_name = "%s%s" % (server_type, droplet_num)
            servers[server_type].append("  server %-20s %-22s check inter %sms" % (server_name, address, check_inter))
    
    h = open(os.path.join(env.NEWSBLUR_PATH, 'config/haproxy.conf.template'), 'r')
    haproxy_template = h.read()
    for sub, server_list in list(servers.items()):
        sorted_servers = '\n'.join(sorted(server_list))
        haproxy_template = haproxy_template.replace("{{ %s }}" % sub, sorted_servers)
    f = open(os.path.join(env.SECRETS_PATH, 'configs/haproxy.conf'), 'w')
    f.write(haproxy_template)
    f.close()

def upgrade_django(role=None):
    if not role:
        role = role_for_host()

    with virtualenv(), settings(warn_only=True):
        sudo('sudo dpkg --configure -a')
        setup_supervisor()
        pull()
        run('git co django1.11')
        if role == "task":
            sudo('supervisorctl stop celery')
            run('./utils/kill_celery.sh')
            copy_task_settings()
            enable_celery_supervisor(update=False)
        elif role == "work":
            copy_app_settings()
            enable_celerybeat()
        elif role == "web" or role == "app":
            sudo('supervisorctl stop gunicorn')
            run('./utils/kill_gunicorn.sh')
            copy_app_settings()
            setup_gunicorn(restart=False)
        elif role == "node":
            copy_app_settings()
            config_node(full=True)
        else:
            copy_task_settings()

        pip()
        clean()

        # sudo('reboot')

def clean():
    with virtualenv(), settings(warn_only=True):
        run('find . -name "*.pyc" -exec rm -f {} \;')
    
def downgrade_django(role=None):
    with virtualenv(), settings(warn_only=True):
        pull()
        run('git co master')
        pip()
        run('pip uninstall -y django-paypal')
        if role == "task":
            copy_task_settings()
            enable_celery_supervisor()
        else:
            copy_app_settings()
            deploy()
        
def vendorize_paypal():
    with virtualenv(), settings(warn_only=True):
        run('pip uninstall -y django-paypal')

def upgrade_pil():
    with virtualenv():
        pull()
        run('pip install --upgrade pillow')
        # celery_stop()
        sudo('apt-get remove -y python-imaging')
        sudo('supervisorctl reload')
        # kill()

def downgrade_pil():
    with virtualenv():
        sudo('apt-get install -y python-imaging')
        sudo('rm -fr /usr/local/lib/python2.7/dist-packages/Pillow*')
        pull()
        sudo('supervisorctl reload')
        # kill()

def setup_db_monitor():
    pull()
    with virtualenv():
        sudo('apt-get install -y libpq-dev python2.7-dev')
        run('pip install -r flask/requirements.txt')
        put('flask/supervisor_db_monitor.conf', '/etc/supervisor/conf.d/db_monitor.conf', use_sudo=True)
        sudo('supervisorctl reread')
        sudo('supervisorctl update')
        
# ==============
# = Setup - DB =
# ==============

@parallel
def setup_db_firewall():
    ports = [
        5432,   # PostgreSQL
        27017,  # MongoDB
        28017,  # MongoDB web
        27019,  # MongoDB config
        6379,   # Redis
        # 11211,  # Memcached
        3060,   # Node original page server
        9200,   # Elasticsearch
        5000,   # DB Monitor
    ]
    sudo('ufw --force reset')
    sudo('ufw default deny')
    sudo('ufw allow ssh')
    sudo('ufw allow 80')
    sudo('ufw allow 443')

    # DigitalOcean
    for ip in set(env.roledefs['app'] +
                  env.roledefs['db'] +
                  env.roledefs['debug'] +
                  env.roledefs['task'] +
                  env.roledefs['work'] +
                  env.roledefs['push'] +
                  env.roledefs['www'] +
                  env.roledefs['search'] +
                  env.roledefs['node']):
        sudo('ufw allow proto tcp from %s to any port %s' % (
            ip,
            ','.join(map(str, ports))
        ))

    # EC2
    # for host in set(env.roledefs['ec2task']):
    #     ip = re.search('ec2-(\d+-\d+-\d+-\d+)', host).group(1).replace('-', '.')
    #     sudo('ufw allow proto tcp from %s to any port %s' % (
    #         ip,
    #         ','.join(map(str, ports))
    #     ))

    sudo('ufw --force enable')

def setup_rabbitmq():
    sudo('echo "deb http://www.rabbitmq.com/debian/ testing main" | sudo tee -a /etc/apt/sources.list')
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
    shmmax = 17818362112
    hugepages = 9000
    sudo('echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" |sudo tee  /etc/apt/sources.list.d/pgdg.list')
    sudo('wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -')
    sudo('apt update')
    sudo('apt install -y postgresql-13')
    put('config/postgresql-13.conf', '/etc/postgresql/13/main/postgresql.conf', use_sudo=True)
    put('config/postgres_hba-13.conf', '/etc/postgresql/13/main/pg_hba.conf', use_sudo=True)
    sudo('mkdir -p /var/lib/postgresql/13/archive')
    sudo('chown -R postgres.postgres /etc/postgresql/13/main')
    sudo('chown -R postgres.postgres /var/lib/postgresql/13/main')
    sudo('chown -R postgres.postgres /var/lib/postgresql/13/archive')
    sudo('echo "%s" | sudo tee /proc/sys/kernel/shmmax' % shmmax)
    sudo('echo "\nkernel.shmmax = %s" | sudo tee -a /etc/sysctl.conf' % shmmax)
    sudo('echo "\nvm.nr_hugepages = %s\n" | sudo tee -a /etc/sysctl.conf' % hugepages)
    run('echo "ulimit -n 100000" > postgresql.defaults')
    sudo('mv postgresql.defaults /etc/default/postgresql')
    sudo('sysctl -p')
    sudo('rm -f /lib/systemd/system/postgresql.service') # Ubuntu 16 has wrong default
    sudo('systemctl daemon-reload')
    sudo('systemctl enable postgresql')

    if standby:
        put('config/postgresql_recovery.conf', '/var/lib/postgresql/13/recovery.conf', use_sudo=True)
        sudo('chown -R postgres.postgres /var/lib/postgresql/13/recovery.conf')

    sudo('/etc/init.d/postgresql stop')
    sudo('/etc/init.d/postgresql start')

def config_postgres(standby=False):
    put('config/postgresql-13.conf', '/etc/postgresql/13/main/postgresql.conf', use_sudo=True)
    put('config/postgres_hba.conf', '/etc/postgresql/13/main/pg_hba.conf', use_sudo=True)
    sudo('chown postgres.postgres /etc/postgresql/13/main/postgresql.conf')
    run('echo "ulimit -n 100000" > postgresql.defaults')
    sudo('mv postgresql.defaults /etc/default/postgresql')
    
    sudo('/etc/init.d/postgresql reload 13')

def upgrade_postgres():
    sudo('su postgres -c "/usr/lib/postgresql/10/bin/pg_upgrade -b /usr/lib/postgresql/9.4/bin -B /usr/lib/postgresql/10/bin -d /var/lib/postgresql/9.4/main -D /var/lib/postgresql/10/main"')
    
def copy_postgres_to_standby(master='db01'):
    # http://www.rassoc.com/gregr/weblog/2013/02/16/zero-to-postgresql-streaming-replication-in-10-mins/
    
    # Make sure you can ssh from master to slave and back with the postgres user account.
    # Need to give postgres accounts keys in authroized_keys.

    # local: fab host:new copy_ssh_keys:postgres,private=True
    # new: sudo su postgres; ssh old
    # new: sudo su postgres; ssh db_pgsql
    # old: sudo su postgres; ssh new
    # old: sudo su postgres -c "psql -c \"SELECT pg_start_backup('label', true)\""
    sudo('systemctl stop postgresql')
    sudo('mkdir -p /var/lib/postgresql/9.4/archive')
    sudo('chown postgres.postgres /var/lib/postgresql/9.4/archive')
    with settings(warn_only=True):
        sudo('su postgres -c "rsync -Pav -e \'ssh -i ~postgres/.ssh/newsblur.key\' --stats --progress postgres@%s:/var/lib/postgresql/9.4/main /var/lib/postgresql/9.4/ --exclude postmaster.pid"' % master)
    put('config/postgresql_recovery.conf', '/var/lib/postgresql/9.4/main/recovery.conf', use_sudo=True)
    sudo('systemctl start postgresql')
    # old: sudo su postgres -c "psql -c \"SELECT pg_stop_backup()\""
    
    # Don't forget to add 'setup_postgres_backups' to new
    

def disable_thp():
    put('config/disable_transparent_hugepages.sh', '/etc/init.d/disable-transparent-hugepages', use_sudo=True)
    sudo('chmod 755 /etc/init.d/disable-transparent-hugepages')
    sudo('update-rc.d disable-transparent-hugepages defaults')
    
def setup_mongo():
    MONGODB_VERSION = "3.4.24"
    pull()
    disable_thp()
    sudo('systemctl enable rc-local.service') # Enable rc.local
    sudo('echo "#!/bin/sh -e\n\nif test -f /sys/kernel/mm/transparent_hugepage/enabled; then\n\
       echo never > /sys/kernel/mm/transparent_hugepage/enabled\n\
    fi\n\
    if test -f /sys/kernel/mm/transparent_hugepage/defrag; then\n\
       echo never > /sys/kernel/mm/transparent_hugepage/defrag\n\
    fi\n\n\
    exit 0" | sudo tee /etc/rc.local')
    sudo('curl -fsSL https://www.mongodb.org/static/pgp/server-3.4.asc | sudo apt-key add -')
    # sudo('echo "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen" | sudo tee /etc/apt/sources.list.d/mongodb.list')
    # sudo('echo "\ndeb http://downloads-distro.mongodb.org/repo/debian-sysvinit dist 10gen" | sudo tee -a /etc/apt/sources.list')
    # sudo('echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list')
    sudo('echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list')
    sudo('apt-get update')
    sudo('apt-get install -y mongodb-org=%s mongodb-org-server=%s mongodb-org-shell=%s mongodb-org-mongos=%s mongodb-org-tools=%s' %
         (MONGODB_VERSION, MONGODB_VERSION, MONGODB_VERSION, MONGODB_VERSION, MONGODB_VERSION))
    put('config/mongodb.%s.conf' % ('prod' if env.user != 'ubuntu' else 'ec2'),
        '/etc/mongodb.conf', use_sudo=True)
    put('config/mongodb.service', '/etc/systemd/system/mongodb.service', use_sudo=True)
    run('echo "ulimit -n 100000" > mongodb.defaults')
    sudo('mv mongodb.defaults /etc/default/mongod')
    sudo('mkdir -p /var/log/mongodb')
    sudo('chown mongodb /var/log/mongodb')
    put('config/logrotate.mongo.conf', '/etc/logrotate.d/mongod', use_sudo=True)
    sudo('systemctl enable mongodb')
    
    # Reclaim 5% disk space used for root logs. Set to 1%.
    with settings(warn_only=True):
        sudo('tune2fs -m 1 /dev/vda1')

def setup_mongo_configsvr():
    sudo('mkdir -p /var/lib/mongodb_configsvr')
    sudo('chown mongodb.mongodb /var/lib/mongodb_configsvr')
    put('config/mongodb.configsvr.conf', '/etc/mongodb.configsvr.conf', use_sudo=True)
    put('config/mongodb.configsvr-init', '/etc/init.d/mongodb-configsvr', use_sudo=True)
    sudo('chmod u+x /etc/init.d/mongodb-configsvr')
    run('echo "ulimit -n 100000" > mongodb_configsvr.defaults')
    sudo('mv mongodb_configsvr.defaults /etc/default/mongodb_configsvr')
    sudo('update-rc.d -f mongodb-configsvr defaults')
    sudo('/etc/init.d/mongodb-configsvr start')

def setup_mongo_mongos():
    put('config/mongodb.mongos.conf', '/etc/mongodb.mongos.conf', use_sudo=True)
    put('config/mongodb.mongos-init', '/etc/init.d/mongodb-mongos', use_sudo=True)
    sudo('chmod u+x /etc/init.d/mongodb-mongos')
    run('echo "ulimit -n 100000" > mongodb_mongos.defaults')
    sudo('mv mongodb_mongos.defaults /etc/default/mongodb_mongos')
    sudo('update-rc.d -f mongodb-mongos defaults')
    sudo('/etc/init.d/mongodb-mongos restart')

def setup_mongo_mms():
    pull()
    sudo('rm -f /etc/supervisor/conf.d/mongomms.conf')
    sudo('supervisorctl reread')
    sudo('supervisorctl update')
    with cd(env.VENDOR_PATH):
        sudo('apt-get remove -y mongodb-mms-monitoring-agent')
        run('curl -OL https://mms.mongodb.com/download/agent/monitoring/mongodb-mms-monitoring-agent_2.2.0.70-1_amd64.deb')
        sudo('dpkg -i mongodb-mms-monitoring-agent_2.2.0.70-1_amd64.deb')
        run('rm mongodb-mms-monitoring-agent_2.2.0.70-1_amd64.deb')
        put(os.path.join(env.SECRETS_PATH, 'settings/mongo_mms_config.txt'),
            'mongo_mms_config.txt')
        sudo("echo \"\n\" | sudo tee -a /etc/mongodb-mms/monitoring-agent.config")
        sudo('cat mongo_mms_config.txt | sudo tee -a /etc/mongodb-mms/monitoring-agent.config')
        sudo('start mongodb-mms-monitoring-agent')

def setup_redis(slave=False):
    redis_version = '3.2.6'
    with cd(env.VENDOR_PATH):
        run('wget http://download.redis.io/releases/redis-%s.tar.gz' % redis_version)
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
    # sudo('chmod 666 /proc/sys/vm/overcommit_memory', pty=False)
    # run('echo "1" > /proc/sys/vm/overcommit_memory', pty=False)
    # sudo('chmod 644 /proc/sys/vm/overcommit_memory', pty=False)
    disable_thp()
    sudo('systemctl enable rc-local.service') # Enable rc.local
    sudo('echo "#!/bin/sh -e\n\nif test -f /sys/kernel/mm/transparent_hugepage/enabled; then\n\
       echo never > /sys/kernel/mm/transparent_hugepage/enabled\n\
    fi\n\
    if test -f /sys/kernel/mm/transparent_hugepage/defrag; then\n\
       echo never > /sys/kernel/mm/transparent_hugepage/defrag\n\
    fi\n\n\
    exit 0" | sudo tee /etc/rc.local')
    sudo("echo 1 | sudo tee /proc/sys/vm/overcommit_memory")
    sudo('echo "vm.overcommit_memory = 1" | sudo tee -a /etc/sysctl.conf')
    sudo("sysctl vm.overcommit_memory=1")
    put('config/redis_rclocal.txt', '/etc/rc.local', use_sudo=True)
    sudo("chown root.root /etc/rc.local")
    sudo("chmod a+x /etc/rc.local")
    sudo('echo "never" | sudo tee /sys/kernel/mm/transparent_hugepage/enabled')
    run('echo "\nnet.core.somaxconn=65535\n" | sudo tee -a /etc/sysctl.conf', pty=False)
    sudo('mkdir -p /var/lib/redis')
    sudo('update-rc.d redis defaults')
    sudo('/etc/init.d/redis stop')
    sudo('/etc/init.d/redis start')
    setup_syncookies()
    config_monit_redis()
    
def setup_munin():
    sudo('apt-get update')
    sudo('apt-get install -y munin munin-node munin-plugins-extra spawn-fcgi')
    put('config/munin.conf', '/etc/munin/munin.conf', use_sudo=True) # Only use on main munin
    put('config/spawn_fcgi_munin_graph.conf', '/etc/init.d/spawn_fcgi_munin_graph', use_sudo=True)
    put('config/spawn_fcgi_munin_html.conf', '/etc/init.d/spawn_fcgi_munin_html', use_sudo=True)
    sudo('chmod u+x /etc/init.d/spawn_fcgi_munin_graph')
    sudo('chmod u+x /etc/init.d/spawn_fcgi_munin_html')
    with settings(warn_only=True):
        sudo('chown nginx.www-data /var/log/munin/munin-cgi*')
        sudo('chown nginx.www-data /usr/lib/cgi-bin/munin-cgi*')
        sudo('chown nginx.www-data /usr/lib/munin/cgi/munin-cgi*')
    with settings(warn_only=True):
        sudo('/etc/init.d/spawn_fcgi_munin_graph stop')
        sudo('/etc/init.d/spawn_fcgi_munin_graph start')
        sudo('update-rc.d spawn_fcgi_munin_graph defaults')
        sudo('/etc/init.d/spawn_fcgi_munin_html stop')
        sudo('/etc/init.d/spawn_fcgi_munin_html start')
        sudo('update-rc.d spawn_fcgi_munin_html defaults')
    sudo('/etc/init.d/munin-node stop')
    time.sleep(2)
    sudo('/etc/init.d/munin-node start')
    with settings(warn_only=True):
        sudo('chown nginx.www-data /var/log/munin/munin-cgi*')
        sudo('chown nginx.www-data /usr/lib/cgi-bin/munin-cgi*')
        sudo('chown nginx.www-data /usr/lib/munin/cgi/munin-cgi*')
        sudo('chmod a+rw /var/log/munin/*')
    with settings(warn_only=True):
        sudo('/etc/init.d/spawn_fcgi_munin_graph start')
        sudo('/etc/init.d/spawn_fcgi_munin_html start')

def copy_munin_data(from_server):
    put(os.path.join(env.SECRETS_PATH, 'keys/newsblur.key'), '~/.ssh/newsblur.key')
    put(os.path.join(env.SECRETS_PATH, 'keys/newsblur.key.pub'), '~/.ssh/newsblur.key.pub')
    run('chmod 600 ~/.ssh/newsblur*')

    # put("config/munin.nginx.conf", "/usr/local/nginx/conf/sites-enabled/munin.conf", use_sudo=True)
    sudo('/etc/init.d/nginx reload')

    run("rsync -az -e \"ssh -i /home/sclay/.ssh/newsblur.key\" --stats --progress %s:/var/lib/munin/ /srv/munin" % from_server)
    sudo('rm -fr /var/lib/bak-munin')
    sudo("mv /var/lib/munin /var/lib/bak-munin")
    sudo("mv /srv/munin /var/lib/")
    sudo("chown munin.munin -R /var/lib/munin")

    run("sudo rsync -az -e \"ssh -i /home/sclay/.ssh/newsblur.key\" --stats --progress %s:/etc/munin/ /srv/munin-etc" % from_server)
    sudo('rm -fr /etc/munin')
    sudo("mv /srv/munin-etc /etc/munin")
    sudo("chown munin.munin -R /etc/munin")

    run("sudo rsync -az -e \"ssh -i /home/sclay/.ssh/newsblur.key\" --stats --progress %s:/var/cache/munin/www/ /srv/munin-www" % from_server)
    sudo('rm -fr /var/cache/munin/www')
    sudo("mv /srv/munin-www /var/cache/munin/www")
    sudo("chown munin.munin -R /var/cache/munin/www")

    sudo("/etc/init.d/munin restart")
    sudo("/etc/init.d/munin-node restart")
    

def setup_db_munin():
    sudo('rm -f /etc/munin/plugins/mongo*')
    sudo('rm -f /etc/munin/plugins/pg_*')
    sudo('rm -f /etc/munin/plugins/redis_*')
    sudo('cp -frs %s/config/munin/mongo* /etc/munin/plugins/' % env.NEWSBLUR_PATH)
    sudo('cp -frs %s/config/munin/pg_* /etc/munin/plugins/' % env.NEWSBLUR_PATH)
    sudo('cp -frs %s/config/munin/redis_* /etc/munin/plugins/' % env.NEWSBLUR_PATH)
    sudo('/etc/init.d/munin-node stop')
    time.sleep(2)
    sudo('/etc/init.d/munin-node start')


def enable_celerybeat():
    with virtualenv():
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
    setup_node_app()
    sudo('mkdir -p /srv/originals')
    sudo('chown %s.%s -R /srv/originals' % (env.user, env.user))        # We assume that the group is the same name as the user. It's common on linux
    config_monit_original()
    put('config/supervisor_node_original.conf',
        '/etc/supervisor/conf.d/node_original.conf', use_sudo=True)
    sudo('supervisorctl reread')
    sudo('supervisorctl reload')

def setup_elasticsearch():
    ES_VERSION = "2.4.4"
    sudo('add-apt-repository -y ppa:openjdk-r/ppa')
    sudo('apt-get update')
    sudo('apt-get install openjdk-7-jre -y')

    with cd(env.VENDOR_PATH):
        run('mkdir -p elasticsearch-%s' % ES_VERSION)
    with cd(os.path.join(env.VENDOR_PATH, 'elasticsearch-%s' % ES_VERSION)):
        # run('wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-%s.deb' % ES_VERSION) # For v5+
        run('wget http://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-%s.deb' % ES_VERSION) # For v1-v2
        sudo('dpkg -i elasticsearch-%s.deb' % ES_VERSION)
        if not files.exists('/usr/share/elasticsearch/plugins/head'):
            sudo('/usr/share/elasticsearch/bin/plugin install mobz/elasticsearch-head')

def setup_db_search():
    put('config/supervisor_celeryd_search_indexer.conf', '/etc/supervisor/conf.d/celeryd_search_indexer.conf', use_sudo=True)
    put('config/supervisor_celeryd_search_indexer_tasker.conf', '/etc/supervisor/conf.d/celeryd_search_indexer_tasker.conf', use_sudo=True)
    sudo('supervisorctl reread')
    sudo('supervisorctl update')

def setup_imageproxy(install_go=False):
    # sudo('apt-get update')
    # sudo('apt-get install -y golang')
    if install_go:
        with cd(env.VENDOR_PATH):
            with settings(warn_only=True):
                run('git clone https://github.com/willnorris/imageproxy.git')
            run('wget https://dl.google.com/go/go1.13.3.linux-amd64.tar.gz')
            run('tar -xzf go1.13.3.linux-amd64.tar.gz')
            run('rm go1.13.3.linux-amd64.tar.gz')
            sudo('rm /usr/bin/go')
            sudo('ln -s /srv/code/go/bin/go /usr/bin/go')
        with cd(os.path.join(env.VENDOR_PATH, 'imageproxy')):
            run('go get willnorris.com/go/imageproxy/cmd/imageproxy')
    put(os.path.join(env.SECRETS_PATH, 'settings/imageproxy.key'), 
        '/etc/imageproxy.key', use_sudo=True)
    put(os.path.join(env.NEWSBLUR_PATH, 'config/supervisor_imageproxy.conf'), '/etc/supervisor/conf.d/supervisor_imageproxy.conf', use_sudo=True)
    sudo('supervisorctl reread')
    sudo('supervisorctl update')
    sudo('ufw allow 443')
    sudo('ufw allow 80')
    put(os.path.join(env.NEWSBLUR_PATH, 'config/nginx.imageproxy.conf'), "/usr/local/nginx/conf/sites-enabled/imageproxy.conf", use_sudo=True)
    sudo("/etc/init.d/nginx restart")
    
    
    
@parallel
def setup_usage_monitor():
    sudo('ln -fs %s/utils/monitor_disk_usage.py /etc/cron.daily/monitor_disk_usage' % env.NEWSBLUR_PATH)
    sudo('/etc/cron.daily/monitor_disk_usage')
    
@parallel
def setup_feeds_fetched_monitor():
    sudo('ln -fs %s/utils/monitor_task_fetches.py /etc/cron.hourly/monitor_task_fetches' % env.NEWSBLUR_PATH)
    sudo('/etc/cron.hourly/monitor_task_fetches')
    
@parallel
def setup_newsletter_monitor():
    sudo('ln -fs %s/utils/monitor_newsletter_delivery.py /etc/cron.hourly/monitor_newsletter_delivery' % env.NEWSBLUR_PATH)
    sudo('/etc/cron.hourly/monitor_newsletter_delivery')
    
@parallel
def setup_queue_monitor():
    sudo('ln -fs %s/utils/monitor_work_queue.py /etc/cron.hourly/monitor_work_queue' % env.NEWSBLUR_PATH)
    sudo('/etc/cron.hourly/monitor_work_queue')
    
@parallel
def setup_redis_monitor():
    run('sleep 5') # Wait for redis to startup so the log file is there
    sudo('ln -fs %s/utils/monitor_redis_bgsave.py /etc/cron.daily/monitor_redis_bgsave' % env.NEWSBLUR_PATH)
    with settings(warn_only=True):
        sudo('/etc/cron.daily/monitor_redis_bgsave')
    
# ================
# = Setup - Task =
# ================

def setup_task_firewall():
    sudo('ufw default deny')
    sudo('ufw allow ssh')
    sudo('ufw allow 80')
    sudo('ufw --force enable')

def setup_motd(role='app'):
    motd = '/etc/update-motd.d/22-newsblur-motd'
    put('config/motd_%s.txt' % role, motd, use_sudo=True)
    sudo('chown root.root %s' % motd)
    sudo('chmod a+x %s' % motd)

def enable_celery_supervisor(queue=None, update=True):
    if not queue:
        put('config/supervisor_celeryd.conf', '/etc/supervisor/conf.d/celeryd.conf', use_sudo=True)
    else:
        put('config/supervisor_celeryd_%s.conf' % queue, '/etc/supervisor/conf.d/celeryd.conf', use_sudo=True)

    sudo('supervisorctl reread')
    if update:
        sudo('supervisorctl update')

@parallel
def copy_db_settings():
    return copy_task_settings()
    
@parallel
def copy_task_settings():
    server_hostname = run('hostname')
    # if any([(n in server_hostname) for n in ['task', 'db', 'search', 'node', 'push']]):
    host = server_hostname
    # elif env.host:
    #     host = env.host.split('.', 2)[0]
    # else:
    #     host = env.host_string.split('.', 2)[0]

    with settings(warn_only=True):
        run('rm -f %s/local_settings.py' % env.NEWSBLUR_PATH)
        put(os.path.join(env.SECRETS_PATH, 'settings/task_settings.py'), 
            '%s/newsblur/local_settings.py' % env.NEWSBLUR_PATH)
        run('echo "\nSERVER_NAME = \\\\"%s\\\\"" >> %s/newsblur/local_settings.py' % (host, env.NEWSBLUR_PATH))

@parallel
def copy_spam():
    put(os.path.join(env.SECRETS_PATH, 'spam/spam.py'), '%s/apps/social/spam.py' % env.NEWSBLUR_PATH)
    
# =========================
# = Setup - Digital Ocean =
# =========================

DO_SIZES = {
    '1': 's-1vcpu-1gb',
    '2': 's-1vcpu-2gb',
    '4': 's-2vcpu-4gb',
    '8': 's-4vcpu-8gb',
    '16': 's-6vcpu-16gb',
    '32': 's-8vcpu-32gb',
    '48': 's-12vcpu-48gb',
    '64': 's-16vcpu-64gb',
    '32c': 'c-16',
}

def setup_do(name, size=1, image=None):
    instance_size = DO_SIZES[str(size)]
    doapi = digitalocean.Manager(token=django_settings.DO_TOKEN_FABRIC)
    # droplets = doapi.get_all_droplets()
    # sizes = dict((s.slug, s.slug) for s in doapi.get_all_sizes())
    ssh_key_ids = [k.id for k in doapi.get_all_sshkeys()]
    if not image:
        image = "ubuntu-20-04-x64"
    else:
        images = dict((s.name, s.id) for s in doapi.get_all_images())
        if image == "task": 
            image = images["task-2018-02"]
        elif image == "app":
            image = images["app-2018-02"]
        else:
            images = dict((s.name, s.id) for s in doapi.get_all_images())
            print(images)
            
    name = do_name(name)
    env.doname = name
    print("Creating droplet: %s" % name)
    instance = digitalocean.Droplet(token=django_settings.DO_TOKEN_FABRIC,
                                    name=name,
                                    size_slug=instance_size,
                                    image=image,
                                    region='nyc1',
                                    monitoring=True,
                                    private_networking=True,
                                    ssh_keys=ssh_key_ids)
    instance.create()
    time.sleep(2)
    instance = digitalocean.Droplet.get_object(django_settings.DO_TOKEN_FABRIC, instance.id)
    print("Booting droplet: %s / %s (size: %s)" % (instance.name, instance.ip_address, instance_size))

    i = 0
    while True:
        if instance.status == 'active':
            print("...booted: %s" % instance.ip_address)
            time.sleep(5)
            break
        elif instance.status == 'new':
            print(".", end=' ')
            sys.stdout.flush()
            instance = digitalocean.Droplet.get_object(django_settings.DO_TOKEN_FABRIC, instance.id)
            i += 1
            time.sleep(i)
        else:
            print("!!! Error: %s" % instance.status)
            return

    host = instance.ip_address
    env.host_string = host
    time.sleep(20)
    add_user_to_do()
    assign_digitalocean_roledefs()

def do_name(name):
    if re.search(r"[0-9]", name):
        print(" ---> Using %s as hostname" % name)
        return name
    else:
        hosts = do_roledefs(split=False)
        hostnames = [host.name for host in hosts]
        existing_hosts = [hostname for hostname in hostnames if name in hostname]
        for i in range(1, 100):
            try_host = "%s%02d" % (name, i)
            if try_host not in existing_hosts:
                print(" ---> %s hosts in %s (%s). %s is unused." % (len(existing_hosts), name, 
                                                                    ', '.join(existing_hosts), try_host))
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
    copy_ssh_keys()
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
    print("Booting reservation: %s/%s (size: %s)" % (reservation, instance, INSTANCE_TYPE))
    i = 0
    while True:
        if instance.state == 'pending':
            print(".", end=' ')
            sys.stdout.flush()
            instance.update()
            i += 1
            time.sleep(i)
        elif instance.state == 'running':
            print("...booted: %s" % instance.public_dns_name)
            time.sleep(5)
            break
        else:
            print("!!! Error: %s" % instance.state)
            return

    host = instance.public_dns_name
    env.host_string = host

# ==========
# = Deploy =
# ==========

@parallel
def pull(master=False):
    with virtualenv():
        run('git pull')
        if master:
            run('git checkout master')
            run('git pull')

def pre_deploy():
    compress_assets(bundle=True)

@serial
def post_deploy():
    cleanup_assets()

def role_for_host():
    for role, hosts in list(env.roledefs.items()):
        if env.host in hosts:
            return role

@parallel
def deploy(fast=False, reload=False):
    role = role_for_host()
    if role in ['work', 'search', 'debug']:
        deploy_code(copy_assets=False, fast=fast, reload=True)
    else:
        deploy_code(copy_assets=False, fast=fast, reload=reload)

@parallel
def deploy_web(fast=False):
    role = role_for_host()
    if role in ['work', 'search']:
        deploy_code(copy_assets=True, fast=fast, reload=True)
    else:
        deploy_code(copy_assets=True, fast=fast)

@parallel
def deploy_rebuild(fast=False):
    deploy_code(copy_assets=True, fast=fast, rebuild=True)

@parallel
def kill_gunicorn():
    with virtualenv():
        sudo('pkill -9 -u %s -f gunicorn_django' % env.user)
                
@parallel
def deploy_code(copy_assets=False, rebuild=False, fast=False, reload=False):
    with virtualenv():
        run('git pull')
        run('mkdir -p static')
        if rebuild:
            run('rm -fr static/*')
        if copy_assets:
            transfer_assets()
        
    with virtualenv():
        with settings(warn_only=True):
            if reload:
                sudo('supervisorctl reload')
            elif fast:
                kill_gunicorn()
            else:
                sudo('kill -HUP `cat /srv/newsblur/logs/gunicorn.pid`')

@parallel
def kill():
    sudo('supervisorctl reload')
    with settings(warn_only=True):
        if env.user == 'ubuntu':
            sudo('./utils/kill_gunicorn.sh')
        else:
            run('./utils/kill_gunicorn.sh')

@parallel
def deploy_node():
    pull()
    with virtualenv():
        run('sudo supervisorctl restart node_unread')
        run('sudo supervisorctl restart node_unread_ssl')
        run('sudo supervisorctl restart node_favicons')
        run('sudo supervisorctl restart node_text')

def gunicorn_restart():
    restart_gunicorn()

def restart_gunicorn():
    with virtualenv(), settings(warn_only=True):
        run('sudo supervisorctl restart gunicorn')

def gunicorn_stop():
    with virtualenv(), settings(warn_only=True):
        run('sudo supervisorctl stop gunicorn')

def staging():
    with cd('~/staging'):
        run('git pull')
        run('kill -HUP `cat logs/gunicorn.pid`')
        run('curl -s http://dev.newsblur.com > /dev/null')
        run('curl -s http://dev.newsblur.com/m/ > /dev/null')

def staging_build():
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
    with virtualenv():
        run('git pull')
    celery_stop()
    celery_start()

@parallel
def celery_fast():
    with virtualenv():
        run('git pull')
    celery_reload()

@parallel
def celery_stop():
    with virtualenv():
        sudo('supervisorctl stop celery')
        with settings(warn_only=True):
            if env.user == 'ubuntu':
                sudo('./utils/kill_celery.sh')
            else:
                run('./utils/kill_celery.sh')

@parallel
def celery_start():
    with virtualenv():
        run('sudo supervisorctl start celery')
        run('tail logs/newsblur.log')

@parallel
def celery_reload():
    with virtualenv():
        run('sudo supervisorctl reload celery')
        run('tail logs/newsblur.log')

def kill_celery():
    with virtualenv():
        with settings(warn_only=True):
            if env.user == 'ubuntu':
                sudo('./utils/kill_celery.sh')
            else:
                run('./utils/kill_celery.sh')  

def compress_assets(bundle=False):
    local('jammit -c newsblur/assets.yml --base-url https://www.newsblur.com --output static')
    local('tar -czf static.tgz static/*')

    tries_left = 5
    while True:
        try:
            success = False
            with settings(warn_only=True):
                local('PYTHONPATH=/srv/newsblur python utils/backups/s3.py set static.tgz')
                success = True
            if not success:
                raise Exception("Ack!")
            break
        except Exception as e:
            print(" ***> %s. Trying %s more time%s..." % (e, tries_left, '' if tries_left == 1 else 's'))
            tries_left -= 1
            if tries_left <= 0: break


def transfer_assets():
    # filename = "deploy_%s.tgz" % env.commit # Easy rollback? Eh, can just upload it again.
    # run('PYTHONPATH=/srv/newsblur python s3.py get deploy_%s.tgz' % filename)
    run('PYTHONPATH=/srv/newsblur python utils/backups/s3.py get static.tgz')
    # run('mv %s static/static.tgz' % filename)
    run('mv static.tgz static/static.tgz')
    run('tar -xzf static/static.tgz')
    run('rm -f static/static.tgz')

def cleanup_assets():
    local('rm -f static.tgz')

# ===========
# = Backups =
# ===========

def setup_redis_backups(name=None):
    # crontab for redis backups, name is either none, story, sessions, pubsub
    crontab = ("0 4 * * * /srv/newsblur/venv/newsblur3/bin/python /srv/newsblur/utils/backups/backup_redis%s.py" % 
                (("_%s"%name) if name else ""))
    run('(crontab -l ; echo "%s") | sort - | uniq - | crontab -' % crontab)
    run('crontab -l')

def setup_mongo_backups():
    # crontab for mongo backups
    crontab = "0 4 * * * /srv/newsblur/venv/newsblur3/bin/python /srv/newsblur/utils/backups/backup_mongo.py"
    run('(crontab -l ; echo "%s") | sort - | uniq - | crontab -' % crontab)
    run('crontab -l')
    
def setup_postgres_backups():
    # crontab for postgres backups
    crontab = """
0 4 * * * /srv/newsblur/venv/newsblur3/bin/python /srv/newsblur/utils/backups/backup_psql.py
0 * * * * sudo find /var/lib/postgresql/13/archive -mtime +1 -exec rm {} \;
0 * * * * sudo find /var/lib/postgresql/13/archive -type f -mmin +180 -delete"""

    run('(crontab -l ; echo "%s") | sort - | uniq - | crontab -' % crontab)
    run('crontab -l')
    
def backup_redis(name=None):
    run('/srv/newsblur/venv/newsblur3/bin/python /srv/newsblur/utils/backups/backup_redis%s.py' % (("_%s"%name) if name else ""))
    
def backup_mongo():
    run('/srv/newsblur/venv/newsblur3/bin/python /srv/newsblur/utils/backups/backup_mongo.py')

def backup_postgresql():
    run('/srv/newsblur/venv/newsblur3/bin/python /srv/newsblur/utils/backups/backup_psql.py')

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

# ==============
# = Tasks - DB =
# ==============

def restore_postgres(port=5432, download=False):
    with virtualenv():
        backup_date = '2020-12-03-02-51'
        yes = prompt("Dropping and creating NewsBlur PGSQL db. Sure?")
        if yes != 'y':
            return
        if download:
            run('mkdir -p postgres')
            run('PYTHONPATH=%s python utils/backups/s3.py get postgres/backup_postgresql_%s.sql.gz' % (env.NEWSBLUR_PATH, backup_date))
        # sudo('su postgres -c "createuser -p %s -U newsblur"' % (port,))
        with settings(warn_only=True): 
            # May not exist
            run('dropdb newsblur -p %s -U newsblur' % (port,), pty=False)
            run('sudo -u postgres createuser newsblur -s')
            # May already exist
            run('createdb newsblur -p %s -O newsblur -U newsblur' % (port,), pty=False)
        run('pg_restore -U newsblur -p %s --role=newsblur --dbname=newsblur /srv/newsblur/postgres/backup_postgresql_%s.sql.gz' % (port, backup_date), pty=False)

def restore_mongo(download=False):
    backup_date = '2020-11-11-04-00'
    if download:
        run('PYTHONPATH=/srv/newsblur python utils/backups/s3.py get backup_mongo_%s.tgz' % (backup_date))
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
        print(" ---> You need to fix django's settings. Enter python and type `import settings`.")

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
        print("[%s] %s" % (i, key.name))

def delete_all_backups():
    #FIXME: validate filename exists
    conn   = S3Connection(ACCESS_KEY, SECRET)
    bucket = conn.get_bucket(BUCKET_NAME)

    for i, key in enumerate(bucket.get_all_keys()):
        print("deleting %s" % (key.name))
        key.delete()

def add_revsys_keys():
    put("~/Downloads/revsys-keys.pub", "revsys_keys")
    run('cat revsys_keys >> ~/.ssh/authorized_keys')
    run('rm revsys_keys')

def upgrade_to_virtualenv(role=None):
    if not role:
        print(" ---> You must specify a role!")
        return
    setup_virtualenv()
    if role == "task" or role == "search":
        celery_stop()
    elif role == "app":
        gunicorn_stop()
    elif role == "node":
        run('sudo supervisorctl stop node_unread')
        run('sudo supervisorctl stop node_favicons')
    elif role == "work":
        sudo('/etc/init.d/supervisor stop')
    kill_pgbouncer(bounce=False)
    setup_installs()
    pip()
    if role == "task":
        enable_celery_supervisor(update=False)
        sudo('reboot')
    elif role == "app":
        setup_gunicorn(supervisor=True, restart=False)
        sudo('reboot')
    elif role == "node":
        deploy_node()
    elif role == "search":
        setup_db_search()
    elif role == "work":
        enable_celerybeat()
        sudo('reboot')

def benchmark():
    run('curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | sudo bash')
    sudo('apt-get install -y sysbench')
    run('sysbench cpu --cpu-max-prime=20000 run')
    run('sysbench fileio --file-total-size=150G prepare')
    run('sysbench fileio --file-total-size=150G --file-test-mode=rndrw --time=300 --max-requests=0 run')
    run('sysbench fileio --file-total-size=150G cleanup')
