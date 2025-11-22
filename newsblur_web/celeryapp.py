from __future__ import absolute_import, unicode_literals

import os

from celery import Celery
from django.apps import apps

# set the default Django settings module for the 'celery' program.
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "newsblur_web.settings")

app = Celery("newsblur_web")

# Using a string here means the worker doesn't have to serialize
# the configuration object to child processes.
# - namespace='CELERY' means all celery-related configuration keys
#   should have a `CELERY_` prefix.
app.config_from_object("django.conf:settings", namespace="CELERY")

# Load task modules from all registered Django app configs.
app.autodiscover_tasks(lambda: [n.name for n in apps.get_app_configs()])


@app.on_after_finalize.connect
def setup_periodic_tasks(sender, **kwargs):
    """Import task modules after Celery is fully configured."""
    if sender.conf.imports:
        for module_name in sender.conf.imports:
            try:
                __import__(module_name)
            except ImportError as e:
                print(f"Failed to import {module_name}: {e}")
