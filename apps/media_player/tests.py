import json
from unittest.mock import patch

import redis
from django.conf import settings
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


class Test_SyncPlaybackPosition(TestCase):
    """The mobile apps' 10 second position updates write Redis only, like the web's media:sync websocket."""

    def setUp(self):
        self.user = User.objects.create_user("syncer", "syncer@example.com", "password")
        self.client = Client(HTTP_USER_AGENT=USER_AGENT)
        self.client.login(username="syncer", password="password")
        MMediaPlaybackState.drop_collection()
        self.redis = redis.Redis(connection_pool=settings.REDIS_PUBSUB_POOL)
        self.redis_key = f"media:playback:{self.user.pk}"
        self.redis.delete(self.redis_key)
        self.addCleanup(self.redis.delete, self.redis_key)
        self.client.post(
            "/media_player/save_playback_state",
            {
                "current_story_hash": "900:pod",
                "current_media_url": "https://example.com/episode.mp3",
                "current_media_type": "podcast",
                "current_position": 0,
                "is_playing": "true",
            },
        )

    def sync(self, **fields):
        return json.loads(self.client.post("/media_player/sync_playback_position", fields).content)

    def test_position_reaches_the_shared_state_without_touching_mongo(self):
        response = self.sync(media_url="https://example.com/episode.mp3", position=125.5, duration=3600)
        self.assertEqual(response["code"], 1)

        state = MMediaPlaybackState.get_state_with_redis_position(self.user.pk)
        self.assertEqual(state["current_position"], 125.5)
        self.assertEqual(state["current_duration"], 3600.0)
        self.assertEqual(MMediaPlaybackState.get_user(self.user.pk).current_position, 0)

    def test_a_stale_item_cannot_move_the_current_items_position(self):
        response = self.sync(media_url="https://example.com/older-episode.mp3", position=900)
        self.assertEqual(response["code"], -1)
        state = MMediaPlaybackState.get_state_with_redis_position(self.user.pk)
        self.assertEqual(state["current_position"], 0)

    def test_bad_requests_are_retryable_not_a_takeover(self):
        # Code -1 tells the apps another device took over and stops their syncing, so it's kept for that.
        self.assertEqual(
            json.loads(self.client.get("/media_player/sync_playback_position").content)["code"], 0
        )
        response = self.sync(media_url="https://example.com/episode.mp3", position="soon")
        self.assertEqual(response["code"], 0)

    def test_a_redis_failure_is_retryable_not_a_takeover(self):
        with patch("redis.Redis.transaction", side_effect=redis.ConnectionError("down")):
            response = self.sync(media_url="https://example.com/episode.mp3", position=125.5)
        self.assertEqual(response["code"], 0)
        self.assertEqual(self.sync(media_url="https://example.com/episode.mp3", position=130)["code"], 1)

    def test_an_item_switch_after_the_check_keeps_the_old_items_position_out(self):
        # Another device's save of a new item lands between this sync's MongoDB check and its Redis write.
        real_transaction = redis.Redis.transaction

        def save_next_item_then_write(redis_client, *args, **kwargs):
            self.client.post(
                "/media_player/save_playback_state",
                {"current_media_url": "https://example.com/next.mp3", "current_position": 5},
            )
            return real_transaction(redis_client, *args, **kwargs)

        with patch.object(redis.Redis, "transaction", autospec=True, side_effect=save_next_item_then_write):
            response = self.sync(media_url="https://example.com/episode.mp3", position=900)
        self.assertEqual(response["code"], -1)
        self.assertEqual(self.redis.hget(self.redis_key, "position"), "5.0")
        state = MMediaPlaybackState.get_state_with_redis_position(self.user.pk)
        self.assertEqual(state["current_position"], 5.0)

    def test_a_stale_hash_left_by_a_failed_redis_write_does_not_stop_syncing(self):
        # Episode B became current in MongoDB, but save_playback_state's Redis write failed, so the hash still
        # names the episode before it. B's syncs must replace that hash, not be refused as a takeover.
        self.redis.hset(
            self.redis_key, mapping={"media_url": "https://example.com/older.mp3", "position": "500"}
        )
        response = self.sync(media_url="https://example.com/episode.mp3", position=42)
        self.assertEqual(response["code"], 1)
        self.assertEqual(self.redis.hget(self.redis_key, "media_url"), "https://example.com/episode.mp3")
        state = MMediaPlaybackState.get_state_with_redis_position(self.user.pk)
        self.assertEqual(state["current_position"], 42)

    def test_a_hash_naming_another_item_is_not_applied(self):
        self.redis.hset(
            self.redis_key, mapping={"media_url": "https://example.com/older.mp3", "position": "500"}
        )
        state = MMediaPlaybackState.get_state_with_redis_position(self.user.pk)
        self.assertEqual(state["current_position"], 0)

    def test_a_new_item_does_not_inherit_the_previous_items_position(self):
        self.sync(media_url="https://example.com/episode.mp3", position=125.5, duration=3600)
        self.client.post(
            "/media_player/save_playback_state",
            {"current_media_url": "https://example.com/next.mp3", "current_media_type": "podcast"},
        )
        state = MMediaPlaybackState.get_state_with_redis_position(self.user.pk)
        self.assertEqual(state["current_media_url"], "https://example.com/next.mp3")
        self.assertEqual(state["current_position"], 0)
        self.assertEqual(self.redis.hget(self.redis_key, "media_url"), "https://example.com/next.mp3")

    def test_requires_login(self):
        anonymous = Client(HTTP_USER_AGENT=USER_AGENT)
        response = anonymous.post(
            "/media_player/sync_playback_position",
            {"media_url": "https://example.com/episode.mp3", "position": 10},
        )
        self.assertEqual(response.status_code, 403)
