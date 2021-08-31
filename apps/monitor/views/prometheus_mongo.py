import os
from django.views import View
from django.shortcuts import render

class MongoGrafanaMetric(View):
    
    def __init__(self):
        super(View, self).__init__()

        self.dbname = os.environ.get('MONGODB_DATABASE')
        host = os.environ.get('MONGODB_SERVER') or 'db_mongo:29019'
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
    def host(self):
        return os.environ.get('MONGODB_SERVER') or 'db_mongo:29019'

    def autoconf(self):
        return bool(self.connection)

    def get_context(self):
        raise NotImplementedError('You must implement the get_context function')
    
    def get(self, request):
        context = self.get_context()
        return render(request, 'monitor/prometheus_data.html', context, content_type="text/plain")

class MongoDBHeapUsage(MongoGrafanaMetric):

    def get_context(self):
        value = self.connection.admin.command('serverStatus')
        try:
            value = value['extra_info']['heap_usage_bytes']
        except KeyError:
            # I am getting this
            value = "U"
        data = {
            'heap_usage_bytes': value
        }
        return {
            "data": data,
            "chart_name": 'MongoDB heap usage',
            "chart_type": 'gauge',
        }

class MongoDBObjects(MongoGrafanaMetric):

    def get_context(self):
        stats = self.connection.db.command("dbstats")
        data = dict(objects=stats['objects'])
        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'mongo_objects{{db="{self.host}"}} {v}'

        return {
            "data": formatted_data,
            "chart_name": 'Number of objects stored',
            "chart_type": 'gauge',
        }

class MongoDBOpsReplsetLag(MongoGrafanaMetric):

    def _get_oplog_length(self):
        oplog = self.connection['local'].oplog.rs
        last_op = oplog.find({}, {'ts': 1}).sort([('$natural', -1)]).limit(1)[0]['ts'].time
        first_op = oplog.find({}, {'ts': 1}).sort([('$natural', 1)]).limit(1)[0]['ts'].time
        oplog_length = last_op - first_op
        return oplog_length

    def _get_max_replication_lag(self):
        PRIMARY_STATE = 1
        SECONDARY_STATE = 2
        status = self.connection.admin.command('replSetGetStatus')
        members = status['members']
        primary_optime = None
        oldest_secondary_optime = None
        for member in members:
            member_state = member['state']
            optime = member['optime']
            if member_state == PRIMARY_STATE:
                primary_optime = optime['ts'].time
            elif member_state == SECONDARY_STATE:
                if not oldest_secondary_optime or optime['ts'].time < oldest_secondary_optime:
                    oldest_secondary_optime = optime['ts'].time

        if not primary_optime or not oldest_secondary_optime:
            raise Exception("Replica set is not healthy")

        return primary_optime - oldest_secondary_optime

    def get_context(self):
        # no such item for Cursor instance
        oplog_length = self._get_oplog_length()
        # not running with --replSet
        replication_lag = self._get_max_replication_lag()
        
        formatted_data = {}
        for k, v in oplog_length.items():
            formatted_data[k] = f'mongo_oplog{{type="length", db="{self.host}"}} {v}'
        for k, v in replication_lag.items():
            formatted_data[k] = f'mongo_oplog{{type="lag", db="{self.host}"}} {v}'

        return {
            "data": formatted_data,
            "chart_name": 'Oplog Metrics',
            "chart_type": 'gauge',
        }

class MongoDBSize(MongoGrafanaMetric):
    def get_context(self):
        pass

class MongoDBOps(MongoGrafanaMetric):

    def get_context(self):
        status = self.connection.admin.command('serverStatus')
        data = dict(
            (q, status["opcounters"][q])
            for q in status['opcounters'].keys()
        )
        
        formatted_data = {}
        for k,v in data.items():
            formatted_data[k] = f'mongo_ops{{type="{k}", db="{self.host}"}} {v}'
        
        return {
            "data": formatted_data,
            "chart_name": 'Number of DB Ops',
            "chart_type": 'gauge',
        }

class MongoDBPageFaults(MongoGrafanaMetric):

    def get_context(self):
        status = self.connection.admin.command('serverStatus')
        try:
            value = status['extra_info']['page_faults']
        except KeyError:
            value = "U"
        data = dict(page_faults=value)
        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'mongo_page_faults{{db="{self.host}"}} {v}'

        return {
            "data": formatted_data,
            "chart_name": 'MongoDB page faults',
            "chart_type": 'counter',
        }


class MongoDBPageQueues(MongoGrafanaMetric):

    def get_context(self):
        status = self.connection.admin.command('serverStatus')
        data = dict(
            (q, status["globalLock"]["currentQueue"][q])
            for q in ("readers", "writers")
        )
        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'mongo_page_queues{{type="{k}", db="{self.host}"}} {v}'

        return {
            "data": formatted_data,
            "chart_name": 'MongoDB queues',
            "chart_type": 'gauge',
        }