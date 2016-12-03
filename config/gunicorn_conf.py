import psutil
import math

GIGS_OF_MEMORY = psutil.virtual_memory().total/1024/1024/1024.
NUM_CPUS = psutil.cpu_count()

bind = "0.0.0.0:8000"
pidfile = "/srv/newsblur/logs/gunicorn.pid"
logfile = "/srv/newsblur/logs/production.log"
accesslog = "/srv/newsblur/logs/production.log"
errorlog = "/srv/newsblur/logs/errors.log"
loglevel = "debug"
name = "newsblur"
timeout = 120
max_requests = 1000
x_forwarded_for_header = "X-FORWARDED-FOR"
forwarded_allow_ips = "*"
limit_request_line = 16000
limit_request_fields = 1000

if GIGS_OF_MEMORY > NUM_CPUS:
    workers = NUM_CPUS
else:
    workers = int(NUM_CPUS / 2)

if workers <= 4:
    workers = max(int(math.floor(GIGS_OF_MEMORY * 1000 / 512)), 4)

if workers > 8:
    workers = 8

