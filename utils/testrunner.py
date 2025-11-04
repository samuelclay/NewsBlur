import os

from django.test.runner import DiscoverRunner
from django.test.utils import setup_databases
from mongoengine.connection import connect, disconnect


class TestRunner(DiscoverRunner):
    def setup_databases(self, **kwargs):
        db_name = "newsblur_test"
        disconnect()

        # Use Docker MongoDB settings when in Docker environment
        if os.getenv("DOCKERBUILD"):
            connect(db_name, host="newsblur_db_mongo", port=29019, connect=False)
        else:
            connect(db_name, host="127.0.0.1", port=27017, connect=False)

        print("Creating test-database: " + db_name)

        result = setup_databases(self.verbosity, self.interactive, **kwargs)

        # Ensure Site exists for subdomain middleware
        from django.conf import settings
        from django.contrib.sites.models import Site

        Site.objects.update_or_create(
            pk=settings.SITE_ID, defaults={"domain": "testserver", "name": "Test Server"}
        )

        return result

    def teardown_databases(self, old_config, **kwargs):
        import pymongo

        # Use Docker MongoDB settings when in Docker environment
        if os.getenv("DOCKERBUILD"):
            conn = pymongo.MongoClient("newsblur_db_mongo", 29019)
        else:
            conn = pymongo.MongoClient("127.0.0.1", 27017)

        db_name = "newsblur_test"
        conn.drop_database(db_name)
        print("Dropping test-database: %s" % db_name)
        return super(TestRunner, self).teardown_databases(old_config, **kwargs)


# class TestCase(TransactionTestCase):
#     def _fixture_setup(self):
#         pass
