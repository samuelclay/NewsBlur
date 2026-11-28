"""Tests for apps/reorganize/tasks.py and apps/reorganize/usage.py, which make proposals in the
background and limit how often an account can ask for one.

Every test starts runs with start_proposal() and runs the queued task in this process. The model is
replaced at call_model() in apps/reorganize/generate.py, so the real generate_proposal() runs.
"""

import datetime
import json
from unittest.mock import patch

import pytz
import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase, override_settings
from kombu.exceptions import OperationalError

from apps.monitor.models import MLLMCost
from apps.profile.models import Profile
from apps.reader.models import UserSubscription, UserSubscriptionFolders
from apps.reorganize import generate, tasks, usage
from apps.reorganize.models import (
    FAILED,
    READY,
    WORKING,
    MReorganizeLocks,
    MReorganizeProposal,
)
from apps.reorganize.tasks import GenerateReorganizeProposal, start_proposal
from apps.reorganize.test_derive import assign, target
from apps.reorganize.test_generate import FakeModel, answer, declined
from apps.rss_feeds.models import Feed

# The dev server shares this Redis and MongoDB, so test sites take ids far above any local feed and
# apart from the ids other test modules use.
FIRST_FEED_ID = 2_000_200_000

LOS_ANGELES = pytz.timezone("America/Los_Angeles")


def los_angeles(*wall_clock):
    """The naive UTC time of a wall clock time in Los Angeles, as proposals store their dates."""
    local = LOS_ANGELES.localize(datetime.datetime(*wall_clock))
    return local.astimezone(pytz.UTC).replace(tzinfo=None)


def published_events(pubsub):
    """The reorganize events waiting on `pubsub`, in the order they were published."""
    events = []
    while True:
        message = pubsub.get_message(timeout=1.0)
        if message is None:
            return events
        if message["type"] != "message":
            continue
        prefix, _, payload = message["data"].partition(":")
        if prefix == "reorganize":
            events.append(json.loads(payload))


@override_settings(ANTHROPIC_API_KEY="sk-ant-test-" + "k" * 24)
class TasksTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="reorganize_tasks_test", password="test")
        for model in (MReorganizeProposal, MReorganizeLocks):
            model.objects(user_id=self.user.pk).delete()
            self.addCleanup(model.objects(user_id=self.user.pk).delete)
        self.set_plan(archive=False)

        self.next_feed_id = FIRST_FEED_ID
        self.gadgets = self.add_site("Gadget Blog")
        self.phones = self.add_site("Phones Weekly")
        self.set_tree([{"Tech": [self.gadgets]}, {"Sorted": [self.phones]}])

        self.model = FakeModel(
            design=lambda: answer(
                {
                    "targets": [
                        target("t1", "Tech", continues=["e0"]),
                        target("t2", "Sorted", continues=["e1"]),
                    ]
                }
            ),
            assign=lambda feed_ids: answer({"assignments": [assign(self.gadgets, "t2")]}),
        )
        model_call = patch.object(generate, "call_model", self.model)
        model_call.start()
        self.addCleanup(model_call.stop)

        # Queued runs wait here until the test runs them in this process.
        self.queued = []
        queue = patch.object(
            GenerateReorganizeProposal,
            "apply_async",
            side_effect=lambda kwargs=None, **options: self.queued.append(kwargs),
        )
        self.apply_async = queue.start()
        self.addCleanup(queue.stop)

        # Cost records land in the shared analytics database, so each test removes the ones it made.
        # The per-day cost counters in Redis are shared with the dev server and are left alone.
        counters = patch("apps.statistics.rllm_costs.RLLMCosts.record")
        counters.start()
        self.addCleanup(counters.stop)
        self.costs_before = set(self.cost_records().scalar("id"))
        self.addCleanup(self.delete_new_cost_records)

    def cost_records(self):
        return MLLMCost.objects(user_id=self.user.pk, feature="reorganize")

    def delete_new_cost_records(self):
        for record in self.cost_records():
            if record.id not in self.costs_before:
                record.delete()

    def set_plan(self, archive, timezone="America/New_York"):
        Profile.objects.filter(user=self.user).update(
            is_premium=archive, is_archive=archive, is_pro=False, timezone=timezone
        )
        self.user = User.objects.get(pk=self.user.pk)

    def add_site(self, title):
        feed_id = self.next_feed_id
        self.next_feed_id += 1
        feed = Feed.objects.create(
            pk=feed_id,
            feed_address="https://site-%s.example.com/rss" % feed_id,
            feed_link="https://site-%s.example.com/" % feed_id,
            feed_title=title,
        )
        UserSubscription.objects.create(user=self.user, feed=feed, active=True)
        return feed_id

    def set_tree(self, folders):
        UserSubscriptionFolders.objects.update_or_create(
            user=self.user, defaults={"folders": json.dumps(folders)}
        )

    def tree(self):
        return json.loads(UserSubscriptionFolders.objects.get(user=self.user).folders)

    def at(self, moment):
        """Run the limits at `moment`, a naive UTC time."""
        return patch.object(usage, "clock", lambda: moment)

    def start(self, level="reorganize"):
        return start_proposal(self.user, level, False, "", "en")

    def run_queued(self):
        """Run every queued run in this process, oldest first."""
        while self.queued:
            GenerateReorganizeProposal.apply(kwargs=self.queued.pop(0), throw=True)

    def run_one(self, level="reorganize"):
        """Start a run, run it, and return its proposal as stored."""
        started = self.start(level)
        self.assertEqual(started["code"], tasks.STARTED)
        self.run_queued()
        return MReorganizeProposal.objects.get(id=started["proposal"].id)

    def working_runs(self):
        return MReorganizeProposal.objects(user_id=self.user.pk, status=WORKING)


