"""
URL tests for the feed_import app.

Tests URL resolution and basic access patterns for all feed_import endpoints.
"""

import pytest
from django.test import Client, TransactionTestCase
from django.urls import resolve, reverse


class Test_FeedImportURLResolution(TransactionTestCase):
    """Test that all feed_import URLs resolve correctly."""

    def test_opml_upload_resolves(self):
        """Test OPML upload URL resolves."""
        url = reverse("opml-upload")
        resolved = resolve(url)
        assert resolved.view_name == "opml-upload"

    def test_opml_export_resolves(self):
        """Test OPML export URL resolves."""
        url = reverse("opml-export")
        resolved = resolve(url)
        assert resolved.view_name == "opml-export"


class Test_FeedImportURLAccess(TransactionTestCase):
    """Test access patterns for feed_import URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_opml_upload_authenticated(self):
        """Test authenticated access to OPML upload."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("opml-upload"))
        assert response.status_code in [200, 302, 405]

    def test_opml_export_authenticated(self):
        """Test authenticated access to OPML export."""
        self.client.login(username="testuser", password="testpass")
        response = self.client.get(reverse("opml-export"))
        assert response.status_code == 200


class Test_FeedImportURLPOST(TransactionTestCase):
    """Test POST endpoints for feed_import URLs."""

    fixtures = [
        "apps/rss_feeds/fixtures/initial_data.json",
    ]

    def setUp(self):
        from django.contrib.auth.models import User

        self.client = Client()
        self.user = User.objects.create_user(username="testuser", password="testpass", email="test@test.com")

    def test_opml_upload_post(self):
        """Test POST to OPML upload."""
        self.client.login(username="testuser", password="testpass")
        # Create a simple OPML file content
        opml_content = b"""<?xml version="1.0" encoding="UTF-8"?>
<opml version="1.0">
    <head><title>Test OPML</title></head>
    <body></body>
</opml>"""
        from io import BytesIO

        from django.core.files.uploadedfile import SimpleUploadedFile

        opml_file = SimpleUploadedFile("test.opml", opml_content, content_type="text/xml")
        response = self.client.post(reverse("opml-upload"), {"file": opml_file})
        assert response.status_code in [200, 302, 400]
