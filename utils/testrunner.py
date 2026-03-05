import os

from django.test.runner import DiscoverRunner
from django.test.utils import setup_databases
from mongoengine.connection import connect, disconnect_all


class TestRunner(DiscoverRunner):
    def setup_databases(self, **kwargs):
        db_name = "newsblur_test"

        # Register a test database alias without disconnecting the main connection
        # The main connection is needed for migrations that use settings.MONGODB
        if os.getenv("DOCKERBUILD"):
            connect(db_name, alias="test", host="newsblur_db_mongo", port=29019, connect=False)
        else:
            connect(db_name, alias="test", host="127.0.0.1", port=27017, connect=False)

        print("Creating test-database: " + db_name)

        result = setup_databases(self.verbosity, self.interactive, **kwargs)

        # Ensure Site exists for subdomain middleware
        # Use get_or_create to avoid conflicts with fixtures that may also create Sites
        from django.conf import settings
        from django.contrib.sites.models import Site

        try:
            Site.objects.get_or_create(
                pk=settings.SITE_ID, defaults={"domain": "testserver", "name": "Test Server"}
            )
        except Exception:
            # Site may already exist from fixtures or previous test runs
            pass

        return result

    def teardown_databases(self, old_config, **kwargs):
        import pymongo

        # Disconnect mongoengine test alias
        try:
            disconnect_all()
        except Exception:
            pass

        # Use Docker MongoDB settings when in Docker environment
        if os.getenv("DOCKERBUILD"):
            conn = pymongo.MongoClient("newsblur_db_mongo", 29019)
        else:
            conn = pymongo.MongoClient("127.0.0.1", 27017)

        db_name = "newsblur_test"
        try:
            conn.drop_database(db_name)
            print("Dropping test-database: %s" % db_name)
        finally:
            conn.close()

        return super(TestRunner, self).teardown_databases(old_config, **kwargs)


# class TestCase(TransactionTestCase):
#     def _fixture_setup(self):
#         pass