class Test_Outcomes(TasksTestCase):
    def test_model_decline_fails_the_run_without_using_up_the_month(self):
        self.model.design = lambda: declined()

        doc = self.run_one()

        self.assertEqual((doc.status, doc.error), (FAILED, generate.MODEL_DECLINED))
        self.assertEqual(self.start()["code"], tasks.STARTED)

    def test_exception_inside_the_run_leaves_it_failed(self):
        def broken_design():
            raise ValueError("unexpected answer object")

        self.model.design = broken_design
        started = self.start()

        with self.assertRaises(ValueError):
            self.run_queued()

        doc = MReorganizeProposal.objects.get(id=started["proposal"].id)
        self.assertEqual((doc.status, doc.error), (FAILED, tasks.RUN_FAILED))
        self.assertEqual(self.start()["code"], tasks.STARTED)

    def test_run_uses_the_locks_saved_when_it_started(self):
        hidden = self.add_site("Hidden Diary")
        self.set_tree([{"Tech": [self.gadgets]}, {"Sorted": [self.phones]}, {"Secret Stash": [hidden]}])
        MReorganizeLocks.save_locks(self.user.pk, keep=[], skip=[["Secret Stash"]])
        self.start()
        MReorganizeLocks.save_locks(self.user.pk, keep=[], skip=[])

        self.run_queued()

        self.assertTrue(self.model.calls)
        for call in self.model.calls:
            self.assertNotIn("Hidden Diary", call["text"])
            self.assertNotIn("Secret Stash", call["text"])


class Test_Progress(TasksTestCase):
    def subscribe(self):
        pubsub = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL).pubsub()
        self.addCleanup(pubsub.close)
        pubsub.subscribe(self.user.username)
        self.assertEqual(pubsub.get_message(timeout=1.0)["type"], "subscribe")
        return pubsub

    def test_events_run_from_start_through_rising_progress_to_ready(self):
        pubsub = self.subscribe()

        doc = self.run_one()

        events = published_events(pubsub)
        types = [event["type"] for event in events]
        self.assertEqual(types[0], "start")
        self.assertEqual(types[-1], "ready")
        self.assertEqual(set(types[1:-1]), {"progress"})
        progress = [event for event in events if event["type"] == "progress"]
        self.assertGreater(len(progress), 2)
        dones = [event["done"] for event in progress]
        self.assertEqual(dones, sorted(dones))
        self.assertEqual(dones[-1], progress[-1]["total"])
        for event in events:
            self.assertEqual((event["request_id"], event["proposal_id"]), (doc.request_id, str(doc.id)))
        last = progress[-1]
        self.assertEqual(doc.progress, {"step": last["step"], "done": last["done"], "total": last["total"]})

    def test_failed_run_publishes_its_error_code(self):
        self.model.design = lambda: declined()
        pubsub = self.subscribe()

        self.run_one()

        last = published_events(pubsub)[-1]
        self.assertEqual((last["type"], last["code"]), ("error", generate.MODEL_DECLINED))

    def test_run_finishes_when_redis_cannot_publish(self):
        with patch.object(redis.Redis, "publish", side_effect=redis.ConnectionError("pubsub is down")):
            doc = self.run_one()

        self.assertEqual(doc.status, READY)
        self.assertEqual(doc.progress["done"], doc.progress["total"])


