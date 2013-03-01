import psutil

GIGS_OF_MEMORY = psutil.TOTAL_PHYMEM/1024/1024/1024.
NUM_CPUS = psutil.NUM_CPUS

bind = "127.0.0.1:8000"
pidfile = "/srv/newsblur/logs/gunicorn.pid"
logfile = "/srv/newsblur/logs/production.log"
accesslog = "/srv/newsblur/logs/production.log"
errorlog = "/srv/newsblur/logs/errors.log"
loglevel = "debug"
name = "newsblur"
timeout = 120
max_requests = 1000
if GIGS_OF_MEMORY > NUM_CPUS:
    workers = NUM_CPUS
else:
    workers = int(NUM_CPUS / 2)
