"""
URL tests for the social app.

Tests URL resolution and basic access patterns for all social endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_SocialURLResolution(TransactionTestCase):
    """Test that all social URLs resolve correctly."""

    def test_river_blurblog_resolves(self):
        """Test river blurblog URL resolves."""
        url = reverse("social-river-blurblog")
        resolved = resolve(url)
        assert resolved.view_name == "social-river-blurblog"

    def test_mark_story_as_shared_resolves(self):
        """Test mark story as shared URL resolves."""
        url = reverse("mark-story-as-shared")
        resolved = resolve(url)
        assert resolved.view_name == "mark-story-as-shared"

    def test_mark_story_as_unshared_resolves(self):
        """Test mark story as unshared URL resolves."""
        url = reverse("mark-story-as-unshared")
        resolved = resolve(url)
        assert resolved.view_name == "mark-story-as-unshared"

    def test_load_user_friends_resolves(self):
        """Test load user friends URL resolves."""
        url = reverse("load-user-friends")
        resolved = resolve(url)
        assert resolved.view_name == "load-user-friends"

    def test_load_follow_requests_resolves(self):
        """Test load follow requests URL resolves."""
        url = reverse("load-follow-requests")
        resolved = resolve(url)
        assert resolved.view_name == "load-follow-requests"

    def test_profile_resolves(self):
        """Test profile URL resolves."""
        url = reverse("profile")
        resolved = resolve(url)
        assert resolved.view_name == "profile"

    def test_load_user_profile_resolves(self):
        """Test load user profile URL resolves."""
        url = reverse("load-user-profile")
        resolved = resolve(url)
        assert resolved.view_name == "load-user-profile"

    def test_save_user_profile_resolves(self):
        """Test save user profile URL resolves."""
        url = reverse("save-user-profile")
        resolved = resolve(url)
        assert resolved.view_name == "save-user-profile"

    def test_upload_avatar_resolves(self):
        """Test upload avatar URL resolves."""
        url = reverse("upload-avatar")
        resolved = resolve(url)
        assert resolved.view_name == "upload-avatar"

    def test_save_blurblog_settings_resolves(self):
        """Test save blurblog settings URL resolves."""
        url = reverse("save-blurblog-settings")
        resolved = resolve(url)
        assert resolved.view_name == "save-blurblog-settings"

    def test_social_interactions_resolves(self):
        """Test social interactions URL resolves."""
        url = reverse("social-interactions")
        resolved = resolve(url)
        assert resolved.view_name == "social-interactions"

    def test_social_activities_resolves(self):
        """Test social activities URL resolves."""
        url = reverse("social-activities")
        resolved = resolve(url)
        assert resolved.view_name == "social-activities"

    def test_social_follow_resolves(self):
        """Test social follow URL resolves."""
        url = reverse("social-follow")
        resolved = resolve(url)
        assert resolved.view_name == "social-follow"

    def test_social_unfollow_resolves(self):
        """Test social unfollow URL resolves."""
        url = reverse("social-unfollow")
        resolved = resolve(url)
        assert resolved.view_name == "social-unfollow"

    def test_social_approve_follower_resolves(self):
        """Test social approve follower URL resolves."""
        url = reverse("social-approve-follower")
        resolved = resolve(url)
        assert resolved.view_name == "social-approve-follower"

    def test_social_ignore_follower_resolves(self):
        """Test social ignore follower URL resolves."""
        url = reverse("social-ignore-follower")
        resolved = resolve(url)
        assert resolved.view_name == "social-ignore-follower"

    def test_social_mute_user_resolves(self):
        """Test social mute user URL resolves."""
        url = reverse("social-mute-user")
        resolved = resolve(url)
        assert resolved.view_name == "social-mute-user"

    def test_social_unmute_user_resolves(self):
        """Test social unmute user URL resolves."""
        url = reverse("social-unmute-user")
        resolved = resolve(url)
        assert resolved.view_name == "social-unmute-user"

    def test_social_feed_trainer_resolves(self):
        """Test social feed trainer URL resolves."""
        url = reverse("social-feed-trainer")
        resolved = resolve(url)
        assert resolved.view_name == "social-feed-trainer"

    def test_story_public_comments_resolves(self):
        """Test story public comments URL resolves."""
        url = reverse("story-public-comments")
        resolved = resolve(url)
        assert resolved.view_name == "story-public-comments"

    def test_social_save_comment_reply_resolves(self):
        """Test social save comment reply URL resolves."""
        url = reverse("social-save-comment-reply")
        resolved = resolve(url)
        assert resolved.view_name == "social-save-comment-reply"

    def test_social_remove_comment_reply_resolves(self):
        """Test social remove comment reply URL resolves."""
        url = reverse("social-remove-comment-reply")
        resolved = resolve(url)
        assert resolved.view_name == "social-remove-comment-reply"

    def test_social_find_friends_resolves(self):
        """Test social find friends URL resolves."""
        url = reverse("social-find-friends")
        resolved = resolve(url)
        assert resolved.view_name == "social-find-friends"

    def test_social_like_comment_resolves(self):
        """Test social like comment URL resolves."""
        url = reverse("social-like-comment")
        resolved = resolve(url)
        assert resolved.view_name == "social-like-comment"

    def test_social_remove_like_comment_resolves(self):
        """Test social remove like comment URL resolves."""
        url = reverse("social-remove-like-comment")
        resolved = resolve(url)
        assert resolved.view_name == "social-remove-like-comment"

    def test_social_comment_reply_resolves(self):
        """Test social comment reply URL resolves."""
        url = reverse("social-comment-reply", kwargs={"comment_id": "abc123", "reply_id": "def456"})
        resolved = resolve(url)
        assert resolved.view_name == "social-comment-reply"

    def test_social_comment_resolves(self):
        """Test social comment URL resolves."""
        url = reverse("social-comment", kwargs={"comment_id": "abc123"})
        resolved = resolve(url)
        assert resolved.view_name == "social-comment"

    def test_shared_stories_rss_feed_resolves(self):
        """Test shared stories RSS feed URL resolves."""
        url = reverse("shared-stories-rss-feed", kwargs={"user_id": "1"})
        resolved = resolve(url)
        assert resolved.view_name == "shared-stories-rss-feed"

    def test_load_social_stories_resolves(self):
        """Test load social stories URL resolves."""
        url = reverse("load-social-stories", kwargs={"user_id": "1", "username": "testuser"})
        resolved = resolve(url)
        assert resolved.view_name == "load-social-stories"

    def test_load_social_page_resolves(self):
        """Test load social page URL resolves."""
        url = reverse("load-social-page", kwargs={"user_id": "1", "username": "testuser"})
        resolved = resolve(url)
        assert resolved.view_name == "load-social-page"

    def test_load_social_settings_resolves(self):
        """Test load social settings URL resolves."""
        url = reverse("load-social-settings", kwargs={"social_user_id": "1", "username": "testuser"})
        resolved = resolve(url)
        assert resolved.view_name == "load-social-settings"

    def test_load_social_statistics_resolves(self):
        """Test load social statistics URL resolves."""
        url = reverse("load-social-statistics", kwargs={"social_user_id": "1"})
        resolved = resolve(url)
        assert resolved.view_name == "load-social-statistics"

    def test_social_mute_story_resolves(self):
        """Test social mute story URL resolves."""
        url = reverse("social-mute-story", kwargs={"secret_token": "abc123", "shared_story_id": "def456"})
        resolved = resolve(url)
        assert resolved.view_name == "social-mute-story"

    def test_shared_stories_public_resolves(self):
        """Test shared stories public URL resolves."""
        url = reverse("shared-stories-public", kwargs={"username": "testuser"})
        resolved = resolve(url)
        assert resolved.view_name == "shared-stories-public"


class Test_SocialURLAccess(TransactionTestCase):
    """Test access patterns for social URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")
        # Create "popular" user required by recommended_users() in load_user_friends
        User.objects.create_user(username="popular", password="popular", email="popular@test.com")

    def test_river_blurblog_authenticated(self):
        """Test authenticated access to river blurblog."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("social-river-blurblog"))
        assert response.status_code == 200

    def test_load_user_friends_authenticated(self):
        """Test authenticated access to load user friends."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("load-user-friends"))
        assert response.status_code == 200

    def test_load_follow_requests_authenticated(self):
        """Test authenticated access to load follow requests."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("load-follow-requests"))
        assert response.status_code == 200

    def test_profile_authenticated(self):
        """Test authenticated access to profile."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("profile"))
        assert response.status_code == 200

    def test_load_user_profile_authenticated(self):
        """Test authenticated access to load user profile."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("load-user-profile"))
        assert response.status_code == 200

    def test_social_interactions_authenticated(self):
        """Test authenticated access to social interactions."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("social-interactions"))
        assert response.status_code == 200

    def test_social_activities_authenticated(self):
        """Test authenticated access to social activities."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("social-activities"))
        assert response.status_code == 200

    def test_social_find_friends_authenticated(self):
        """Test authenticated access to find friends."""
        self.client.login(username="testuser", password="testpass")
        # Endpoint requires 'query' parameter
        response = self.client.get(
            reverse("social-find-friends"), {"query": "test"}, HTTP_USER_AGENT="TestBrowser/1.0"
        )
        assert response.status_code == 200

    def test_shared_stories_public_anonymous(self):
        """Test anonymous access to shared stories public."""
        response = self.client.get(reverse("shared-stories-public", kwargs={"username": "testuser"}))
        assert response.status_code in [200, 302, 404]


class Test_SocialURLPOST(TransactionTestCase):
    """Test POST endpoints for social URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")
        self.user2 = User.objects.create_user(username="testuser2", password="testpass", email="test2@test.com")

    def test_save_user_profile_post(self):
        """Test POST to save user profile and verify database persistence."""
        from apps.social.models import MSocialProfile

        self.client.login(username="testuser", password="testpass")

        # Create profile if it doesn't exist
        MSocialProfile.get_user(self.user.pk)

        response = self.client.post(
            reverse("save-user-profile"),
            {
                "bio": "Test bio",
                "website": "https://example.com",
                "location": "Test Location",
                "photo_service": "nothing",
            },
        )
        assert response.status_code == 200

        # Verify database state
        profile = MSocialProfile.get_user(self.user.pk)
        assert profile.bio == "Test bio"
        assert profile.website == "https://example.com"
        assert profile.location == "Test Location"

    def test_save_blurblog_settings_post(self):
        """Test POST to save blurblog settings."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("save-blurblog-settings"), {"blurblog_title": "Test Title"})
        assert response.status_code in [200, 302, 400]

    def test_social_follow_post(self):
        """Test POST to follow user."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("social-follow"), {"user_id": self.user2.pk})
        assert response.status_code in [200, 302, 400]

    def test_social_unfollow_post(self):
        """Test POST to unfollow user."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("social-unfollow"), {"user_id": self.user2.pk})
        assert response.status_code in [200, 302, 400]

    def test_social_mute_user_post(self):
        """Test POST to mute user."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("social-mute-user"), {"user_id": self.user2.pk})
        assert response.status_code in [200, 302, 400]

    def test_social_unmute_user_post(self):
        """Test POST to unmute user."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("social-unmute-user"), {"user_id": self.user2.pk})
        assert response.status_code in [200, 302, 400]
