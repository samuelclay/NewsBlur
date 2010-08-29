from fabric.api import env, run, require, cd

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

# ================
# = Git Commands =
# ================

def git_pull():
    run("cd ~/$(repo)/; git pull $(parent) $(branch)")
    
def git_reset():
    run("cd ~/$(repo)/; git reset --hard $(hash)")

# ================
# = Environments =
# ================   

def production():
    env.fab_hosts = ['app01.newsblur.com', 'db01.newsblur.com']
    env.repos = (('newsblur', 'origin', 'master'),)

# ===================
# = Server Commands =
# ===================    

def deploy():
    with cd('/home/conesus/newsblur'):
        run('git pull')
        run('./utils/restart')
    
def restart():
    run("cd ~/$(repo)/; ./utils/restart;")
    
def pull():
    require('fab_hosts', provided_by=[production])
    for repo, parent, branch in env.repos:
        env.repo = repo
        env.parent = parent
        env.branch = branch
        git_pull()

def reset(repo, hash):
    require('fab_hosts', provided_by=[production])
    env.hash = hash
    env.repo = repo
    git_reset()