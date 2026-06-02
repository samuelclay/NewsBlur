from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase
from django.test.client import Client
from django.urls import reverse

from apps.social.models import MInteraction, MSocialProfile
from utils import json_functions as json


class Test_Interactions(TestCase):
    def setUp(self):
        self.email_patcher = patch("apps.profile.tasks.EmailNewPremiumTrial.delay")
        self.email_patcher.start()
        self.client = Client(HTTP_USER_AGENT="Mozilla/5.0")
        self.owner = User.objects.create_user(username="interaction-owner", password="password")
        self.attacker = User.objects.create_user(username="interaction-attacker", password="password")
        self.other_user = User.objects.create_user(username="interaction-other", password="password")
        self.interaction = MInteraction.objects.create(
            user_id=self.owner.pk,
            with_user_id=self.attacker.pk,
            category="follow",
            title="Interaction test",
            content="attacker followed owner",
        )

    def tearDown(self):
        user_ids = [self.owner.pk, self.attacker.pk, self.other_user.pk]
        MInteraction.objects.filter(user_id__in=user_ids).delete()
        MInteraction.objects.filter(with_user_id__in=user_ids).delete()
        MSocialProfile.objects.filter(user_id__in=user_ids).delete()
        self.email_patcher.stop()

    def test_load_interactions_denies_other_user(self):
        self.client.force_login(self.attacker)

        response = self.client.get(reverse("social-interactions"), {"user_id": self.owner.pk})
        data = json.decode(response.content)

        self.assertEqual(data["code"], -1)
        self.assertEqual(data["message"], "Access denied.")

    def test_load_interactions_allows_current_user(self):
        self.client.force_login(self.owner)

        response = self.client.get(reverse("social-interactions"), {"user_id": self.owner.pk})
        data = json.decode(response.content)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(data["interactions"]), 1)
        self.assertEqual(data["interactions"][0]["content"], "attacker followed owner")

    def test_load_interactions_defaults_to_current_user(self):
        self.client.force_login(self.owner)

        response = self.client.get(reverse("social-interactions"))
        data = json.decode(response.content)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(data["interactions"]), 1)
        self.assertEqual(data["interactions"][0]["content"], "attacker followed owner")

    def test_load_river_blurblog_denies_other_relative_user(self):
        self.client.force_login(self.attacker)

        response = self.client.get(reverse("social-river-blurblog"), {"relative_user_id": self.owner.pk})
        data = json.decode(response.content)

        self.assertEqual(data["code"], -1)
        self.assertEqual(data["message"], "Access denied.")

    def test_story_public_comments_denies_other_relative_user(self):
        self.client.force_login(self.attacker)

        response = self.client.get(
            reverse("story-public-comments"),
            {"feed_id": 1, "story_id": "test-story", "user_id": self.owner.pk},
        )
        data = json.decode(response.content)

        self.assertEqual(data["code"], -1)
        self.assertEqual(data["message"], "Access denied.")

    def test_profile_hides_private_follow_lists_from_non_follower(self):
        owner_profile = MSocialProfile.get_user(self.owner.pk)
        owner_profile.private = True
        owner_profile.following_user_ids = [self.owner.pk, self.other_user.pk]
        owner_profile.follower_user_ids = [self.owner.pk, self.other_user.pk]
        owner_profile.save()
        self.client.force_login(self.attacker)

        response = self.client.get(reverse("profile"), {"user_id": self.owner.pk})
        data = json.decode(response.content)

        self.assertNotIn("following_user_ids", data["user_profile"])
        self.assertNotIn("follower_user_ids", data["user_profile"])
        self.assertEqual(data["following_youknow"], [])
        self.assertEqual(data["following_everybody"], [])
        self.assertEqual(data["followers_youknow"], [])
        self.assertEqual(data["followers_everybody"], [])
        self.assertEqual(data["activities"], [])

    def test_profile_allows_private_follow_lists_to_owner(self):
        owner_profile = MSocialProfile.get_user(self.owner.pk)
        owner_profile.private = True
        owner_profile.following_user_ids = [self.owner.pk, self.other_user.pk]
        owner_profile.follower_user_ids = [self.owner.pk, self.other_user.pk]
        owner_profile.save()
        self.client.force_login(self.owner)

        response = self.client.get(reverse("profile"), {"user_id": self.owner.pk})
        data = json.decode(response.content)

        self.assertIn(self.other_user.pk, data["user_profile"]["following_user_ids"])
        self.assertIn(self.other_user.pk, data["user_profile"]["follower_user_ids"])
