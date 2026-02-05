import redis
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

INSTANCES = {
    "db-redis-session": settings.REDIS_SESSIONS,
    "db-redis-story": settings.REDIS_STORY,
    "db-redis-pubsub": settings.REDIS_PUBSUB,
    "db-redis-user": settings.REDIS_USER,
}


class RedisMetric(object):
    def __init__(self, title, fields):
        self.title = title
        self.fields = fields

    def get_info(self):
        r = redis.Redis(self.host, self.port)
        return r.info()

    def redis_servers_stats(self):
        for instance, redis_config in INSTANCES.items():
            if not settings.DOCKERBUILD and instance not in settings.SERVER_NAME:
                continue
            self.host = f"{settings.SERVER_NAME}.node.nyc1.consul"
            if instance == "db-redis-session":
                self.port = redis_config.get("port", settings.REDIS_SESSION_PORT)
            elif instance == "db-redis-story":
                self.port = redis_config.get("port", settings.REDIS_STORY_PORT)
            elif instance == "db-redis-pubsub":
                self.port = redis_config.get("port", settings.REDIS_PUBSUB_PORT)
            elif instance == "db-redis-user":
                self.port = redis_config.get("port", settings.REDIS_USER_PORT)
            stats = self.get_info()
            yield instance, stats

    def execute(self):
        data = {}
        for instance, stats in self.redis_servers_stats():
            values = {}
            for k in self.fields:
                try:
                    value = stats[k[0]]
                except KeyError:
                    value = "U"
                values[k[0]] = value
            data[instance] = values
        return data

    def format_data(self, data):
        label = self.fields[0][1]["label"]
        formatted_data = {}
        for k, v in data.items():
            formatted_data[k] = f'{label}{{db="{k}"}} {v[self.fields[0][0]]}'
        return formatted_data

    def get_db_size_data(self):
        data = {}
        for instance, stats in self.redis_servers_stats():
            dbs = [stat for stat in stats.keys() if stat.startswith("db")]
            for db in dbs:
                data[f"{instance}-{db}"] = f'redis_size{{db="{db}"}} {stats[db]["keys"]}'
        return data

    def get_context(self):
        if self.fields[0][0] == "size":
            formatted_data = self.get_db_size_data()
        else:
            values = self.execute()
            formatted_data = self.format_data(values)
        context = {
            "data": formatted_data,
            "chart_name": self.fields[0][1]["label"],
            "chart_type": self.fields[0][1]["type"],
        }
        return context

    @property
    def response_body(self):
        context = self.get_context()
        return render_template("prometheus_data.html", **context)


@app.route("/active-connections/")
def active_connections():
    conf = {
        "title": "Redis active connections",
        "fields": (
            (
                "connected_clients",
                dict(
                    label="redis_active_connections",
                    type="gauge",
                ),
            ),
        ),
    }
    redis_metric = RedisMetric(**conf)
    return Response(redis_metric.response_body, content_type="text/plain")


@app.route("/commands/")
def commands():
    conf = {
        "title": "Redis commands",
        "fields": (
            (
                "total_commands_processed",
                dict(
                    label="redis_commands",
                    type="gauge",
                ),
            ),
        ),
    }
    redis_metric = RedisMetric(**conf)
    context = redis_metric.get_context()
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


@app.route("/connects/")
def connects():
    conf = {
        "title": "Redis connections per second",
        "fields": (
            (
                "total_connections_received",
                dict(
                    label="redis_connects",
                    type="counter",
                ),
            ),
        ),
    }
    redis_metric = RedisMetric(**conf)
    context = redis_metric.get_context()
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


@app.route("/size/")
def size():
    conf = {
        "title": "Redis DB size",
        "fields": (
            (
                "size",
                dict(
                    label="redis_size",
                    type="gauge",
                ),
            ),
        ),
    }
    redis_metric = RedisMetric(**conf)
    context = redis_metric.get_context()
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


