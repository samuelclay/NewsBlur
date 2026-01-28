import datetime

from django.contrib.auth.models import User
from django.test import TestCase
from django.test.client import Client
from django.urls import reverse

from apps.rss_feeds.models import MStarredStory, MStarredStoryCounts
from utils import json_functions as json


class Test_RenameStarredTag(TestCase):
    """Tests for renaming starred story tags."""

    def setUp(self):
        self.client = Client()
        # Create test user
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")
        self.client.login(username="testuser", password="testpass")

        # Clear any existing starred stories for this user
        MStarredStory.objects(user_id=self.user.pk).delete()
        MStarredStoryCounts.objects(user_id=self.user.pk).delete()

        # Create some starred stories with tags
        self.story1 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 1",
            story_guid="guid1",
            user_tags=["oldtag", "othertag"],
        )
        self.story1.save()

        self.story2 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 2",
            story_guid="guid2",
            user_tags=["oldtag"],
        )
        self.story2.save()

        self.story3 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 3",
            story_guid="guid3",
            user_tags=["anothertag"],
        )
        self.story3.save()

        # Count tags to create the counts entries
        MStarredStoryCounts.count_for_user(self.user.pk)

    def tearDown(self):
        MStarredStory.objects(user_id=self.user.pk).delete()
        MStarredStoryCounts.objects(user_id=self.user.pk).delete()

    def test_rename_tag_updates_all_stories(self):
        """Verify all stories with old tag now have new tag."""
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": "newtag"},
        )
        data = json.decode(response.content)

        self.assertEqual(data["code"], 1)

        # Check stories were updated
        story1 = MStarredStory.objects.get(user_id=self.user.pk, story_guid="guid1")
        story2 = MStarredStory.objects.get(user_id=self.user.pk, story_guid="guid2")

        self.assertIn("newtag", story1.user_tags)
        self.assertNotIn("oldtag", story1.user_tags)
        self.assertIn("othertag", story1.user_tags)  # Other tags preserved

        self.assertIn("newtag", story2.user_tags)
        self.assertNotIn("oldtag", story2.user_tags)

    def test_rename_tag_updates_counts(self):
        """Verify MStarredStoryCounts updated correctly."""
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": "newtag"},
        )
        data = json.decode(response.content)

        self.assertEqual(data["code"], 1)

        # Old tag count should not exist
        old_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="oldtag").first()
        self.assertIsNone(old_count)

        # New tag count should exist with correct count
        new_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="newtag").first()
        self.assertIsNotNone(new_count)
        self.assertEqual(new_count.count, 2)

    def test_rename_tag_merge_existing(self):
        """If new tag already exists, counts should merge."""
        # Create a story with the new tag already
        story4 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 4",
            story_guid="guid4",
            user_tags=["existingtag"],
        )
        story4.save()

        # Recount to include the new story
        MStarredStoryCounts.count_for_user(self.user.pk)

        # Verify initial counts
        old_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="oldtag").first()
        existing_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="existingtag").first()
        self.assertEqual(old_count.count, 2)
        self.assertEqual(existing_count.count, 1)

        # Rename oldtag to existingtag (should merge)
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": "existingtag"},
        )
        data = json.decode(response.content)

        self.assertEqual(data["code"], 1)

        # Old tag should not exist
        old_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="oldtag").first()
        self.assertIsNone(old_count)

        # Merged tag should have combined count (2 + 1 = 3)
        merged_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="existingtag").first()
        self.assertIsNotNone(merged_count)
        self.assertEqual(merged_count.count, 3)

    def test_rename_tag_case_insensitive(self):
        """'News' renamed to 'news' should update casing, not create duplicate."""
        # First rename to 'News' (capitalized)
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": "News"},
        )
        data = json.decode(response.content)
        self.assertEqual(data["code"], 1)

        # Now rename 'News' to 'news' (lowercase) - should be same tag, different case
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "News", "new_tag_name": "news"},
        )
        data = json.decode(response.content)
        self.assertEqual(data["code"], 1)

        # Should only have one count entry for 'news'
        news_counts = list(MStarredStoryCounts.objects(user_id=self.user.pk, tag__iexact="news"))
        self.assertEqual(len(news_counts), 1)
        self.assertEqual(news_counts[0].tag, "news")

    def test_rename_tag_requires_auth(self):
        """Ensure endpoint requires login."""
        self.client.logout()
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": "newtag"},
        )
        # Should return 403 Forbidden for AJAX requests (ajax_login_required decorator)
        self.assertEqual(response.status_code, 403)

    def test_rename_tag_empty_name_fails(self):
        """Validation: can't rename to empty string."""
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": ""},
        )
        data = json.decode(response.content)
        self.assertEqual(data["code"], -1)

    def test_rename_tag_whitespace_only_fails(self):
        """Validation: can't rename to whitespace-only string."""
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": "   "},
        )
        data = json.decode(response.content)
        self.assertEqual(data["code"], -1)

    def test_rename_tag_too_long_fails(self):
        """Validation: tag name must be 128 characters or less."""
        long_name = "a" * 129
        response = self.client.post(
            reverse("rename-starred-tag"),
            {"old_tag_name": "oldtag", "new_tag_name": long_name},
        )
        data = json.decode(response.content)
        self.assertEqual(data["code"], -1)