class Test_Limits(TasksTestCase):
    def test_free_account_gets_one_run_per_calendar_month_in_its_own_time_zone(self):
        self.set_plan(archive=False, timezone="America/Los_Angeles")

        # 11pm on November 30th in Los Angeles is already December 1st in UTC.
        with self.at(los_angeles(2026, 11, 30, 23, 0)):
            self.run_one()
        with self.at(los_angeles(2026, 11, 30, 23, 30)):
            refusal = self.start()
            limits = usage.limits(self.user)

        reset = los_angeles(2026, 12, 1, 0, 0)
        self.assertEqual(refusal, {"code": usage.MONTHLY_LIMIT, "next_date": reset})
        self.assertEqual(
            (limits["can_apply"], limits["remaining"], limits["next_date"], limits["running"]),
            (False, 0, reset, False),
        )
        with self.at(los_angeles(2026, 12, 1, 0, 30)):
            self.assertEqual(self.start()["code"], tasks.STARTED)

    def test_archive_has_no_monthly_limit_but_a_cap_on_runs_in_any_24_hours(self):
        self.set_plan(archive=True)
        first = datetime.datetime(2026, 11, 10, 12, 0)

        for minute in range(usage.DAILY_RUNS):
            with self.at(first + datetime.timedelta(minutes=minute)):
                self.assertEqual(self.run_one().status, READY)
        with self.at(first + datetime.timedelta(hours=23)):
            refusal = self.start()
            limits = usage.limits(self.user)

        reopens = first + datetime.timedelta(hours=24)
        self.assertEqual(refusal, {"code": usage.DAILY_CAP, "next_date": reopens})
        self.assertEqual((limits["can_apply"], limits["remaining"], limits["next_date"]), (True, 0, reopens))
        with self.at(reopens + datetime.timedelta(seconds=1)):
            self.assertEqual(self.start()["code"], tasks.STARTED)

    def test_second_start_while_one_is_working_is_refused(self):
        began = datetime.datetime(2026, 11, 10, 12, 0)
        with self.at(began):
            self.start()

        with self.at(began + datetime.timedelta(minutes=19)):
            self.assertEqual(self.start(), {"code": usage.ALREADY_RUNNING, "next_date": None})
            self.assertTrue(usage.limits(self.user)["running"])
        self.assertEqual(len(self.queued), 1)

    def test_run_left_working_too_long_is_failed_and_a_new_one_starts(self):
        began = datetime.datetime(2026, 11, 10, 12, 0)
        with self.at(began):
            stale = self.start()["proposal"]

        with self.at(began + datetime.timedelta(minutes=21)):
            restarted = self.start()

        self.assertEqual(restarted["code"], tasks.STARTED)
        stale.reload()
        self.assertEqual(stale.status, FAILED)
        self.assertEqual([doc.id for doc in self.working_runs()], [restarted["proposal"].id])

        # The stale run's task, reaching the queue's front late, leaves it failed and asks nothing.
        GenerateReorganizeProposal.apply(kwargs=self.queued.pop(0), throw=True)
        stale.reload()
        self.assertEqual(stale.status, FAILED)
        self.assertEqual(self.model.calls, [])

    def test_two_starts_at_once_leave_one_run(self):
        check = usage.can_start
        racing = [True]
        competing = []

        def another_start_between_check_and_save(user):
            verdict = check(user)
            if racing:
                racing.clear()
                competing.append(start_proposal(user, "tidy", False, "", "en"))
            return verdict

        with patch.object(usage, "can_start", another_start_between_check_and_save):
            late = self.start()

        self.assertEqual(competing[0]["code"], tasks.STARTED)
        self.assertEqual(late, {"code": usage.ALREADY_RUNNING, "next_date": None})
        self.assertEqual([doc.id for doc in self.working_runs()], [competing[0]["proposal"].id])
        self.assertEqual(len(self.queued), 1)


class Test_Start(TasksTestCase):
    def test_run_that_cannot_be_queued_is_failed_so_another_can_start(self):
        self.apply_async.side_effect = OperationalError("broker is down")

        with self.assertRaises(OperationalError):
            self.start()

        self.assertEqual(list(MReorganizeProposal.objects(user_id=self.user.pk).scalar("status")), [FAILED])
        self.apply_async.side_effect = lambda kwargs=None, **options: self.queued.append(kwargs)
        self.assertEqual(self.start()["code"], tasks.STARTED)

    def test_unknown_level_is_refused_without_saving_a_run(self):
        self.assertEqual(self.start(level="everything"), {"code": tasks.UNKNOWN_LEVEL})

        self.assertEqual(MReorganizeProposal.objects(user_id=self.user.pk).count(), 0)
