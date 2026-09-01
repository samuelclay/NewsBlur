"""Tests for the beat dedup scheduler that keeps redundant celery beats from triple-firing tasks."""

import datetime
from types import SimpleNamespace
from unittest.mock import patch

import redis
from celery.beat import PersistentScheduler
from django.conf import settings
from django.test import TestCase

from newsblur_web.celery_beat import DedupPersistentScheduler, acquire_beat_lock, beat_lock_key, beat_lock_ttl


class Test_BeatDedup(TestCase):
    TASK_NAME = "test-beat-dedup-task"

    def setUp(self):
        self.r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)
        self.r.delete(beat_lock_key(self.TASK_NAME))
        self.addCleanup(lambda: self.r.delete(beat_lock_key(self.TASK_NAME)))

    def make_entry(self, interval=datetime.timedelta(hours=1)):
        return SimpleNamespace(task=self.TASK_NAME, schedule=SimpleNamespace(run_every=interval))

    def test_only_the_first_beat_wins_the_interval(self):
        """Three beats fire within seconds of each other; one task run comes out."""
        self.assertTrue(acquire_beat_lock(self.TASK_NAME, 3600))
        self.assertFalse(acquire_beat_lock(self.TASK_NAME, 3600))
        self.assertFalse(acquire_beat_lock(self.TASK_NAME, 3600))

    def test_lock_ttl_scales_with_the_interval_and_expires_before_the_next_run(self):
        self.assertEqual(beat_lock_ttl(3600), 3240)
        self.assertEqual(beat_lock_ttl(60), 54)
        # A floor keeps sub-minute intervals from thrashing the lock.
        self.assertEqual(beat_lock_ttl(10), 30)

    def test_scheduler_skips_an_entry_another_beat_enqueued(self):
        scheduler = object.__new__(DedupPersistentScheduler)
        entry = self.make_entry()
        acquire_beat_lock(self.TASK_NAME, 3600)

        with patch.object(PersistentScheduler, "apply_entry") as apply_entry:
            DedupPersistentScheduler.apply_entry(scheduler, entry)

        apply_entry.assert_not_called()

    def test_scheduler_applies_an_entry_when_it_wins_the_lock(self):
        scheduler = object.__new__(DedupPersistentScheduler)
        entry = self.make_entry()

        with patch.object(PersistentScheduler, "apply_entry") as apply_entry:
            DedupPersistentScheduler.apply_entry(scheduler, entry)

        apply_entry.assert_called_once_with(entry, producer=None)

    def test_scheduler_fails_open_when_redis_is_unreachable(self):
        """A duplicated cron task beats a missing one."""
        scheduler = object.__new__(DedupPersistentScheduler)
        entry = self.make_entry()

        with patch("newsblur_web.celery_beat.redis.Redis") as redis_cls:
            redis_cls.return_value.set.side_effect = redis.exceptions.ConnectionError("down")
            with patch.object(PersistentScheduler, "apply_entry") as apply_entry:
                DedupPersistentScheduler.apply_entry(scheduler, entry)

        apply_entry.assert_called_once_with(entry, producer=None)

    def test_an_entry_without_a_fixed_interval_is_always_applied(self):
        """Crontab-style schedules have no run_every; they pass through undeduped."""
        scheduler = object.__new__(DedupPersistentScheduler)
        entry = SimpleNamespace(task=self.TASK_NAME, schedule=SimpleNamespace())

        with patch.object(PersistentScheduler, "apply_entry") as apply_entry:
            DedupPersistentScheduler.apply_entry(scheduler, entry)

        apply_entry.assert_called_once_with(entry, producer=None)
