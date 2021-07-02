from django.test.runner import DiscoverRunner
from django.test.utils import setup_databases
from mongoengine.connection import disconnect, connect
class TestRunner(DiscoverRunner):
    def setup_databases(self, **kwargs):
        db_name = 'newsblur_test'
        disconnect()
        connect(db_name)
        print('Creating test-database: ' + db_name)

        return setup_databases(self.verbosity, self.interactive, **kwargs)

    def teardown_databases(self, old_config, **kwargs):
        import pymongo
        conn = pymongo.MongoClient()
        db_name = 'newsblur_test'
        conn.drop_database(db_name)
        print('Dropping test-database: %s' % db_name)
        return super(TestRunner, self).teardown_databases(old_config, **kwargs)


# class TestCase(TransactionTestCase):
#     def _fixture_setup(self):
#         pass
