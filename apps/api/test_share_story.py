from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase

from apps.api.views import MAX_SHARED_STORY_GUID_BYTES
from apps.social.models import MSharedStory
from utils import json_functions as json


class Test_ShareStoryLongUrl(TestCase):
    """POST /api/share_story/<token>, the bookmarklet's share (apps/api/views.py share_story).
    The shared story's guid is the page's URL and the guid is indexed, so a URL too long for
    an index key (a Google search with all its tracking parameters) failed with a 500."""

    def setUp(self):
        self.user = User.objects.create_user(username="long_url_sharer", password="password")
        self.addCleanup(MSharedStory.objects(user_id=self.user.pk).delete)
        self.long_url = "https://www.google.com/search?q=" + "+".join(["counterintelligence"] * 80)

    def share(self, comments, story_url=None):
        with patch("apps.api.views.Feed.get_feed_from_url", return_value=None):
            response = self.client.post(
                "/api/share_story/%s" % self.user.profile.secret_token,
                {
                    "story_url": story_url or self.long_url,
                    "title": "A long search",
                    "content": "<p>Search results</p>",
                    "comments": comments,
                },
            )
        self.assertEqual(response.status_code, 200)
        return json.decode(response.content)

    def test_page_with_a_url_too_long_to_index_is_shared(self):
        self.share("Worth a read")

        shared_story = MSharedStory.objects.get(user_id=self.user.pk)
        self.assertEqual(shared_story.story_permalink, self.long_url)

    def test_sharing_the_same_long_url_again_updates_the_share(self):
        self.share("First thought")
        self.share("Second thought")

        shared_story = MSharedStory.objects.get(user_id=self.user.pk)
        self.assertIn("Second thought", shared_story.comments)

    def test_longest_url_kept_as_the_guid_still_fits_the_index(self):
        """Shares made before long URLs were hashed are found again by their URL, so every URL
        that fit the index keeps the URL as its guid. Raising the limit past what MongoDB
        indexes brings the 500 back for the URLs in between."""
        prefix = "https://www.example.com/search?q="
        url_at_the_limit = prefix + "a" * (MAX_SHARED_STORY_GUID_BYTES - len(prefix))

        self.share("At the limit", story_url=url_at_the_limit)

        shared_story = MSharedStory.objects.get(user_id=self.user.pk)
        self.assertEqual(shared_story.story_guid, url_at_the_limit)
