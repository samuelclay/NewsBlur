from settings import *
DATABASES = {
    'default': {
        'NAME': ':memory:',
        'ENGINE': 'django.db.backends.sqlite3',
        'USER': 'newsblur',
        'PASSWORD': '',
        'HOST': '127.0.0.1',
    }
}
MONGO_DB = {
    'NAME': 'newsblur_test',
    'HOST': '127.0.0.1',
    'PORT': 27017
}      

TEST_DATABASE_NAME = ":memory:"
DAYS_OF_UNREAD = 9999
TEST_DEBUG = True
DEBUG = True

# from django.db import connection
# cursor = connection.cursor()
# cursor.execute('PRAGMA temp_store = MEMORY;')
# cursor.execute('PRAGMA synchronous=OFF')