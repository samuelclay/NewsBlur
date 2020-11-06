import sys
from newsblur_web.settings import *

DOCKERBUILD = os.getenv("DOCKERBUILD")

DATABASES['default']['ENGINE'] = 'django.db.backends.sqlite3'
DATABASES['default']['OPTIONS'] = {}
DATABASES['default']['NAME'] = 'nb.db'
DATABASES['default']['TEST_NAME'] = 'nb2.db'
    
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
        'name': 'newsblur_test',
        'host': '127.0.0.1:29019',
    }

else:
    MONGO_PORT = 27017
    MONGO_DB = {
        'name': 'newsblur_test',
        'host': '127.0.0.1:27017',
    }
    SERVER_NAME

MONGO_DATABASE_NAME = 'test_newsblur'
# TEST_DATABASE_NAME = ":memory:"
SOUTH_TESTS_MIGRATE = False
DAYS_OF_UNREAD = 9999
DAYS_OF_UNREAD_FREE = 9999
TEST_DEBUG = True
DEBUG = True
SITE_ID = 2
RAVEN_CLIENT = None
HOMEPAGE_USERNAME = 'conesus'
SERVER_NAME = 'test_newsblur'
# from django.db import connection
# cursor = connection.cursor()
# cursor.execute('PRAGMA temp_store = MEMORY;')
# cursor.execute('PRAGMA synchronous=OFF')
