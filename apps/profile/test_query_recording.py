from django.db import connection
from django.http import HttpResponse
from django.test import RequestFactory, TestCase, override_settings

from apps.profile.middleware import SQLLogToConsoleMiddleware
from apps.rss_feeds.models import MStory


@override_settings(DEBUG_QUERIES=False)
class Test_QueryRecordingOnlyWhileProfiling(TestCase):
    """The Mongo command monitor (utils/mongo_command_monitor.py) appended every command to
    connection.queriesx in every process, profiled or not, and only a profiled request or task
    ever emptied it, so the list grew for the life of each web and task worker. A 3 GB task server
    ran out of memory during manage.py trim_feeds. apps/profile/test_query_recording.py"""

    def setUp(self):
        connection.queriesx = None
        self.addCleanup(setattr, connection, "queriesx", None)

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
