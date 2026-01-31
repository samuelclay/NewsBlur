"""
Pytest configuration and fixtures for NewsBlur tests.

This module provides common fixtures used across all test files.
"""

import pytest
from django.contrib.auth.models import User
from django.test import Client


@pytest.fixture
def user(db):
    """Create a test user."""
    return User.objects.create_user(
        username="testuser",
        email="test@test.com",
        password="testpass123",
    )


@pytest.fixture
def client():
    """Create a test client."""
    return Client()


@pytest.fixture
def authenticated_client(client, user):
    """Create an authenticated test client."""
    client.login(username="testuser", password="testpass123")
    return client


@pytest.fixture
def feed(db, user):
    """Create a test feed with subscription."""
    from apps.reader.models import UserSubscription
    from apps.rss_feeds.models import Feed

    feed = Feed.objects.create(
        feed_address="http://example.com/feed.xml",
        feed_link="http://example.com",
        feed_title="Test Feed",
    )
    UserSubscription.objects.create(user=user, feed=feed)
    return feed


@pytest.fixture
def premium_user(db):
    """Create a premium user."""
    user = User.objects.create_user(
        username="premiumuser",
        email="premium@test.com",
        password="testpass123",
    )
    user.profile.is_premium = True
    user.profile.save()
    return user


@pytest.fixture
def authenticated_premium_client(client, premium_user):
    """Create an authenticated client with premium user."""
    client.login(username="premiumuser", password="testpass123")
    return client
