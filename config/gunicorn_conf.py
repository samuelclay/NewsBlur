import os

def numCPUs():
    if not hasattr(os, "sysconf"):
        raise RuntimeError("No sysconf detected.")
    return os.sysconf("SC_NPROCESSORS_ONLN")

bind = "127.0.0.1:8000"
pidfile = "/home/sclay/newsblur/logs/gunicorn.pid"
logfile = "/home/sclay/newsblur/logs/production.log"
accesslog = "/home/sclay/newsblur/logs/production.log"
errorlog = "/home/sclay/newsblur/logs/errors.log"
loglevel = "debug"
name = "newsblur"
timeout = 60
max_requests = 1000
workers = numCPUs()
