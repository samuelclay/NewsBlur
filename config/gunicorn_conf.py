import psutil
import math

GIGS_OF_MEMORY = psutil.TOTAL_PHYMEM/1024/1024/1024.
NUM_CPUS = psutil.NUM_CPUS

bind = "0.0.0.0:8000"
pidfile = "/srv/newsblur/logs/gunicorn.pid"
logfile = "/srv/newsblur/logs/production.log"
accesslog = "/srv/newsblur/logs/production.log"
errorlog = "/srv/newsblur/logs/errors.log"
loglevel = "debug"
name = "newsblur"
timeout = 120
max_requests = 1000
x_forwarded_for_header = "X-Forwarded-For"

if GIGS_OF_MEMORY > NUM_CPUS:
    workers = NUM_CPUS
else:
    workers = int(NUM_CPUS / 2)

if workers <= 4:
    workers = max(int(math.floor(GIGS_OF_MEMORY * 1000 / 512)), 4)
if workers > 8:
    workers = 8