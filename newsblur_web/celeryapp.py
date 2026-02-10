from __future__ import absolute_import, unicode_literals

import functools
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

# Worktree queue isolation: automatically prefix queue names on all apply_async
# calls so tasks are routed to the worktree-specific queues. This avoids needing
# to change every apply_async(queue="...") call site in the codebase.
_worktree_name = os.environ.get("NEWSBLUR_WORKTREE", "")
if _worktree_name:
    _worktree_prefix = f"{_worktree_name}_"
    _original_apply_async = app.Task.apply_async

    @functools.wraps(_original_apply_async)
    def _prefixed_apply_async(self, *args, **kwargs):
        queue = kwargs.get("queue")
        if queue and not queue.startswith(_worktree_prefix):
            kwargs["queue"] = _worktree_prefix + queue
        return _original_apply_async(self, *args, **kwargs)

    app.Task.apply_async = _prefixed_apply_async

    # Also patch send_task, which is the path Celery Beat uses to dispatch
    # periodic tasks. Without this, beat-scheduled tasks would go to unprefixed
    # queues (consumed by main, not the worktree).
    _original_send_task = app.send_task

    @functools.wraps(_original_send_task)
    def _prefixed_send_task(*args, **kwargs):
        queue = kwargs.get("queue")
        if queue and not queue.startswith(_worktree_prefix):
            kwargs["queue"] = _worktree_prefix + queue
        return _original_send_task(*args, **kwargs)

    app.send_task = _prefixed_send_task


@app.on_after_finalize.connect
def setup_periodic_tasks(sender, **kwargs):
    """Import task modules after Celery is fully configured."""
    if sender.conf.imports:
        for module_name in sender.conf.imports:
            try:
                __import__(module_name)
            except ImportError as e:
                print(f"Failed to import {module_name}: {e}")
