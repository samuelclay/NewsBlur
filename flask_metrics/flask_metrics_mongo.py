import pymongo
import sentry_sdk
from flask import Flask, Response, render_template
from sentry_sdk.integrations.flask import FlaskIntegration

from newsblur_web import settings

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
    connection = pymongo.MongoClient(
        f"mongodb://{settings.MONGO_DB['username']}:{settings.MONGO_DB['password']}@{settings.SERVER_NAME}.node.consul/?authSource=admin"
    )

MONGO_HOST = settings.SERVER_NAME


@app.route("/objects/")
def objects():
    try:
        stats = connection.newsblur.command("dbstats")
    except pymongo.errors.ServerSelectionTimeoutError as e:
        return Response(f"Server selection timeout: {e}", 500)
    except pymongo.errors.OperationFailure as e:
        return Response(f"Operation failure: {e}", 500)
    except pymongo.errors.NotPrimaryError as e:
        return Response(f"NotMaster error: {e}", 500)
    data = dict(objects=stats["objects"])
    formatted_data = {}
    for k, v in data.items():
        formatted_data[k] = f'mongo_objects{{db="{MONGO_HOST}"}} {v}'

    context = {
        "data": formatted_data,
        "chart_name": "objects",
        "chart_type": "gauge",
    }
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


@app.route("/mongo-replset-lag/")
def repl_set_lag():
    """
    Get MongoDB replica set replication lag for each secondary.
    Returns per-secondary lag values for better monitoring.
    """
    PRIMARY_STATE = 1
    SECONDARY_STATE = 2

    formatted_data = {}
    metric_index = 0

    try:
        status = connection.admin.command("replSetGetStatus")
        members = status["members"]

        primary_optime = None
        primary_name = None
        secondaries = []

        for member in members:
            member_state = member["state"]
            member_name = member.get("name", "unknown")
            optime = member.get("optime", {})

            if member_state == PRIMARY_STATE:
                primary_optime = optime.get("ts")
                if primary_optime:
                    primary_optime = primary_optime.time
                primary_name = member_name
            elif member_state == SECONDARY_STATE:
                secondary_optime = optime.get("ts")
                if secondary_optime:
                    secondaries.append(
                        {
                            "name": member_name,
                            "optime": secondary_optime.time,
                            "state": member.get("stateStr", "SECONDARY"),
                            "health": member.get("health", 0),
                        }
                    )

        if primary_optime is None:
            formatted_data[
                f"error_{metric_index}"
            ] = f'mongo_replication_error{{db="{MONGO_HOST}", error="no_primary"}} 1'
            metric_index += 1
        else:
            # Add primary info
            formatted_data[
                f"primary_{metric_index}"
            ] = f'mongo_replication_primary{{db="{MONGO_HOST}", primary="{primary_name}"}} 1'
            metric_index += 1

            # Connected secondaries count
            formatted_data[
                f"secondaries_{metric_index}"
            ] = f'mongo_connected_secondaries{{db="{MONGO_HOST}"}} {len(secondaries)}'
            metric_index += 1

            # Per-secondary metrics
            for secondary in secondaries:
                lag_seconds = primary_optime - secondary["optime"]
                health = secondary["health"]
                name = secondary["name"]

                # Lag in seconds
                formatted_data[
                    f"lag_{metric_index}"
                ] = f'mongo_replication_lag_seconds{{db="{MONGO_HOST}", secondary="{name}"}} {lag_seconds}'
                metric_index += 1

                # Health status (1=healthy, 0=unhealthy)
                formatted_data[
                    f"health_{metric_index}"
                ] = f'mongo_secondary_health{{db="{MONGO_HOST}", secondary="{name}"}} {int(health)}'
                metric_index += 1

            # Max lag across all secondaries (for alerting)
            if secondaries:
                max_lag = max(primary_optime - s["optime"] for s in secondaries)
                formatted_data[
                    f"max_lag_{metric_index}"
                ] = f'mongo_replication_max_lag_seconds{{db="{MONGO_HOST}"}} {max_lag}'
                metric_index += 1

    except pymongo.errors.ServerSelectionTimeoutError as e:
        return Response(f"Server selection timeout: {e}", 500)
    except pymongo.errors.OperationFailure as e:
        formatted_data[
            f"error_{metric_index}"
        ] = f'mongo_replication_error{{db="{MONGO_HOST}", error="operation_failure"}} 1'
        metric_index += 1
    except pymongo.errors.NotPrimaryError as e:
        formatted_data[
            f"error_{metric_index}"
        ] = f'mongo_replication_error{{db="{MONGO_HOST}", error="not_primary"}} 1'
        metric_index += 1
    except Exception as e:
        formatted_data[
            f"error_{metric_index}"
        ] = f'mongo_replication_error{{db="{MONGO_HOST}", error="unknown"}} 1'
        metric_index += 1

    context = {
        "data": formatted_data,
        "chart_name": "mongo_replication",
        "chart_type": "gauge",
    }
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


