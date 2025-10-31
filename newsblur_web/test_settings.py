import os

DOCKERBUILD = os.getenv("DOCKERBUILD")
from newsblur_web.settings import *

# Use PostgreSQL for tests to avoid SQLite concurrency issues
DATABASES["default"] = {
    "NAME": "newsblur",
    "ENGINE": "django.db.backends.postgresql_psycopg2",
    "USER": "newsblur",
    "PASSWORD": "newsblur",
    "HOST": "newsblur_db_postgres" if DOCKERBUILD else "localhost",
    "PORT": "5432",
    "TEST": {
        "NAME": "test_newsblur",
    },
}

LOGGING_CONFIG = None

# Monkey-patch TransactionTestCase to ensure Site exists before each test
from django.test import TransactionTestCase

_original_fixture_setup = TransactionTestCase._fixture_setup


def _fixture_setup_with_site(self):
    """Override fixture setup to ensure Site exists before each test."""
    result = _original_fixture_setup(self)

    # Ensure the test Site exists before running the test
    from django.conf import settings
    from django.contrib.sites.models import Site

    try:
        Site.objects.update_or_create(
            pk=settings.SITE_ID, defaults={"domain": "testserver", "name": "Test Server"}
        )
    except Exception:
        pass

    return result


TransactionTestCase._fixture_setup = _fixture_setup_with_site

# DATABASES = {
#     'default':{
#         'ENGINE': 'django.db.backends.sqlite3',
#         'NAME': ':memory:',
#         'TEST_NAME': ':memory:',
#     },
# }


if DOCKERBUILD:
    MONGO_PORT = 29019
    MONGO_DB = {
        "name": "newsblur_test",
        "host": "newsblur_db_mongo:29019",
    }

else:
    MONGO_PORT = 27017
    MONGO_DB = {
        "name": "newsblur_test",
        "host": "127.0.0.1:27017",
    }

MONGO_DATABASE_NAME = "test_newsblur"

SOUTH_TESTS_MIGRATE = False
DAYS_OF_UNREAD = 9999
DAYS_OF_UNREAD_FREE = 9999
TEST_DEBUG = True
DEBUG = True

# Fix subdomain middleware warning in tests
PARENT_HOST = "testserver"
SESSION_COOKIE_DOMAIN = "testserver"
SITE_ID = 2
SENTRY_DSN = None
HOMEPAGE_USERNAME = "conesus"
SERVER_NAME = "test_newsblur"

# Run Celery tasks synchronously during tests
CELERY_ALWAYS_EAGER = True
CELERY_EAGER_PROPAGATES_EXCEPTIONS = True
BROKER_BACKEND = "memory"
CELERY_RESULT_BACKEND = "cache"
CELERY_CACHE_BACKEND = "memory"
