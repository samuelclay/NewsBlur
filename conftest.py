"""
Pytest configuration and fixtures for NewsBlur tests.

This module provides common fixtures used across all test files.
"""

import os

import pytest

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "newsblur_web.test_settings")

import django

django.setup()

from utils.testrunner import TestRunner

_runner = None
_old_config = None


def pytest_sessionstart(session):
    global _runner, _old_config

    _runner = TestRunner(verbosity=0, interactive=False)
    _runner.setup_test_environment()
    _old_config = _runner.setup_databases()


def pytest_sessionfinish(session, exitstatus):
    if _runner is None:
        return

    _runner.teardown_databases(_old_config)
    _runner.teardown_test_environment()


@pytest.fixture
def user(db):
    """Create a test user."""
    from django.contrib.auth.models import User

    return User.objects.create_user(
        username="testuser",
        email="test@test.com",
        password="testpass123",
    )


@pytest.fixture
def client():
    """Create a test client."""
    from django.test import Client

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
    from django.contrib.auth.models import User

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