@app.route("/size/")
def size():
    try:
        stats = connection.newsblur.command("dbstats")
    except pymongo.errors.ServerSelectionTimeoutError as e:
        return Response(f"Server selection timeout: {e}", 500)
    except pymongo.errors.OperationFailure as e:
        return Response(f"Operation failure: {e}", 500)
    except pymongo.errors.NotPrimaryError as e:
        return Response(f"NotMaster error: {e}", 500)
    data = dict(size=stats["fsUsedSize"])
    formatted_data = {}
    for k, v in data.items():
        formatted_data[k] = f'mongo_db_size{{db="{MONGO_HOST}"}} {v}'

    context = {
        "data": formatted_data,
        "chart_name": "db_size_bytes",
        "chart_type": "gauge",
    }
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


@app.route("/ops/")
def ops():
    try:
        status = connection.admin.command("serverStatus")
    except pymongo.errors.ServerSelectionTimeoutError as e:
        return Response(f"Server selection timeout: {e}", 500)
    except pymongo.errors.OperationFailure as e:
        return Response(f"Operation failure: {e}", 500)
    except pymongo.errors.NotPrimaryError as e:
        return Response(f"NotMaster error: {e}", 500)
    data = dict((q, status["opcounters"][q]) for q in status["opcounters"].keys())

    formatted_data = {}
    for k, v in data.items():
        formatted_data[k] = f'mongo_ops{{type="{k}", db="{MONGO_HOST}"}} {v}'

    context = {
        "data": formatted_data,
        "chart_name": "ops",
        "chart_type": "gauge",
    }
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


@app.route("/page-faults/")
def page_faults():
    try:
        status = connection.admin.command("serverStatus")
    except pymongo.errors.ServerSelectionTimeoutError as e:
        return Response(f"Server selection timeout: {e}", 500)
    except pymongo.errors.OperationFailure as e:
        return Response(f"Operation failure: {e}", 500)
    except pymongo.errors.NotPrimaryError as e:
        return Response(f"NotMaster error: {e}", 500)
    try:
        value = status["extra_info"]["page_faults"]
    except KeyError:
        value = "U"
    data = dict(page_faults=value)
    formatted_data = {}
    for k, v in data.items():
        formatted_data[k] = f'mongo_page_faults{{db="{MONGO_HOST}"}} {v}'

    context = {
        "data": formatted_data,
        "chart_name": "page_faults",
        "chart_type": "counter",
    }
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


@app.route("/page-queues/")
def page_queues():
    try:
        status = connection.admin.command("serverStatus")
    except pymongo.errors.ServerSelectionTimeoutError as e:
        return Response(f"Server selection timeout: {e}", 500)
    except pymongo.errors.OperationFailure as e:
        return Response(f"Operation failure: {e}", 500)
    except pymongo.errors.NotPrimaryError as e:
        return Response(f"NotMaster error: {e}", 500)
    data = dict((q, status["globalLock"]["currentQueue"][q]) for q in ("readers", "writers"))
    formatted_data = {}
    for k, v in data.items():
        formatted_data[k] = f'mongo_page_queues{{type="{k}", db="{MONGO_HOST}"}} {v}'

    context = {
        "data": formatted_data,
        "chart_name": "queues",
        "chart_type": "gauge",
    }
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


if __name__ == "__main__":
    print(" ---> Starting NewsBlur Flask Metrics server...")
    app.run(host="0.0.0.0", port=5569)
