from fabric.api import env, run, require, sudo, settings

# =========
# = Roles =
# =========

env.user = 'conesus'
env.hosts = ['www.newsblur.com', 'db01.newsblur.com']
env.roledefs ={
    'web': ['app01.newsblur.com'],
    'ff': ['app01.newsblur.com', 'db01.newsblur.com'],
    'db': ['db01.newsblur.com'],
}

"""
Base configuration
"""
env.project_name = '$(project)'
env.database_password = '$(db_password)'
env.site_media_prefix = "site_media"
env.admin_media_prefix = "admin_media"
env.newsapps_media_prefix = "na_media"
env.path = '/home/newsapps/sites/%(project_name)s' % env
env.log_path = '/home/newsapps/logs/%(project_name)s' % env
env.env_path = '%(path)s/env' % env
env.repo_path = '%(path)s/repository' % env
env.apache_config_path = '/home/newsapps/sites/apache/%(project_name)s' % env
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
    
"""
Commands - setup
"""
def setup():
    """
    Setup a fresh virtualenv, install everything we need, and fire up the database.
    
    Does NOT perform the functions of deploy().
    """
    require('settings', provided_by=[production, staging])
    require('branch', provided_by=[stable, master, branch])
    
    setup_directories()
    setup_virtualenv()
    clone_repo()
    checkout_latest()
    destroy_database()
    create_database()
    load_data()
    install_requirements()
    install_apache_conf()
    deploy_requirements_to_s3()

def setup_directories():
    """
    Create directories necessary for deployment.
    """
    run('mkdir -p %(path)s' % env)
    run('mkdir -p %(env_path)s' % env)
    run ('mkdir -p %(log_path)s;' % env)
    sudo('chgrp -R www-data %(log_path)s; chmod -R g+w %(log_path)s;' % env)
    run('ln -s %(log_path)s %(path)s/logs' % env)
    
def setup_virtualenv():
    """
    Setup a fresh virtualenv.
    """
    run('virtualenv -p %(python)s --no-site-packages %(env_path)s;' % env)
    run('source %(env_path)s/bin/activate; easy_install -U setuptools; easy_install pip;' % env)

def clone_repo():
    """
    Do initial clone of the git repository.
    """
    run('git clone git@tribune.unfuddle.com:tribune/%(project_name)s.git %(repo_path)s' % env)

def checkout_latest():
    """
    Pull the latest code on the specified branch.
    """
    run('cd %(repo_path)s; git checkout %(branch)s; git pull origin %(branch)s' % env)

def install_requirements():
    """
    Install the required packages using pip.
    """
    run('source %(env_path)s/bin/activate; pip install -E %(env_path)s -r %(repo_path)s/requirements.txt' % env)

def install_apache_conf():
    """
    Install the apache site config file.
    """
    sudo('cp %(repo_path)s/%(project_name)s/configs/%(settings)s/%(project_name)s %(apache_config_path)s' % env)

def deploy_requirements_to_s3():
    """
    Deploy the latest newsapps and admin media to s3.
    """
    run('s3cmd del --recursive s3://%(s3_bucket)s/%(project_name)s/%(admin_media_prefix)s/' % env)
    run('s3cmd -P --guess-mime-type sync %(env_path)s/src/django/django/contrib/admin/media/ s3://%(s3_bucket)s/%(project_name)s/%(site_media_prefix)s/' % env)
    run('s3cmd del --recursive s3://%(s3_bucket)s/%(project_name)s/%(newsapps_media_prefix)s/' % env)
    run('s3cmd -P --guess-mime-type sync %(env_path)s/src/newsapps/newsapps/na_media/ s3://%(s3_bucket)s/%(project_name)s/%(newsapps_media_prefix)s/' % env)
    
"""
Commands - deployment
"""
def deploy():
    """
    Deploy the latest version of the site to the server and restart Apache2.
    
    Does not perform the functions of load_new_data().
    """
    require('settings', provided_by=[production, staging])
    require('branch', provided_by=[stable, master, branch])
    
    with settings(warn_only=True):
        maintenance_up()
        
    checkout_latest()
    gzip_assets()
    deploy_to_s3()
    refresh_widgets()
    maintenance_down()
    
def maintenance_up():
    """
    Install the Apache maintenance configuration.
    """
    sudo('cp %(repo_path)s/%(project_name)s/configs/%(settings)s/%(project_name)s_maintenance %(apache_config_path)s' % env)
    reboot()

