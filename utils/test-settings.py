import sys
from settings import *

# if 'test' in sys.argv:
#     DATABASES['default']['ENGINE'] = 'django.db.backends.sqlite3'
#     DATABASES['default']['OPTIONS'] = {}
#     # DATABASES['default']['NAME'] = 'nb.db'
#     # DATABASES['default']['TEST_NAME'] = 'nb2.db'
    
# DATABASES = {
#     'default':{
#         'ENGINE': 'django.db.backends.sqlite3',
#         'NAME': ':memory:',
#         'TEST_NAME': ':memory:',
#     },
# }
MONGO_DB = {
    'name': 'newsblur_test',
    'host': '127.0.0.1:27017',
}

MONGO_DATABASE_NAME = 'test_newsblur'
# TEST_DATABASE_NAME = ":memory:"
SOUTH_TESTS_MIGRATE = False
DAYS_OF_UNREAD = 9999
DAYS_OF_UNREAD_FREE = 9999
TEST_DEBUG = True
DEBUG = True
SITE_ID = 2
RAVEN_CLIENT = None
# from django.db import connection
# cursor = connection.cursor()
# cursor.execute('PRAGMA temp_store = MEMORY;')
# cursor.execute('PRAGMA synchronous=OFF')