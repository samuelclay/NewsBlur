from django.test.runner import DiscoverRunner
from django.test.utils import setup_databases
from mongoengine.connection import disconnect_all

from utils.test_mongo import configure_test_mongo_connection


class TestRunner(DiscoverRunner):
    def setup_databases(self, **kwargs):
        from django.conf import settings

        db_name = configure_test_mongo_connection(settings)

        print("Creating test-database: " + db_name)

        result = setup_databases(self.verbosity, self.interactive, **kwargs)

        # Ensure Site exists for subdomain middleware
        # Use get_or_create to avoid conflicts with fixtures that may also create Sites
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
        from django.conf import settings

        # Disconnect mongoengine test alias
        try:
            disconnect_all()
        except Exception:
            pass

        mongo_config = dict(getattr(settings, "MONGO_DB", {}))
        db_name = mongo_config.pop("name", getattr(settings, "MONGO_DB_NAME", "newsblur_test"))
        host = mongo_config.get("host", "127.0.0.1:27017")
        conn = pymongo.MongoClient(host)
        try:
            conn.drop_database(db_name)
            print("Dropping test-database: %s" % db_name)
        finally:
            conn.close()

        return super(TestRunner, self).teardown_databases(old_config, **kwargs)


# class TestCase(TransactionTestCase):
#     def _fixture_setup(self):
#         pass