def gzip_assets():
    """
    GZips every file in the assets directory and places the new file
    in the gzip directory with the same filename.
    """
    run('cd %(repo_path)s; python gzip_assets.py' % env)

def deploy_to_s3():
    """
    Deploy the latest project site media to S3.
    """
    env.gzip_path = '%(path)s/repository/%(project_name)s/gzip/assets/' % env
    run(('s3cmd -P --add-header=Content-encoding:gzip --guess-mime-type --rexclude-from=%(path)s/repository/s3exclude sync %(gzip_path)s s3://%(s3_bucket)s/%(project_name)s/%(site_media_prefix)s/') % env)
       
def refresh_widgets():
    """
    Redeploy the widgets to S3.
    """
    run('source %(env_path)s/bin/activate; cd %(repo_path)s; ./manage refreshwidgets' % env)

def reboot(): 
    """
    Restart the Apache2 server.
    """
    sudo('/mnt/apps/bin/restart-all-apache.sh')
    
def maintenance_down():
    """
    Reinstall the normal site configuration.
    """
    install_apache_conf()
    reboot()
    
"""
Commands - rollback
"""
def rollback(commit_id):
    """
    Rolls back to specified git commit hash or tag.
    
    There is NO guarantee we have committed a valid dataset for an arbitrary
    commit hash.
    """
    require('settings', provided_by=[production, staging])
    require('branch', provided_by=[stable, master, branch])
    
    maintenance_up()
    checkout_latest()
    git_reset(commit_id)
    gzip_assets()
    deploy_to_s3()
    refresh_widgets()
    maintenance_down()
    
def git_reset(commit_id):
    """
    Reset the git repository to an arbitrary commit hash or tag.
    """
    env.commit_id = commit_id
    run("cd %(repo_path)s; git reset --hard %(commit_id)s" % env)

"""
Commands - data
"""
def load_new_data():
    """
    Erase the current database and load new data from the SQL dump file.
    """
    require('settings', provided_by=[production, staging])
    
    maintenance_up()
    pgpool_down()
    destroy_database()
    create_database()
    load_data()
    pgpool_up()
    maintenance_down()
    
def create_database():
    """
    Creates the user and database for this project.
    """
    run('echo "CREATE USER %(project_name)s WITH PASSWORD \'%(database_password)s\';" | psql postgres' % env)
    run('createdb -O %(project_name)s %(project_name)s -T template_postgis' % env)
    
def destroy_database():
    """
    Destroys the user and database for this project.
    
    Will not cause the fab to fail if they do not exist.
    """
    with settings(warn_only=True):
        run('dropdb %(project_name)s' % env)
        run('dropuser %(project_name)s' % env)
        
def load_data():
    """
    Loads data from the repository into PostgreSQL.
    """
    run('psql -q %(project_name)s < %(path)s/repository/data/psql/dump.sql' % env)
    run('psql -q %(project_name)s < %(path)s/repository/data/psql/finish_init.sql' % env)
    
def pgpool_down():
    """
    Stop pgpool so that it won't prevent the database from being rebuilt.
    """
    sudo('/etc/init.d/pgpool stop')
    
def pgpool_up():
    """
    Start pgpool.
    """
    sudo('/etc/init.d/pgpool start')

"""
Commands - miscellaneous
"""
    
def clear_cache():
    """
    Restart memcache, wiping the current cache.
    """
    sudo('/mnt/apps/bin/restart-memcache.sh')
    
def echo_host():
    """
    Echo the current host to the command line.
    """
    run('echo %(settings)s; echo %(hosts)s' % env)

"""
Deaths, destroyers of worlds
"""
def shiva_the_destroyer():
    """
    Remove all directories, databases, etc. associated with the application.
    """
    with settings(warn_only=True):
        run('rm -Rf %(path)s' % env)
        run('rm -Rf %(log_path)s' % env)
        run('dropdb %(project_name)s' % env)
        run('dropuser %(project_name)s' % env)
        sudo('rm %(apache_config_path)s' % env)
        reboot()
        run('s3cmd del --recursive s3://%(s3_bucket)s/%(project_name)s' % env)

"""
Utility functions (not to be called directly)
"""
def _execute_psql(query):
    """
    Executes a PostgreSQL command using the command line interface.
    """
    env.query = query
    run(('cd %(path)s/repository; psql -q %(project_name)s -c "%(query)s"') % env)