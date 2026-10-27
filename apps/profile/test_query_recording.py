from unittest.mock import patch

from django.conf import settings
from django.db import connection, reset_queries
from django.http import HttpResponse
from django.test import RequestFactory, TestCase, override_settings

from apps.profile.middleware import DBProfilerMiddleware, SQLLogToConsoleMiddleware
from apps.rss_feeds.models import Feed, MStory


@override_settings(DEBUG_QUERIES=False)
class Test_QueryRecordingOnlyWhileProfiling(TestCase):
    """The Mongo command monitor (utils/mongo_command_monitor.py) appended every command to
    connection.queriesx in every process, profiled or not, and only a profiled request or task
    ever emptied it, so the list grew for the life of each web and task worker. A 3 GB task server
    ran out of memory during manage.py trim_feeds. apps/profile/test_query_recording.py"""

    def setUp(self):
        connection.queriesx = None
        self.addCleanup(setattr, connection, "queriesx", None)
        reset_queries()

    def _request(self, profiled):
        request = RequestFactory().get("/reader/feed/1")
        request.activated_segments = ["db_profiler"] if profiled else []
        return request

    def _view_runs_a_mongo_query(self, request):
        MStory.objects(story_feed_id=0).count()
        return HttpResponse("ok")

    def test_an_unprofiled_request_records_nothing(self):
        middleware = SQLLogToConsoleMiddleware(self._view_runs_a_mongo_query)

        middleware(self._request(profiled=False))

        self.assertIsNone(connection.queriesx)

    # DBProfilerMiddleware turns DEBUG on for a profiled request, so its SQL queries are logged too.
    @override_settings(DEBUG=True)
    def test_a_profiled_request_records_its_queries_and_then_stops(self):
        from django.contrib.auth.models import User

        recorded = []

        def view(request):
            User.objects.count()
            response = self._view_runs_a_mongo_query(request)
            recorded.extend(connection.queriesx)
            return response

        middleware = SQLLogToConsoleMiddleware(view)

        middleware(self._request(profiled=True))

        # The first query on a collection also ensures its indexes, so count collections, not commands.
        self.assertEqual({q["mongo"]["collection"] for q in recorded}, {"stories"})
        # Read by process_response and turned off, so the next unprofiled request keeps nothing.
        self.assertIsNone(connection.queriesx)
        MStory.objects(story_feed_id=0).count()
        self.assertIsNone(connection.queriesx)

    def test_a_profiled_request_that_ran_no_sql_still_turns_recording_off(self):
        middleware = SQLLogToConsoleMiddleware(self._view_runs_a_mongo_query)

        middleware(self._request(profiled=True))

        self.assertIsNone(connection.queriesx)
        MStory.objects(story_feed_id=0).count()
        self.assertIsNone(connection.queriesx)


# DEBUG is restored with the settings when each test ends, along with the ORIGINAL_DEBUG the profiler sets.
@override_settings(DEBUG_QUERIES=False, DEBUG=False)
@patch("apps.rss_feeds.tasks.RedisDumpMiddleware")
class Test_UpdateFeedsQueryRecording(TestCase):
    """A profiled UpdateFeeds task reads and turns off recording after each feed, so each feed
    has to turn it on for its own queries, and a feed that raises must not leave it on for every
    later task on the worker. apps/profile/test_query_recording.py"""

    def setUp(self):
        connection.queriesx = None
        self.addCleanup(setattr, connection, "queriesx", None)
        self.feeds = [
            Feed.objects.create(
                feed_address="https://rss.example.com/profiled-%s.xml" % number,
                feed_link="https://www.example.com/profiled-%s" % number,
                feed_title="Profiled %s" % number,
            )
            for number in range(2)
        ]

    def _profiled(self):
        # Stands in for the 1% of tasks DBProfilerMiddleware.process_celery samples, which also turns
        # DEBUG on so the task's SQL is logged.
        def process_celery(profiler):
            profiler.activated_segments = ["db_profiler"]
            setattr(settings, "ORIGINAL_DEBUG", settings.DEBUG)
            settings.DEBUG = True
            return profiler

        return patch.object(DBProfilerMiddleware, "process_celery", process_celery)

    def test_each_feed_of_a_profiled_task_records_its_own_queries(self, mock_redis_middleware):
        from apps.rss_feeds.tasks import UpdateFeeds

        recorded = []
        process_response = SQLLogToConsoleMiddleware.process_response

        def reading_each_feed(middleware, request, response):
            recorded.append({q["mongo"]["collection"] for q in connection.queriesx or []})
            return process_response(middleware, request, response)

        def update(feed, **options):
            MStory.objects(story_feed_id=feed.pk).count()

        with self._profiled(), patch.object(Feed, "update", update), patch.object(
            SQLLogToConsoleMiddleware, "process_response", reading_each_feed
        ):
            UpdateFeeds([feed.pk for feed in self.feeds])

        self.assertEqual(recorded, [{"stories"}, {"stories"}])
        self.assertIsNone(connection.queriesx)
        self.assertFalse(settings.DEBUG)

    def test_a_feed_that_raises_still_turns_recording_off(self, mock_redis_middleware):
        from apps.rss_feeds.tasks import UpdateFeeds

        def update(feed, **options):
            MStory.objects(story_feed_id=feed.pk).count()
            raise ValueError("The fetch blew up")

        with self._profiled(), patch.object(Feed, "update", update):
            with self.assertRaises(ValueError):
                UpdateFeeds([self.feeds[0].pk])

        self.assertIsNone(connection.queriesx)
        self.assertFalse(settings.DEBUG)