@app.route("/memory/")
def memory():
    conf = {
        "title": "Redis Total Memory",
        "fields": (
            (
                "total_system_memory",
                dict(
                    label="redis_memory",
                    type="gauge",
                ),
            ),
        ),
    }
    redis_metric = RedisMetric(**conf)
    context = redis_metric.get_context()
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


@app.route("/used-memory/")
def memory_used():
    conf = {
        "title": "Redis Used Memory",
        "fields": (
            (
                "used_memory",
                dict(
                    label="redis_used_memory",
                    type="gauge",
                ),
            ),
        ),
    }
    redis_metric = RedisMetric(**conf)
    context = redis_metric.get_context()
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


@app.route("/replication-lag/")
def replication_lag():
    """
    Query each Redis primary for INFO replication and parse slave lag values.
    Returns Prometheus metrics for replication lag in seconds.
    """
    formatted_data = {}
    metric_index = 0

    for instance, redis_config in INSTANCES.items():
        if not settings.DOCKERBUILD and instance not in settings.SERVER_NAME:
            continue

        host = f"{settings.SERVER_NAME}.node.nyc1.consul"
        if instance == "db-redis-session":
            port = redis_config.get("port", settings.REDIS_SESSION_PORT)
        elif instance == "db-redis-story":
            port = redis_config.get("port", settings.REDIS_STORY_PORT)
        elif instance == "db-redis-pubsub":
            port = redis_config.get("port", settings.REDIS_PUBSUB_PORT)
        elif instance == "db-redis-user":
            port = redis_config.get("port", settings.REDIS_USER_PORT)
        else:
            continue

        try:
            r = redis.Redis(host, port)
            info = r.info("replication")

            role = info.get("role", "unknown")
            connected_slaves = info.get("connected_slaves", 0)

            # Add role metric
            role_value = 1 if role == "master" else 0
            formatted_data[
                f"role_{metric_index}"
            ] = f'redis_replication_role{{instance="{instance}", role="{role}"}} {role_value}'
            metric_index += 1

            # Add connected slaves metric
            formatted_data[
                f"slaves_{metric_index}"
            ] = f'redis_connected_slaves{{instance="{instance}"}} {connected_slaves}'
            metric_index += 1

            # Parse slave info - format: slaveN:ip=X,port=Y,state=Z,offset=N,lag=N
            for key, value in info.items():
                if key.startswith("slave") and key[5:].isdigit():
                    slave_num = key[5:]
                    # Parse the slave info string
                    slave_info = {}
                    if isinstance(value, str):
                        for part in value.split(","):
                            if "=" in part:
                                k, v = part.split("=", 1)
                                slave_info[k] = v
                    elif isinstance(value, dict):
                        slave_info = value

                    slave_ip = slave_info.get("ip", "unknown")
                    slave_state = slave_info.get("state", "unknown")
                    lag = slave_info.get("lag", "0")

                    # State as numeric: online=1, other=0
                    state_value = 1 if slave_state == "online" else 0
                    formatted_data[
                        f"state_{metric_index}"
                    ] = f'redis_slave_state{{instance="{instance}", slave="{slave_num}", slave_ip="{slave_ip}"}} {state_value}'
                    metric_index += 1

                    # Lag in seconds
                    formatted_data[
                        f"lag_{metric_index}"
                    ] = f'redis_replication_lag_seconds{{instance="{instance}", slave="{slave_num}", slave_ip="{slave_ip}"}} {lag}'
                    metric_index += 1

        except redis.ConnectionError as e:
            formatted_data[
                f"error_{metric_index}"
            ] = f'redis_replication_error{{instance="{instance}", error="connection_error"}} 1'
            metric_index += 1
        except redis.TimeoutError as e:
            formatted_data[
                f"error_{metric_index}"
            ] = f'redis_replication_error{{instance="{instance}", error="timeout"}} 1'
            metric_index += 1

    context = {
        "data": formatted_data,
        "chart_name": "redis_replication",
        "chart_type": "gauge",
    }
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


if __name__ == "__main__":
    print(" ---> Starting NewsBlur Flask Metrics server...")
    app.run(host="0.0.0.0", port=5569)
