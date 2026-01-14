"""
URL tests for the reader app.

Tests URL resolution and basic access patterns for all reader endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_ReaderURLResolution(TransactionTestCase):
    """Test that all reader URLs resolve correctly."""

    def test_index_resolves(self):
        """Test reader index URL resolves."""
        url = "/reader/"
        resolved = resolve(url)
        assert resolved.func.__name__ == "index"

    def test_iframe_buster_resolves(self):
        """Test iframe buster URL resolves."""
        url = reverse("iframe-buster")
        resolved = resolve(url)
        assert resolved.view_name == "iframe-buster"

    def test_login_as_resolves(self):
        """Test login_as URL resolves."""
        url = reverse("login_as")
        resolved = resolve(url)
        assert resolved.view_name == "login_as"

    def test_welcome_resolves(self):
        """Test welcome URL resolves."""
        url = reverse("welcome")
        resolved = resolve(url)
        assert resolved.view_name == "welcome"

    def test_logout_resolves(self):
        """Test logout URL resolves."""
        url = reverse("welcome-logout")
        resolved = resolve(url)
        assert resolved.view_name == "welcome-logout"

    def test_login_resolves(self):
        """Test login URL resolves."""
        url = reverse("welcome-login")
        resolved = resolve(url)
        assert resolved.view_name == "welcome-login"

    def test_autologin_resolves(self):
        """Test autologin URL resolves."""
        url = reverse("autologin", kwargs={"username": "testuser", "secret": "abc123"})
        resolved = resolve(url)
        assert resolved.view_name == "autologin"

    def test_signup_resolves(self):
        """Test signup URL resolves."""
        url = reverse("welcome-signup")
        resolved = resolve(url)
        assert resolved.view_name == "welcome-signup"

    def test_load_feeds_resolves(self):
        """Test load feeds URL resolves."""
        url = reverse("load-feeds")
        resolved = resolve(url)
        assert resolved.view_name == "load-feeds"

    def test_load_single_feed_resolves(self):
        """Test load single feed URL resolves."""
        url = reverse("load-single-feed", kwargs={"feed_id": "1"})
        resolved = resolve(url)
        assert resolved.view_name == "load-single-feed"

    def test_load_feed_page_resolves(self):
        """Test load feed page URL resolves."""
        url = reverse("load-feed-page", kwargs={"feed_id": "1"})
        resolved = resolve(url)
        assert resolved.view_name == "load-feed-page"

    def test_refresh_feed_resolves(self):
        """Test refresh feed URL resolves."""
        url = reverse("refresh-feed", kwargs={"feed_id": "1"})
        resolved = resolve(url)
        assert resolved.view_name == "refresh-feed"

    def test_load_feed_favicons_resolves(self):
        """Test load feed favicons URL resolves."""
        url = reverse("load-feed-favicons")
        resolved = resolve(url)
        assert resolved.view_name == "load-feed-favicons"

    def test_load_river_stories_widget_resolves(self):
        """Test load river stories widget URL resolves."""
        url = reverse("load-river-stories-widget")
        resolved = resolve(url)
        assert resolved.view_name == "load-river-stories-widget"

    def test_load_river_stories_resolves(self):
        """Test load river stories URL resolves."""
        url = reverse("load-river-stories")
        resolved = resolve(url)
        assert resolved.view_name == "load-river-stories"

    def test_complete_river_resolves(self):
        """Test complete river URL resolves."""
        url = reverse("complete-river")
        resolved = resolve(url)
        assert resolved.view_name == "complete-river"

    def test_refresh_feeds_resolves(self):
        """Test refresh feeds URL resolves."""
        url = reverse("refresh-feeds")
        resolved = resolve(url)
        assert resolved.view_name == "refresh-feeds"

    def test_interactions_count_resolves(self):
        """Test interactions count URL resolves."""
        url = reverse("interactions-count")
        resolved = resolve(url)
        assert resolved.view_name == "interactions-count"

    def test_feed_unread_count_resolves(self):
        """Test feed unread count URL resolves."""
        url = reverse("feed-unread-count")
        resolved = resolve(url)
        assert resolved.view_name == "feed-unread-count"

    def test_load_starred_stories_resolves(self):
        """Test load starred stories URL resolves."""
        url = reverse("load-starred-stories")
        resolved = resolve(url)
        assert resolved.view_name == "load-starred-stories"

    def test_load_read_stories_resolves(self):
        """Test load read stories URL resolves."""
        url = reverse("load-read-stories")
        resolved = resolve(url)
        assert resolved.view_name == "load-read-stories"

    def test_starred_story_hashes_resolves(self):
        """Test starred story hashes URL resolves."""
        url = reverse("starred-story-hashes")
        resolved = resolve(url)
        assert resolved.view_name == "starred-story-hashes"

    def test_starred_stories_rss_feed_resolves(self):
        """Test starred stories RSS feed URL resolves."""
        url = reverse("starred-stories-rss-feed", kwargs={"user_id": "1", "secret_token": "abc123"})
        resolved = resolve(url)
        assert resolved.view_name == "starred-stories-rss-feed"

    def test_starred_stories_rss_feed_tag_resolves(self):
        """Test starred stories RSS feed tag URL resolves."""
        url = reverse(
            "starred-stories-rss-feed-tag",
            kwargs={"user_id": "1", "secret_token": "abc123", "tag_slug": "test-tag"},
        )
        resolved = resolve(url)
        assert resolved.view_name == "starred-stories-rss-feed-tag"

    def test_folder_rss_feed_resolves(self):
        """Test folder RSS feed URL resolves."""
        url = reverse(
            "folder-rss-feed",
            kwargs={"user_id": "1", "secret_token": "abc123", "unread_filter": "all", "folder_slug": "test-folder"},
        )
        resolved = resolve(url)
        assert resolved.view_name == "folder-rss-feed"

    def test_unread_story_hashes_resolves(self):
        """Test unread story hashes URL resolves."""
        url = reverse("unread-story-hashes")
        resolved = resolve(url)
        assert resolved.view_name == "unread-story-hashes"

    def test_starred_counts_resolves(self):
        """Test starred counts URL resolves."""
        url = reverse("starred-counts")
        resolved = resolve(url)
        assert resolved.view_name == "starred-counts"

    def test_mark_all_as_read_resolves(self):
        """Test mark all as read URL resolves."""
        url = reverse("mark-all-as-read")
        resolved = resolve(url)
        assert resolved.view_name == "mark-all-as-read"

    def test_mark_story_as_read_resolves(self):
        """Test mark story as read URL resolves."""
        url = reverse("mark-story-as-read")
        resolved = resolve(url)
        assert resolved.view_name == "mark-story-as-read"

    def test_mark_story_hashes_as_read_resolves(self):
        """Test mark story hashes as read URL resolves."""
        url = reverse("mark-story-hashes-as-read")
        resolved = resolve(url)
        assert resolved.view_name == "mark-story-hashes-as-read"

    def test_mark_feed_stories_as_read_resolves(self):
        """Test mark feed stories as read URL resolves."""
        url = reverse("mark-feed-stories-as-read")
        resolved = resolve(url)
        assert resolved.view_name == "mark-feed-stories-as-read"

    def test_mark_social_stories_as_read_resolves(self):
        """Test mark social stories as read URL resolves."""
        url = reverse("mark-social-stories-as-read")
        resolved = resolve(url)
        assert resolved.view_name == "mark-social-stories-as-read"

    def test_mark_story_hash_as_unread_resolves(self):
        """Test mark story hash as unread URL resolves."""
        url = reverse("mark-story-hash-as-unread")
        resolved = resolve(url)
        assert resolved.view_name == "mark-story-hash-as-unread"

    def test_delete_feed_by_url_resolves(self):
        """Test delete feed by URL resolves."""
        url = reverse("delete-feed-by-url")
        resolved = resolve(url)
        assert resolved.view_name == "delete-feed-by-url"

    def test_delete_feeds_by_folder_resolves(self):
        """Test delete feeds by folder URL resolves."""
        url = reverse("delete-feeds-by-folder")
        resolved = resolve(url)
        assert resolved.view_name == "delete-feeds-by-folder"

    def test_delete_feed_resolves(self):
        """Test delete feed URL resolves."""
        url = reverse("delete-feed")
        resolved = resolve(url)
        assert resolved.view_name == "delete-feed"

    def test_delete_folder_resolves(self):
        """Test delete folder URL resolves."""
        url = reverse("delete-folder")
        resolved = resolve(url)
        assert resolved.view_name == "delete-folder"

    def test_rename_feed_resolves(self):
        """Test rename feed URL resolves."""
        url = reverse("rename-feed")
        resolved = resolve(url)
        assert resolved.view_name == "rename-feed"

    def test_rename_folder_resolves(self):
        """Test rename folder URL resolves."""
        url = reverse("rename-folder")
        resolved = resolve(url)
        assert resolved.view_name == "rename-folder"

    def test_move_feed_to_folders_resolves(self):
        """Test move feed to folders URL resolves."""
        url = reverse("move-feed-to-folders")
        resolved = resolve(url)
        assert resolved.view_name == "move-feed-to-folders"

    def test_move_feed_to_folder_resolves(self):
        """Test move feed to folder URL resolves."""
        url = reverse("move-feed-to-folder")
        resolved = resolve(url)
        assert resolved.view_name == "move-feed-to-folder"

    def test_move_folder_to_folder_resolves(self):
        """Test move folder to folder URL resolves."""
        url = reverse("move-folder-to-folder")
        resolved = resolve(url)
        assert resolved.view_name == "move-folder-to-folder"

    def test_move_feeds_by_folder_to_folder_resolves(self):
        """Test move feeds by folder to folder URL resolves."""
        url = reverse("move-feeds-by-folder-to-folder")
        resolved = resolve(url)
        assert resolved.view_name == "move-feeds-by-folder-to-folder"

    def test_save_folder_icon_resolves(self):
        """Test save folder icon URL resolves."""
        url = reverse("save-folder-icon")
        resolved = resolve(url)
        assert resolved.view_name == "save-folder-icon"

    def test_upload_folder_icon_resolves(self):
        """Test upload folder icon URL resolves."""
        url = reverse("upload-folder-icon")
        resolved = resolve(url)
        assert resolved.view_name == "upload-folder-icon"

    def test_save_feed_icon_resolves(self):
        """Test save feed icon URL resolves."""
        url = reverse("save-feed-icon")
        resolved = resolve(url)
        assert resolved.view_name == "save-feed-icon"

    def test_upload_feed_icon_resolves(self):
        """Test upload feed icon URL resolves."""
        url = reverse("upload-feed-icon")
        resolved = resolve(url)
        assert resolved.view_name == "upload-feed-icon"

    def test_add_feature_resolves(self):
        """Test add feature URL resolves."""
        url = reverse("add-feature")
        resolved = resolve(url)
        assert resolved.view_name == "add-feature"

    def test_load_features_resolves(self):
        """Test load features URL resolves."""
        url = reverse("load-features")
        resolved = resolve(url)
        assert resolved.view_name == "load-features"

    def test_save_feed_order_resolves(self):
        """Test save feed order URL resolves."""
        url = reverse("save-feed-order")
        resolved = resolve(url)
        assert resolved.view_name == "save-feed-order"

    def test_feeds_trainer_resolves(self):
        """Test feeds trainer URL resolves."""
        url = reverse("feeds-trainer")
        resolved = resolve(url)
        assert resolved.view_name == "feeds-trainer"

    def test_save_feed_chooser_resolves(self):
        """Test save feed chooser URL resolves."""
        url = reverse("save-feed-chooser")
        resolved = resolve(url)
        assert resolved.view_name == "save-feed-chooser"

    def test_set_feed_mute_resolves(self):
        """Test set feed mute URL resolves."""
        url = reverse("set-feed-mute")
        resolved = resolve(url)
        assert resolved.view_name == "set-feed-mute"

    def test_send_story_email_resolves(self):
        """Test send story email URL resolves."""
        url = reverse("send-story-email")
        resolved = resolve(url)
        assert resolved.view_name == "send-story-email"

    def test_retrain_all_sites_resolves(self):
        """Test retrain all sites URL resolves."""
        url = reverse("retrain-all-sites")
        resolved = resolve(url)
        assert resolved.view_name == "retrain-all-sites"

    def test_load_tutorial_resolves(self):
        """Test load tutorial URL resolves."""
        url = reverse("load-tutorial")
        resolved = resolve(url)
        assert resolved.view_name == "load-tutorial"

    def test_save_search_resolves(self):
        """Test save search URL resolves."""
        url = reverse("save-search")
        resolved = resolve(url)
        assert resolved.view_name == "save-search"

    def test_delete_search_resolves(self):
        """Test delete search URL resolves."""
        url = reverse("delete-search")
        resolved = resolve(url)
        assert resolved.view_name == "delete-search"

    def test_save_dashboard_rivers_resolves(self):
        """Test save dashboard rivers URL resolves."""
        url = reverse("save-dashboard-rivers")
        resolved = resolve(url)
        assert resolved.view_name == "save-dashboard-rivers"

    def test_save_dashboard_river_resolves(self):
        """Test save dashboard river URL resolves."""
        url = reverse("save-dashboard-river")
        resolved = resolve(url)
        assert resolved.view_name == "save-dashboard-river"

    def test_remove_dashboard_river_resolves(self):
        """Test remove dashboard river URL resolves."""
        url = reverse("remove-dashboard-river")
        resolved = resolve(url)
        assert resolved.view_name == "remove-dashboard-river"

    def test_trending_feeds_resolves(self):
        """Test trending feeds URL resolves."""
        url = reverse("trending-feeds")
        resolved = resolve(url)
        assert resolved.view_name == "trending-feeds"

    def test_print_story_resolves(self):
        """Test print story URL resolves."""
        url = reverse("print-story")
        resolved = resolve(url)
        assert resolved.view_name == "print-story"


class Test_ReaderURLAccess(TransactionTestCase):
    """Test access patterns for reader URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_index_anonymous(self):
        """Test anonymous access to index - redirects or returns 403/200."""
        response = self.client.get("/reader/", HTTP_USER_AGENT="TestBrowser/1.0")
        # Anonymous users get redirected to login, or may get 200/403 depending on settings
        assert response.status_code in [200, 302, 403]

    def test_welcome_anonymous(self):
        """Test anonymous access to welcome page."""
        response = self.client.get(reverse("welcome"))
        assert response.status_code == 200

    def test_login_page_anonymous(self):
        """Test anonymous access to login page."""
        response = self.client.get(reverse("welcome-login"))
        assert response.status_code == 200

    def test_signup_page_anonymous(self):
        """Test anonymous access to signup page."""
        response = self.client.get(reverse("welcome-signup"))
        assert response.status_code == 200

    def test_load_feeds_authenticated(self):
        """Test authenticated access to load feeds."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("load-feeds"))
        assert response.status_code == 200

        # Verify response contains expected structure
        data = response.json()
        assert "feeds" in data
        assert "folders" in data

    def test_load_feeds_anonymous(self):
        """Test anonymous access to load feeds - returns empty feeds structure or redirects."""
        response = self.client.get(reverse("load-feeds"), HTTP_USER_AGENT="TestBrowser/1.0")
        # Anonymous users get empty feeds (200), redirect (302), or forbidden (403)
        assert response.status_code in [200, 302, 403]

    def test_refresh_feeds_authenticated(self):
        """Test authenticated access to refresh feeds."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("refresh-feeds"))
        assert response.status_code == 200

        # Verify response structure
        data = response.json()
        assert "feeds" in data

    def test_load_features_anonymous(self):
        """Test anonymous access to load features."""
        response = self.client.get(reverse("load-features"))
        assert response.status_code == 200

    def test_trending_feeds_anonymous(self):
        """Test anonymous access to trending feeds."""
        response = self.client.get(reverse("trending-feeds"))
        assert response.status_code == 200

    def test_load_river_stories_authenticated(self):
        """Test authenticated access to load river stories."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("load-river-stories"))
        assert response.status_code == 200

        # Verify response structure
        data = response.json()
        assert "stories" in data

    def test_starred_counts_authenticated(self):
        """Test authenticated access to starred counts."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("starred-counts"))
        assert response.status_code == 200

        # Verify response structure
        data = response.json()
        assert "starred_counts" in data or "starred_count" in data or isinstance(data, list)

    def test_starred_story_hashes_authenticated(self):
        """Test authenticated access to starred story hashes."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("starred-story-hashes"))
        assert response.status_code == 200

        # Verify response structure
        data = response.json()
        assert "starred_story_hashes" in data

    def test_unread_story_hashes_authenticated(self):
        """Test authenticated access to unread story hashes."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("unread-story-hashes"))
        assert response.status_code == 200

        # Verify response structure
        data = response.json()
        assert "unread_feed_story_hashes" in data

    def test_interactions_count_authenticated(self):
        """Test authenticated access to interactions count."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("interactions-count"))
        assert response.status_code == 200

        # Verify response structure
        data = response.json()
        assert "interactions_count" in data

    def test_feeds_trainer_authenticated(self):
        """Test authenticated access to feeds trainer."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("feeds-trainer"))
        assert response.status_code == 200

    def test_load_tutorial_authenticated(self):
        """Test authenticated access to load tutorial."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("load-tutorial"))
        assert response.status_code == 200


class Test_ReaderURLPOST(TransactionTestCase):
    """Test POST endpoints for reader URLs with database verification."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        from apps.reader.models import UserSubscriptionFolders

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

        # Create initial folder structure for user
        UserSubscriptionFolders.objects.create(user=self.user, folders="[]")

    def test_mark_all_as_read_post(self):
        """Test POST to mark all as read and verify response."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.post(reverse("mark-all-as-read"), {"days": 0})
        assert response.status_code == 200

        # Verify response structure
        data = response.json()
        assert "code" in data
        assert data["code"] == 1  # Success code

    def test_add_folder_post(self):
        """Test POST to add folder and verify database persistence."""
        from apps.reader.models import UserSubscriptionFolders

        from utils import json_functions as json

        self.client.login(username="testuser", password="testpass")

        # POST to add folder
        response = self.client.post("/reader/add_folder", {"folder": "Test Folder"})
        assert response.status_code == 200

        # Verify folder was added to database
        usf = UserSubscriptionFolders.objects.get(user=self.user)
        folders = json.decode(usf.folders)
        # The folder should be in the folders structure
        folder_names = []
        for item in folders:
            if isinstance(item, dict):
                folder_names.extend(item.keys())
        assert "Test Folder" in folder_names

    def test_add_nested_folder_post(self):
        """Test POST to add nested folder and verify database persistence."""
        from apps.reader.models import UserSubscriptionFolders

        from utils import json_functions as json

        self.client.login(username="testuser", password="testpass")

        # First add a parent folder
        response = self.client.post("/reader/add_folder", {"folder": "Parent Folder"})
        assert response.status_code == 200

        # Add a nested folder
        response = self.client.post(
            "/reader/add_folder", {"folder": "Child Folder", "parent_folder": "Parent Folder"}
        )
        assert response.status_code == 200

        # Verify nested structure in database
        usf = UserSubscriptionFolders.objects.get(user=self.user)
        folders = json.decode(usf.folders)

        # Find Parent Folder and check it contains Child Folder
        found_parent = False
        for item in folders:
            if isinstance(item, dict) and "Parent Folder" in item:
                found_parent = True
                parent_contents = item["Parent Folder"]
                # Look for Child Folder in parent contents
                child_folder_names = []
                for subitem in parent_contents:
                    if isinstance(subitem, dict):
                        child_folder_names.extend(subitem.keys())
                assert "Child Folder" in child_folder_names
                break
        assert found_parent

    def test_rename_folder_post(self):
        """Test POST to rename folder and verify database persistence."""
        from apps.reader.models import UserSubscriptionFolders

        from utils import json_functions as json

        self.client.login(username="testuser", password="testpass")

        # First add a folder
        response = self.client.post("/reader/add_folder", {"folder": "Old Folder Name"})
        assert response.status_code == 200

        # Rename the folder
        response = self.client.post(
            reverse("rename-folder"), {"folder_name": "Old Folder Name", "new_folder_name": "New Folder Name"}
        )
        assert response.status_code == 200

        # Verify folder was renamed in database
        usf = UserSubscriptionFolders.objects.get(user=self.user)
        folders = json.decode(usf.folders)

        folder_names = []
        for item in folders:
            if isinstance(item, dict):
                folder_names.extend(item.keys())

        assert "New Folder Name" in folder_names
        assert "Old Folder Name" not in folder_names

    def test_save_feed_order_post(self):
        """Test POST to save feed order and verify database persistence."""
        from apps.reader.models import UserSubscriptionFolders

        from utils import json_functions as json

        self.client.login(username="testuser", password="testpass")

        # Save a specific folder order
        new_folders = '[{"Tech News": []}, {"Sports": []}]'
        response = self.client.post(reverse("save-feed-order"), {"folders": new_folders})
        assert response.status_code == 200

        # Verify folder order was saved to database
        usf = UserSubscriptionFolders.objects.get(user=self.user)
        folders = json.decode(usf.folders)

        # Extract folder names to verify order
        folder_names = []
        for item in folders:
            if isinstance(item, dict):
                folder_names.extend(item.keys())

        assert "Tech News" in folder_names
        assert "Sports" in folder_names

    def test_save_dashboard_rivers_post(self):
        """Test POST to save dashboard rivers and verify database persistence."""
        import json

        from apps.profile.models import MDashboardRiver

        self.client.login(username="testuser", password="testpass")

        # Save dashboard rivers with proper JSON body (requires river_id, river_side, and river_order)
        dashboard_rivers = [
            {"river_id": "river:global", "river_side": "left", "river_order": 0},
            {"river_id": "river:infrequent", "river_side": "right", "river_order": 1},
        ]
        response = self.client.post(
            reverse("save-dashboard-rivers"),
            json.dumps({"dashboard_rivers": dashboard_rivers}),
            content_type="application/json",
            HTTP_USER_AGENT="TestBrowser/1.0",
        )
        assert response.status_code == 200

        # Verify dashboard rivers were saved to MDashboardRiver MongoDB model
        saved_rivers = list(MDashboardRiver.objects.filter(user_id=self.user.pk))
        assert len(saved_rivers) == 2

        # Clean up
        MDashboardRiver.objects.filter(user_id=self.user.pk).delete()

    def test_retrain_all_sites_post(self):
        """Test POST to retrain all sites and verify database changes."""
        from apps.reader.models import UserSubscription
        from apps.rss_feeds.models import Feed

        self.client.login(username="testuser", password="testpass")

        # Create a subscription and mark it as trained
        feed = Feed.objects.first()
        if feed:
            sub = UserSubscription.objects.create(user=self.user, feed=feed, is_trained=True)

            # POST to retrain all sites
            response = self.client.post(reverse("retrain-all-sites"))
            assert response.status_code == 200

            # Verify subscription is_trained was reset to False
            sub.refresh_from_db()
            assert sub.is_trained is False
        else:
            # No feeds in fixture, just verify endpoint works
            response = self.client.post(reverse("retrain-all-sites"))
            assert response.status_code == 200

    def test_delete_folder_post(self):
        """Test POST to delete folder and verify database persistence."""
        from apps.reader.models import UserSubscriptionFolders

        from utils import json_functions as json

        self.client.login(username="testuser", password="testpass")

        # First add a folder
        response = self.client.post("/reader/add_folder", {"folder": "Folder To Delete"})
        assert response.status_code == 200

        # Verify folder exists
        usf = UserSubscriptionFolders.objects.get(user=self.user)
        folders = json.decode(usf.folders)
        folder_names = []
        for item in folders:
            if isinstance(item, dict):
                folder_names.extend(item.keys())
        assert "Folder To Delete" in folder_names

        # Delete the folder
        response = self.client.post(reverse("delete-folder"), {"folder_name": "Folder To Delete"})
        assert response.status_code == 200

        # Verify folder was removed from database
        usf.refresh_from_db()
        folders = json.decode(usf.folders)
        folder_names = []
        for item in folders:
            if isinstance(item, dict):
                folder_names.extend(item.keys())
        assert "Folder To Delete" not in folder_names
