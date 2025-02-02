import math
import os

import psutil

try:
    from newsblur_web import app_env
except ImportError:
    app_env = None

GIGS_OF_MEMORY = psutil.virtual_memory().total / 1024 / 1024 / 1024.0
NUM_CPUS = psutil.cpu_count()

bind = "0.0.0.0:8000"

pidfile = "/srv/newsblur/logs/gunicorn.pid"
logfile = "/srv/newsblur/logs/production.log"
accesslog = "/srv/newsblur/logs/production.log"
errorlog = "/srv/newsblur/logs/errors.log"
loglevel = "info"
name = "newsblur"
timeout = 120
max_requests = 1000
x_forwarded_for_header = "X-FORWARDED-FOR"
forwarded_allow_ips = "*"
limit_request_line = 16000
limit_request_fields = 1000
worker_tmp_dir = "/dev/shm"
reload = False

workers = max(int(math.floor(GIGS_OF_MEMORY * 2)), 3)

if workers > 16:
    workers = 16

if os.environ.get("DOCKERBUILD", False):
    workers = 2
    reload = True

# If hostname has staging in it, only 2 workers
if app_env and "staging" in getattr(app_env, "SERVER_NAME", ""):
    workers = 2

prom_folder = "/srv/newsblur/.prom_cache"
os.makedirs(prom_folder, exist_ok=True)
os.environ["PROMETHEUS_MULTIPROC_DIR"] = prom_folder
for filename in os.listdir(prom_folder):
    file_path = os.path.join(prom_folder, filename)
    try:
        if os.path.isfile(file_path) or os.path.islink(file_path):
            os.unlink(file_path)
        elif os.path.isdir(file_path):
            shutil.rmtree(file_path)
    except Exception as e:
        print("Failed to delete %s. Reason: %s" % (file_path, e))

from prometheus_client import multiprocess


def child_exit(server, worker):
    multiprocess.mark_process_dead(worker.pid)
