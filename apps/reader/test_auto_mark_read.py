"""Tests for the per-folder auto mark read setting: saved by save_folder_auto_mark_read in
apps/reader/views.py and resolved for each site by UserSubscription in apps/reader/models.py."""

import json
import time

import redis
from django.conf import settings
from django.contrib.auth.models import User
from django.test import TestCase
from django.urls import reverse

from apps.reader.models import (
    MFolderAutoMarkRead,
    UserSubscription,
    UserSubscriptionFolders,
)
from apps.rss_feeds.models import Feed


class Test_FolderAutoMarkRead(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username="marker", password="test")
        profile = self.user.profile
        profile.is_premium = True
        profile.is_archive = True
        profile.save()
        MFolderAutoMarkRead.objects(user_id=self.user.pk).delete()
        self.addCleanup(MFolderAutoMarkRead.objects(user_id=self.user.pk).delete)

        self.blogs_site = self.subscribe("blogs")
        self.people_site = self.subscribe("people")
        folders = [{"Blogs": [self.blogs_site.feed_id, {"People": [self.people_site.feed_id]}]}]
        UserSubscriptionFolders.objects.create(user=self.user, folders=json.dumps(folders))
        self.client.login(username="marker", password="test")

    def subscribe(self, name, feed_id=None):
        feed = Feed.objects.create(
            pk=feed_id,
            feed_address="https://example.com/%s.xml" % name,
            feed_link="https://example.com/%s" % name,
            feed_title=name,
        )
        return UserSubscription.objects.create(user=self.user, feed=feed, active=True)

    def arrange(self, folders):
        UserSubscriptionFolders.objects.filter(user=self.user).update(folders=json.dumps(folders))

    def save_setting(self, folder_title, days):
        """Save a folder's setting the way the web client does, under the folder's own name."""
        response = self.client.post(
            reverse("save-folder-auto-mark-read"),
            {"folder_title": folder_title, "auto_mark_read_days": days},
        )
        self.assertEqual(json.loads(response.content)["code"], 1)

    def effective_days(self, subscription):
        days, source = UserSubscription.objects.get(pk=subscription.pk).get_effective_auto_mark_read_days()
        return days, source.split(":")[0]

    def test_setting_saved_on_a_nested_folder_applies_to_its_sites(self):
        self.save_setting("People", 3)

        self.assertEqual(self.effective_days(self.people_site), (3, "folder"))
        self.assertNotEqual(self.effective_days(self.blogs_site)[1], "folder")

    def test_saving_a_nested_folder_setting_recounts_its_sites(self):
        UserSubscription.objects.filter(user=self.user).update(needs_unread_recalc=False)

        self.save_setting("People", 3)

        self.assertTrue(UserSubscription.objects.get(pk=self.people_site.pk).needs_unread_recalc)
        self.assertFalse(UserSubscription.objects.get(pk=self.blogs_site.pk).needs_unread_recalc)

    def test_nested_folder_setting_beats_its_parent(self):
        self.save_setting("Blogs", 10)
        self.save_setting("People", 3)

        self.assertEqual(self.effective_days(self.people_site), (3, "folder"))
        self.assertEqual(self.effective_days(self.blogs_site), (10, "folder"))

    def test_never_on_a_nested_folder_beats_its_parent(self):
        self.save_setting("Blogs", 10)
        self.save_setting("People", 0)

        self.assertEqual(self.effective_days(self.people_site), (None, "folder"))

    def test_parent_setting_reaches_sites_in_nested_folders(self):
        self.save_setting("Blogs", 10)

        self.assertEqual(self.effective_days(self.people_site), (10, "folder"))

    def test_setting_saved_under_the_full_path_applies(self):
        MFolderAutoMarkRead.save_folder_setting(self.user.pk, "Blogs - People", 3)

        self.assertEqual(self.effective_days(self.people_site), (3, "folder"))

    def test_folders_with_the_same_own_name_share_its_setting(self):
        work_people_site = self.subscribe("work-people")
        other_people_site = self.subscribe("other-people")
        self.arrange(
            [
                {"Blogs": [self.blogs_site.feed_id, {"People": [self.people_site.feed_id]}]},
                {
                    "Work": [
                        {"People": [work_people_site.feed_id]},
                        {"Other People": [other_people_site.feed_id]},
                    ]
                },
            ]
        )
        UserSubscription.objects.filter(user=self.user).update(needs_unread_recalc=False)

        self.save_setting("People", 3)

        self.assertEqual(self.effective_days(self.people_site), (3, "folder"))
        self.assertEqual(self.effective_days(work_people_site), (3, "folder"))
        self.assertNotEqual(self.effective_days(other_people_site)[1], "folder")
        recounted = UserSubscription.objects.filter(user=self.user, needs_unread_recalc=True)
        self.assertEqual(
            set(recounted.values_list("feed_id", flat=True)),
            {self.people_site.feed_id, work_people_site.feed_id},
        )

    def test_full_path_setting_beats_own_name_setting(self):
        self.save_setting("People", 3)
        MFolderAutoMarkRead.save_folder_setting(self.user.pk, "Blogs - People", 7)

        self.assertEqual(self.effective_days(self.people_site), (7, "folder"))

    def test_settings_reach_a_folder_three_levels_deep(self):
        friends_site = self.subscribe("friends")
        people_folder = {"People": [self.people_site.feed_id, {"Friends": [friends_site.feed_id]}]}
        self.arrange([{"Blogs": [self.blogs_site.feed_id, people_folder]}])
        UserSubscription.objects.filter(user=self.user).update(needs_unread_recalc=False)

        self.save_setting("People", 5)

        self.assertEqual(self.effective_days(friends_site), (5, "folder"))
        self.assertTrue(UserSubscription.objects.get(pk=friends_site.pk).needs_unread_recalc)

        self.save_setting("Friends", 2)

        self.assertEqual(self.effective_days(friends_site), (2, "folder"))
        self.assertEqual(self.effective_days(self.people_site), (5, "folder"))

    def test_story_lists_use_the_nested_folder_setting(self):
        """story_hashes and unread_story_hashes_for_story_hashes load folder settings for many
        sites at once; they must give a nested folder's sites the same cutoff as a single site."""
        # The dev server shares this Redis, so these sites take ids far above any local feed
        # to keep their story keys apart from its feeds' keys.
        blogs_site = self.subscribe("listed-blogs", feed_id=2_000_000_001)
        people_site = self.subscribe("listed-people", feed_id=2_000_000_002)
        self.arrange([{"Blogs": [blogs_site.feed_id, {"People": [people_site.feed_id]}]}])
        self.save_setting("People", 3)
        r = redis.Redis(connection_pool=settings.REDIS_STORY_HASH_POOL)
        people_recent = "%s:amrnew" % people_site.feed_id
        people_old = "%s:amrold" % people_site.feed_id
        blogs_old = "%s:amrold" % blogs_site.feed_id
        for story_hash, age_days in ((people_recent, 1), (people_old, 5), (blogs_old, 5)):
            feed_stories_key = "zF:%s" % story_hash.split(":")[0]
            r.zadd(feed_stories_key, {story_hash: int(time.time()) - age_days * 24 * 60 * 60})
            self.addCleanup(r.delete, feed_stories_key)
        for site in (people_site, blogs_site):
            unread_stories_key = "zU:%s:%s" % (self.user.pk, site.feed_id)
            r.delete(unread_stories_key)
            self.addCleanup(r.delete, unread_stories_key)

        listed = UserSubscription.story_hashes(
            self.user.pk,
            feed_ids=[people_site.feed_id, blogs_site.feed_id],
            read_filter="unread",
        )
        checked = UserSubscription.unread_story_hashes_for_story_hashes(
            self.user.pk, [people_recent, people_old, blogs_old]
        )

        self.assertEqual(set(listed), {people_recent, blogs_old})
        self.assertEqual(set(checked), {people_recent, blogs_old})
