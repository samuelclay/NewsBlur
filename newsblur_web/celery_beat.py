"""
Celery beat scheduler that dedupes periodic tasks across redundant beat processes.

Every htask-work server runs `celery worker -B`, so the same beat schedule ticks on
three hosts and every periodic task was being enqueued three times within a few
seconds. Running beat on a single host would fix that at the cost of redundancy.
Instead, each beat keeps its own schedule, but before enqueueing a task it must win
a redis lock for that task's interval. The first beat to fire wins, the others skip,
and if the winning host dies a surviving beat wins the next interval.
"""

import os

import redis
from celery.beat import PersistentScheduler
from django.conf import settings

from utils import log as logging

# newsblur_web/celery_beat.py: The lock lives for most of the task's interval: long enough
# that a beat firing minutes behind the winner can't re-enqueue the task, short enough to
# have expired by the time the next interval arrives. The floor covers one-minute tasks
# on beats skewed by a few seconds.
LOCK_INTERVAL_FRACTION = 0.9
MINIMUM_LOCK_SECONDS = 30

# newsblur_web/celery_beat.py: Worktrees share redis with the main dev instance, so each
# worktree's beat locks are namespaced away from the others'.
LOCK_PREFIX = os.environ.get("NEWSBLUR_WORKTREE", "")


def beat_lock_key(task_name):
    if LOCK_PREFIX:
        return f"beat:dedup:{LOCK_PREFIX}:{task_name}"

    return f"beat:dedup:{task_name}"


def beat_lock_ttl(interval_seconds):
    return max(int(interval_seconds * LOCK_INTERVAL_FRACTION), MINIMUM_LOCK_SECONDS)


def acquire_beat_lock(task_name, interval_seconds):
    """
    Claim the right to enqueue this task for its current interval. Returns False when
    another beat process already enqueued it. Fails open when redis is unreachable:
    a duplicated task beats a missing one.
    """
    try:
        r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        return bool(r.set(beat_lock_key(task_name), "locked", nx=True, ex=beat_lock_ttl(interval_seconds)))
    except redis.RedisError as e:
        logging.debug(" ---> ~FRBeat dedup lock unavailable (%s), enqueueing anyway" % e)
        return True


def schedule_interval_seconds(entry):
    """The entry's repeat interval, or None for schedules without a fixed interval."""
    run_every = getattr(entry.schedule, "run_every", None)
    if run_every is None:
        return None

    return run_every.total_seconds()


class DedupPersistentScheduler(PersistentScheduler):
    """PersistentScheduler that skips entries another beat process already enqueued."""

    def apply_entry(self, entry, producer=None):
        interval_seconds = schedule_interval_seconds(entry)
        if interval_seconds and not acquire_beat_lock(entry.task, interval_seconds):
            logging.debug(" ---> ~FBBeat dedup: ~SB%s~SN already enqueued by another beat" % entry.task)
            return

        super().apply_entry(entry, producer=producer)
