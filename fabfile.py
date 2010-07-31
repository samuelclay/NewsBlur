from fabric.api import env

# =========
# = Roles =
# =========

env.roledefs ={
    'web': ['www.newsblur.com']
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
    config.fab_hosts = ['www.newsblur.com']
    config.repos = (('newsblur', 'origin', 'master'),)

# ===================
# = Server Commands =
# ===================    

def restart():
    run("cd ~/$(repo)/; ./utils/restart;")
    
def pull():
    require('fab_hosts', provided_by=[production])
    for repo, parent, branch in config.repos:
        config.repo = repo
        config.parent = parent
        config.branch = branch
        invoke(git_pull)

def reset(repo, hash):
    require('fab_hosts', provided_by=[production])
    config.hash = hash
    config.repo = repo
    invoke(git_reset)