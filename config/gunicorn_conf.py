import os
import psutil


GIGS_OF_MEMORY = psutil.TOTAL_PHYMEM/1024/1024/1024.
NUM_CPU = psutil.NUM_CPU

bind = "127.0.0.1:8000"
pidfile = "/home/sclay/newsblur/logs/gunicorn.pid"
logfile = "/home/sclay/newsblur/logs/production.log"
accesslog = "/home/sclay/newsblur/logs/production.log"
errorlog = "/home/sclay/newsblur/logs/errors.log"
loglevel = "debug"
name = "newsblur"
timeout = 120
max_requests = 1000
if GIGS_OF_MEMORY > NUM_CPU:
    workers = NUM_CPU
else:
    workers = int(NUM_CPU / 2)
