from settings import *

DATABASE_ENGINE = 'sqlite3'
DATABASE_NAME = ':memory:'
TEST_DATABASE_NAME = ":memory:"

# from django.db import connection
# cursor = connection.cursor()
# cursor.execute('PRAGMA temp_store = MEMORY;')
# cursor.execute('PRAGMA synchronous=OFF')