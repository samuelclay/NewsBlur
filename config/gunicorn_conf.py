import math
import os
import shutil

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
max_requests_jitter = 500
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

# If hostname has staging in it, only 2 workers and higher max_requests
# since health checks from 3 haproxy backends (every 1s each) burn through
# max_requests quickly, causing both workers to restart simultaneously
if app_env and "staging" in getattr(app_env, "SERVER_NAME", ""):
    workers = 2
    max_requests = 5000

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

# Prometheus selects multiprocess mode at import time, after the directory is configured above.
from utils.prometheus_worker_slots import (  # noqa: E402
    lowest_free_slot,
    use_worker_slot,
)


def pre_fork(server, worker):
    """Assign the worker a Prometheus slot, in the master, before it forks.

    server.WORKERS holds exactly the live workers, so the slots it reports are the
    ones still in use and a reaped worker's slot frees itself. The child inherits
    this worker object through the fork and reads the slot back in post_fork.
    """
    live_slots = [
        live.prometheus_slot for live in server.WORKERS.values() if hasattr(live, "prometheus_slot")
    ]
    worker.prometheus_slot = lowest_free_slot(live_slots)


def post_fork(server, worker):
    """Bind the worker to its slot before Django constructs any metric."""
    slot = getattr(worker, "prometheus_slot", None)
    if slot is None:
        # Falling back to pid-named files keeps metrics working, but they
        # accumulate, so say so loudly rather than degrade in silence.
        server.log.error("Worker %s has no Prometheus slot; its metric files will accumulate", worker.pid)
        return
    use_worker_slot(prom_folder, slot)
