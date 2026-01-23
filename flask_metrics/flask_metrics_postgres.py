import psycopg2
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

POSTGRES_HOST = settings.SERVER_NAME


def get_connection():
    """Get a connection to the Postgres database."""
    if settings.DOCKERBUILD:
        host = "db_postgres"
    else:
        host = f"{settings.SERVER_NAME}.node.nyc1.consul"

    return psycopg2.connect(
        host=host,
        port=5432,
        database="newsblur",
        user="newsblur",
        password=settings.DATABASES.get("default", {}).get("PASSWORD", "newsblur"),
        connect_timeout=10,
    )


@app.route("/replication-lag/")
def replication_lag():
    """
    Query pg_stat_replication to get replication lag for connected replicas.
    This must run on the primary server.
    Returns Prometheus metrics for replication lag in seconds and bytes.
    """
    formatted_data = {}
    metric_index = 0

    try:
        conn = get_connection()
        cur = conn.cursor()

        # Check if this is a primary by looking for connected replicas
        cur.execute(
            """
            SELECT
                client_addr,
                client_hostname,
                state,
                sent_lsn,
                write_lsn,
                flush_lsn,
                replay_lsn,
                write_lag,
                flush_lag,
                replay_lag,
                sync_state,
                EXTRACT(EPOCH FROM (now() - backend_start)) as connection_age_seconds,
                pg_wal_lsn_diff(sent_lsn, replay_lsn) as lag_bytes
            FROM pg_stat_replication
        """
        )

        rows = cur.fetchall()

        if not rows:
            # No replicas connected - might be a replica or primary with no replicas
            formatted_data[
                f"no_replicas_{metric_index}"
            ] = f'postgres_connected_replicas{{instance="{POSTGRES_HOST}"}} 0'
            metric_index += 1
        else:
            # Add connected replicas count
            formatted_data[
                f"replicas_{metric_index}"
            ] = f'postgres_connected_replicas{{instance="{POSTGRES_HOST}"}} {len(rows)}'
            metric_index += 1

            for row in rows:
                client_addr = row[0] or "unknown"
                client_hostname = row[1] or ""
                state = row[2] or "unknown"
                write_lag = row[7]  # interval
                flush_lag = row[8]  # interval
                replay_lag = row[9]  # interval
                sync_state = row[10] or "async"
                connection_age = row[11] or 0
                lag_bytes = row[12] or 0

                # Convert intervals to seconds
                write_lag_seconds = write_lag.total_seconds() if write_lag else 0
                flush_lag_seconds = flush_lag.total_seconds() if flush_lag else 0
                replay_lag_seconds = replay_lag.total_seconds() if replay_lag else 0

                # State as numeric: streaming=1, catchup=2, other=0
                if state == "streaming":
                    state_value = 1
                elif state == "catchup":
                    state_value = 2
                else:
                    state_value = 0

                formatted_data[
                    f"state_{metric_index}"
                ] = f'postgres_replica_state{{instance="{POSTGRES_HOST}", client="{client_addr}", state="{state}", sync_state="{sync_state}"}} {state_value}'
                metric_index += 1

                # Write lag
                formatted_data[
                    f"write_lag_{metric_index}"
                ] = f'postgres_replication_write_lag_seconds{{instance="{POSTGRES_HOST}", client="{client_addr}"}} {write_lag_seconds}'
                metric_index += 1

                # Flush lag
                formatted_data[
                    f"flush_lag_{metric_index}"
                ] = f'postgres_replication_flush_lag_seconds{{instance="{POSTGRES_HOST}", client="{client_addr}"}} {flush_lag_seconds}'
                metric_index += 1

                # Replay lag (this is the most meaningful one - time until changes are queryable)
                formatted_data[
                    f"replay_lag_{metric_index}"
                ] = f'postgres_replication_lag_seconds{{instance="{POSTGRES_HOST}", client="{client_addr}"}} {replay_lag_seconds}'
                metric_index += 1

                # Lag in bytes
                formatted_data[
                    f"lag_bytes_{metric_index}"
                ] = f'postgres_replication_lag_bytes{{instance="{POSTGRES_HOST}", client="{client_addr}"}} {lag_bytes}'
                metric_index += 1

                # Connection age
                formatted_data[
                    f"conn_age_{metric_index}"
                ] = f'postgres_replica_connection_age_seconds{{instance="{POSTGRES_HOST}", client="{client_addr}"}} {connection_age}'
                metric_index += 1

        cur.close()
        conn.close()

    except psycopg2.OperationalError as e:
        formatted_data[
            f"error_{metric_index}"
        ] = f'postgres_replication_error{{instance="{POSTGRES_HOST}", error="connection_error"}} 1'
        metric_index += 1
    except psycopg2.Error as e:
        formatted_data[
            f"error_{metric_index}"
        ] = f'postgres_replication_error{{instance="{POSTGRES_HOST}", error="query_error"}} 1'
        metric_index += 1

    context = {
        "data": formatted_data,
        "chart_name": "postgres_replication",
        "chart_type": "gauge",
    }
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


@app.route("/replica-status/")
def replica_status():
    """
    Check if this server is a replica and get its status.
    This should run on replica servers.
    """
    formatted_data = {}
    metric_index = 0

    try:
        conn = get_connection()
        cur = conn.cursor()

        # Check if we're in recovery (i.e., a replica)
        cur.execute("SELECT pg_is_in_recovery()")
        is_replica = cur.fetchone()[0]

        formatted_data[
            f"is_replica_{metric_index}"
        ] = f'postgres_is_replica{{instance="{POSTGRES_HOST}"}} {1 if is_replica else 0}'
        metric_index += 1

        if is_replica:
            # Get replica status
            cur.execute(
                """
                SELECT
                    pg_last_wal_receive_lsn(),
                    pg_last_wal_replay_lsn(),
                    pg_last_xact_replay_timestamp(),
                    EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())) as lag_seconds
            """
            )
            row = cur.fetchone()
            if row:
                lag_seconds = row[3] if row[3] else 0
                formatted_data[
                    f"lag_{metric_index}"
                ] = f'postgres_replica_lag_seconds{{instance="{POSTGRES_HOST}"}} {lag_seconds}'
                metric_index += 1

        cur.close()
        conn.close()

    except psycopg2.Error as e:
        formatted_data[
            f"error_{metric_index}"
        ] = f'postgres_replication_error{{instance="{POSTGRES_HOST}", error="query_error"}} 1'
        metric_index += 1

    context = {
        "data": formatted_data,
        "chart_name": "postgres_replica_status",
        "chart_type": "gauge",
    }
    html_body = render_template("prometheus_data.html", **context)
    return Response(html_body, content_type="text/plain")


if __name__ == "__main__":
    print(" ---> Starting NewsBlur Flask Metrics Postgres server...")
    app.run(host="0.0.0.0", port=5569)
