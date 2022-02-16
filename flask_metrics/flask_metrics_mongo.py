from flask import Flask, render_template, Response
import pymongo
from newsblur_web import settings
import sentry_sdk
from sentry_sdk.integrations.flask import FlaskIntegration

if settings.FLASK_SENTRY_DSN is not None:
    sentry_sdk.init(
        dsn=settings.FLASK_SENTRY_DSN,
        integrations=[FlaskIntegration()],
        traces_sample_rate=1.0,
    )

app = Flask(__name__)

if settings.DOCKERBUILD:
    connection = pymongo.MongoClient(f"mongodb://{settings.MONGO_DB['host']}")
else:
    connection = pymongo.MongoClient(f"mongodb://{settings.MONGO_DB['username']}:{settings.MONGO_DB['password']}@{settings.SERVER_NAME}.node.consul/?authSource=admin")

MONGO_HOST = settings.SERVER_NAME

@app.route("/objects/")
def objects():
    try:
        stats = connection.newsblur.command("dbstats")
    except pymongo.errors.OperationFailure as e:
        return Response(f"Operation failure: {e}", 500)
    except pymongo.errors.NotMasterError as e:
        return Response(f"NotMaster error: {e}", 500)
    data = dict(objects=stats['objects'])
    formatted_data = {}
    for k, v in data.items():
        formatted_data[k] = f'mongo_objects{{db="{MONGO_HOST}"}} {v}'

    context = {
        "data": formatted_data,
        "chart_name": 'objects',
        "chart_type": 'gauge',
    }
    html_body = render_template('prometheus_data.html', **context)
    return Response(html_body, content_type="text/plain")


@app.route("/mongo-replset-lag/")
def repl_set_lag():
    def _get_oplog_length():
        oplog = connection.rs.command('printReplicationInfo')
        last_op = oplog.find({}, {'ts': 1}).sort([('$natural', -1)]).limit(1)[0]['ts'].time
        first_op = oplog.find({}, {'ts': 1}).sort([('$natural', 1)]).limit(1)[0]['ts'].time
        oplog_length = last_op - first_op
        return oplog_length

    def _get_max_replication_lag():
        PRIMARY_STATE = 1
        SECONDARY_STATE = 2
        status = connection.admin.command('replSetGetStatus')
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

    try:
        # no such item for Cursor instance
        oplog_length = _get_oplog_length()
        # not running with --replSet
        replication_lag = _get_max_replication_lag()
    except pymongo.errors.OperationFailure as e:
        return Response(f"Operation failure: {e}", 500)
    except pymongo.errors.NotMasterError as e:
        return Response(f"NotMaster error: {e}", 500)
    
    formatted_data = {}
    for k, v in oplog_length.items():
        formatted_data[k] = f'mongo_oplog{{type="length", db="{MONGO_HOST}"}} {v}'
    for k, v in replication_lag.items():
        formatted_data[k] = f'mongo_oplog{{type="lag", db="{MONGO_HOST}"}} {v}'

    context = {
        "data": formatted_data,
        "chart_name": 'oplog_metrics',
        "chart_type": 'gauge',
    }
    html_body = render_template('prometheus_data.html', **context)
    return Response(html_body, content_type="text/plain")


@app.route("/size/")
def size():
    try:
        stats = connection.newsblur.command("dbstats")
    except pymongo.errors.OperationFailure as e:
        return Response(f"Operation failure: {e}", 500)
    except pymongo.errors.NotMasterError as e:
        return Response(f"NotMaster error: {e}", 500)
    data = dict(size=stats['fsUsedSize'])
    formatted_data = {}
    for k, v in data.items():
        formatted_data[k] = f'mongo_db_size{{db="{MONGO_HOST}"}} {v}'

    context = {
        "data": formatted_data,
        "chart_name": 'db_size_bytes',
        "chart_type": 'gauge',
    }
    html_body = render_template('prometheus_data.html', **context)
    return Response(html_body, content_type="text/plain")


@app.route("/ops/")
def ops():
    try:
        status = connection.admin.command('serverStatus')
    except pymongo.errors.OperationFailure as e:
        return Response(f"Operation failure: {e}", 500)
    except pymongo.errors.NotMasterError as e:
        return Response(f"NotMaster error: {e}", 500)
    data = dict(
        (q, status["opcounters"][q])
        for q in status['opcounters'].keys()
    )
    
    formatted_data = {}
    for k, v in data.items():
        formatted_data[k] = f'mongo_ops{{type="{k}", db="{MONGO_HOST}"}} {v}'
    
    context = {
        "data": formatted_data,
        "chart_name": 'ops',
        "chart_type": 'gauge',
    }
    html_body = render_template('prometheus_data.html', **context)
    return Response(html_body, content_type="text/plain")


@app.route("/page-faults/")
def page_faults():
    try:
        status = connection.admin.command('serverStatus')
    except pymongo.errors.OperationFailure as e:
        return Response(f"Operation failure: {e}", 500)
    except pymongo.errors.NotMasterError as e:
        return Response(f"NotMaster error: {e}", 500)
    try:
        value = status['extra_info']['page_faults']
    except KeyError:
        value = "U"
    data = dict(page_faults=value)
    formatted_data = {}
    for k, v in data.items():
        formatted_data[k] = f'mongo_page_faults{{db="{MONGO_HOST}"}} {v}'

    context = {
        "data": formatted_data,
        "chart_name": 'page_faults',
        "chart_type": 'counter',
    }
    html_body = render_template('prometheus_data.html', **context)
    return Response(html_body, content_type="text/plain")


@app.route("/page-queues/")
def page_queues():
    try:
        status = connection.admin.command('serverStatus')
    except pymongo.errors.OperationFailure as e:
        return Response(f"Operation failure: {e}", 500)
    except pymongo.errors.NotMasterError as e:
        return Response(f"NotMaster error: {e}", 500)
    data = dict(
        (q, status["globalLock"]["currentQueue"][q])
        for q in ("readers", "writers")
    )
    formatted_data = {}
    for k, v in data.items():
        formatted_data[k] = f'mongo_page_queues{{type="{k}", db="{MONGO_HOST}"}} {v}'

    context = {
        "data": formatted_data,
        "chart_name": 'queues',
        "chart_type": 'gauge',
    }
    html_body = render_template('prometheus_data.html', **context)
    return Response(html_body, content_type="text/plain")


if __name__ == "__main__":
    print(" ---> Starting NewsBlur Flask Metrics server...")
    app.run(host="0.0.0.0", port=5569)
