from settings import *
DATABASES = {
    'default': {
        'NAME': 'memory',
        'ENGINE': 'django.db.backends.sqlite3',
        'USER': 'newsblur',
        'PASSWORD': '',
        'HOST': '127.0.0.1',
    }
}
MONGO_DB = {
    'name': 'newsblur_test',
    'host': '127.0.0.1:27017',
}

MONGO_DATABASE_NAME = 'test_newsblur'
TEST_DATABASE_NAME = ":memory:"
DAYS_OF_UNREAD = 9999
TEST_DEBUG = True
DEBUG = True
SITE_ID = 2
RAVEN_CLIENT = None
# from django.db import connection
# cursor = connection.cursor()
# cursor.execute('PRAGMA temp_store = MEMORY;')
# cursor.execute('PRAGMA synchronous=OFF')