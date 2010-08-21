from django.test.simple import DjangoTestSuiteRunner
from django.test import TransactionTestCase

from mongoengine import connect

class TestRunner(DjangoTestSuiteRunner):
    def setup_databases(self, **kwargs):
        db_name = 'newsblur_test'
        connect(db_name)
        print 'Creating test-database: ' + db_name

        return super(TestRunner, self).setup_databases(**kwargs)

    def teardown_databases(self, db_name, **kwargs):
        from pymongo import Connection
        conn = Connection()
        db_name = 'newsblur_test'
        conn.drop_database(db_name)
        print 'Dropping test-database: ' + db_name


class TestCase(TransactionTestCase):
    def _fixture_setup(self):
        pass
