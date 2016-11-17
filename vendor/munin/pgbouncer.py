import sys
from vendor.munin.postgres import MuninPostgresPlugin

class MuninPgBouncerPlugin(MuninPostgresPlugin):
    dbname_in_args = False
    default_table = "pgbouncer"
    category = "PgBouncer"

    def __init__(self, *args, **kwargs):
        super(MuninPgBouncerPlugin, self).__init__(*args, **kwargs)
        self.dbwatched = sys.argv[0].rsplit('_', 1)[-1]

    def connection(self):
        if not hasattr(self, '_connection'):
            import psycopg2
            self._connection = psycopg2.connect(self.dsn)
            self._connection.set_isolation_level(0)
        return self._connection

    def execute(self):
        cursor = self.cursor()
        cursor.execute(self.command)
        columns = [column[0] for column in cursor.description]

        totals = dict.fromkeys((field[0] for field in self.fields), 0)
        for row in cursor:
            row_dict = dict(zip(columns, row))
            if row_dict['database'] in (self.dbwatched, self.dbwatched + '\x00'):
                for field in self.fields:
                    totals[field[0]] += row_dict[field[0]]

        return dict((field[0], totals[field[0]]) for field in self.fields)