class Test_DeleteStarredTag(TestCase):
    """Tests for deleting starred story tags."""

    def setUp(self):
        self.client = Client()
        # Create test user
        self.user = User.objects.create_user(username="testuser2", password="testpass", email="test2@test.com")
        self.client.login(username="testuser2", password="testpass")

        # Clear any existing starred stories for this user
        MStarredStory.objects(user_id=self.user.pk).delete()
        MStarredStoryCounts.objects(user_id=self.user.pk).delete()

        # Create some starred stories with tags
        self.story1 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 1",
            story_guid="guid1",
            user_tags=["tagtoremove", "othertag"],
        )
        self.story1.save()

        self.story2 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 2",
            story_guid="guid2",
            user_tags=["tagtoremove"],
        )
        self.story2.save()

        self.story3 = MStarredStory(
            user_id=self.user.pk,
            starred_date=datetime.datetime.now(),
            story_feed_id=1,
            story_title="Test Story 3",
            story_guid="guid3",
            user_tags=["anothertag"],
        )
        self.story3.save()

        # Count tags to create the counts entries
        MStarredStoryCounts.count_for_user(self.user.pk)

    def tearDown(self):
        MStarredStory.objects(user_id=self.user.pk).delete()
        MStarredStoryCounts.objects(user_id=self.user.pk).delete()

    def test_delete_tag_removes_from_all_stories(self):
        """Tag removed from user_tags list."""
        response = self.client.post(
            reverse("delete-starred-tag"),
            {"tag_name": "tagtoremove"},
        )
        data = json.decode(response.content)

        self.assertEqual(data["code"], 1)

        # Check stories were updated
        story1 = MStarredStory.objects.get(user_id=self.user.pk, story_guid="guid1")
        story2 = MStarredStory.objects.get(user_id=self.user.pk, story_guid="guid2")

        self.assertNotIn("tagtoremove", story1.user_tags)
        self.assertIn("othertag", story1.user_tags)  # Other tags preserved

        self.assertNotIn("tagtoremove", story2.user_tags)

    def test_delete_tag_stories_remain_saved(self):
        """Stories still exist as starred, just without the tag."""
        response = self.client.post(
            reverse("delete-starred-tag"),
            {"tag_name": "tagtoremove"},
        )
        data = json.decode(response.content)

        self.assertEqual(data["code"], 1)

        # All stories should still exist
        self.assertEqual(MStarredStory.objects(user_id=self.user.pk).count(), 3)

    def test_delete_tag_removes_count(self):
        """MStarredStoryCounts entry deleted."""
        response = self.client.post(
            reverse("delete-starred-tag"),
            {"tag_name": "tagtoremove"},
        )
        data = json.decode(response.content)

        self.assertEqual(data["code"], 1)

        # Tag count should not exist
        tag_count = MStarredStoryCounts.objects(user_id=self.user.pk, tag="tagtoremove").first()
        self.assertIsNone(tag_count)

    def test_delete_tag_requires_auth(self):
        """Ensure endpoint requires login."""
        self.client.logout()
        response = self.client.post(
            reverse("delete-starred-tag"),
            {"tag_name": "tagtoremove"},
        )
        # Should return 403 Forbidden for AJAX requests (ajax_login_required decorator)
        self.assertEqual(response.status_code, 403)

    def test_delete_tag_empty_name_fails(self):
        """Validation: can't delete empty tag name."""
        response = self.client.post(
            reverse("delete-starred-tag"),
            {"tag_name": ""},
        )
        data = json.decode(response.content)
        self.assertEqual(data["code"], -1)

    def test_delete_last_tag_on_story(self):
        """Story remains saved with empty user_tags list."""
        # Delete 'tagtoremove' first
        self.client.post(
            reverse("delete-starred-tag"),
            {"tag_name": "tagtoremove"},
        )

        # Story2 now has no tags - verify it still exists
        story2 = MStarredStory.objects.get(user_id=self.user.pk, story_guid="guid2")
        self.assertIsNotNone(story2)
        self.assertEqual(len(story2.user_tags), 0)
