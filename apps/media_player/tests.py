import json

from django.contrib.auth.models import User
from django.test import TestCase
from django.test.client import Client

from apps.media_player.models import MMediaPlaybackState

USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) MediaPlayerTests"


class Test_SharedListenQueue(TestCase):
    """The Listen queue lives in the media player state so web, iOS, Mac and Android share it."""

    def setUp(self):
        User.objects.create_user("queuer", "queuer@example.com", "password")
        self.client = Client(HTTP_USER_AGENT=USER_AGENT)
        self.client.login(username="queuer", password="password")
        MMediaPlaybackState.drop_collection()

    def queue_story(self, story_hash, title):
        return json.loads(
            self.client.post(
                "/media_player/add_to_media_queue",
                {
                    "story_hash": story_hash,
                    "media_url": f"/listen/story/{story_hash}",
                    "media_type": "listen",
                    "media_title": title,
                    "feed_id": 900,
                },
            ).content
        )

    def test_a_queued_story_is_read_back_in_order(self):
        self.queue_story("900:one", "First")
        self.queue_story("900:two", "Second")
        state = json.loads(self.client.get("/media_player/playback_state").content)["playback_state"]
        self.assertEqual([item["story_hash"] for item in state["queue"]], ["900:one", "900:two"])
        self.assertEqual(state["queue"][0]["media_type"], "listen")

    def test_no_state_yet_reads_as_none(self):
        response = json.loads(self.client.get("/media_player/playback_state").content)
        self.assertIsNone(response["playback_state"])
