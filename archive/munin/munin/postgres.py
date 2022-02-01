
import os, sys
from vendor.munin import MuninPlugin

class MuninPostgresPlugin(MuninPlugin):
    dbname_in_args = False
    category = "PostgreSQL"
    default_table = "template1"

    def __init__(self):
        super(MuninPostgresPlugin, self).__init__()

        self.dbname = ((sys.argv[0].rsplit('_', 1)[-1] if self.dbname_in_args else None)
            or os.environ.get('PGDATABASE') or self.default_table)
        dsn = ["dbname='%s'" % self.dbname]
        for k in ('user', 'password', 'host', 'port'):
            v = os.environ.get('DB%s' % k.upper())
            if v:
                dsn.append("db%s='%s'" % (k, v))
        self.dsn = ' '.join(dsn)

    def connection(self):
        if not hasattr(self, '_connection'):
            import psycopg2
            self._connection = psycopg2.connect(self.dsn)
        return self._connection

    def cursor(self):
        return self.connection().cursor()

    def autoconf(self):
        return bool(self.connection())

    def tables(self):
        if not hasattr(self, '_tables'):
            c = self.cursor()
            c.execute(
                "SELECT c.relname FROM pg_catalog.pg_class c"
                " LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace"
                " WHERE c.relkind IN ('r','')"
                "  AND n.nspname NOT IN ('pg_catalog', 'pg_toast')"
                "  AND pg_catalog.pg_table_is_visible(c.oid)")
            self._tables = [r[0] for r in c.fetchall()]
        return self._tables
