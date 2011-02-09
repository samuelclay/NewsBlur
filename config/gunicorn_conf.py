import os

def numCPUs():
    if not hasattr(os, "sysconf"):
        raise RuntimeError("No sysconf detected.")
    return os.sysconf("SC_NPROCESSORS_ONLN")

bind = "127.0.0.1:8000"
pidfile = "/home/conesus/newsblur/logs/gunicorn.pid"
logfile = "/home/conesus/newsblur/logs/production.log"
loglevel = "debug"
name = "newsblur"
workers = numCPUs() * 2
