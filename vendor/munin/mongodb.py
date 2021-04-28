#!/srv/newsblur/venv/newsblur3/bin/python

import os
import sys
from vendor.munin import MuninPlugin

class MuninMongoDBPlugin(MuninPlugin):
    dbname_in_args = False
    category = "MongoDB"

    def __init__(self):
        super(MuninMongoDBPlugin, self).__init__()

        self.dbname = None
        if self.dbname_in_args:
            self.dbname = sys.argv[0].rsplit('_', 1)[-1]
        if not self.dbname:
            self.dbname = os.environ.get('MONGODB_DATABASE')

        host = os.environ.get('MONGODB_SERVER') or 'localhost'
        if ':' in host:
            host, port = host.split(':')
            port = int(port)
        else:
            port = 27017
        self.server = (host, port)

    @property
    def connection(self):
        if not hasattr(self, '_connection'):
            import pymongo
            self._connection = pymongo.MongoClient(self.server[0], self.server[1])
        return self._connection

    @property
    def db(self):
        if not hasattr(self, '_db'):
            self._db = getattr(self.connection, self.dbname)
        return self._db

    def autoconf(self):
        return bool(self.connection)
