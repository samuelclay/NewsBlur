import os

import elasticsearch
import psycopg2
import pymongo
import pymysql
import redis
import sentry_sdk
from flask import Flask, Response, abort, request
from sentry_sdk.integrations.flask import FlaskIntegration
from werkzeug.exceptions import HTTPException

from newsblur_web import settings

sentry_sdk.init(
    dsn=settings.FLASK_SENTRY_DSN,
    integrations=[FlaskIntegration()],
    traces_sample_rate=0,
)

app = Flask(__name__)

PRIMARY_STATE = 1
SECONDARY_STATE = 2

# Health checks hit these endpoints every few seconds, forever. Building a new
# MongoClient/Redis/Elasticsearch per request churned through allocations across
# the dev server's per-request threads, which glibc never returns to the OS: on
# hdb-mongo-secondary-3 this monitor reached 4.5GB RSS in three weeks (a fresh
# process is ~105MB) and helped OOM the box. These drivers are all designed to
# be long-lived singletons that reconnect internally, so build each one once.
#
# Postgres and MySQL are deliberately left per-request below: a raw psycopg2 or
# pymysql connection does not transparently reconnect, so a cached one that went
# stale would report a healthy database as down.
_mongo_client = None
_mongo_analytics_client = None
_elasticsearch_client = None
_redis_clients = {}


def get_mongo_client():
    global _mongo_client
    if _mongo_client is None:
        _mongo_client = pymongo.MongoClient(
            f"mongodb://{settings.MONGO_DB['username']}:{settings.MONGO_DB['password']}@{settings.SERVER_NAME}.node.nyc1.consul/?authSource=admin"
        )
    return _mongo_client


def get_mongo_analytics_client():
    global _mongo_analytics_client
    if _mongo_analytics_client is None:
        # db_monitor.py runs on the Mongo host itself. The analytics sidecar
        # publishes container port 27017 on host port 27018.
        _mongo_analytics_client = pymongo.MongoClient(
            f"mongodb://{settings.MONGO_ANALYTICS_DB['username']}:{settings.MONGO_ANALYTICS_DB['password']}@127.0.0.1:27018/?authSource=admin"
        )
    return _mongo_analytics_client


def get_elasticsearch_client():
    global _elasticsearch_client
    if _elasticsearch_client is None:
        _elasticsearch_client = elasticsearch.Elasticsearch(
            f"http://{settings.SERVER_NAME}.node.nyc1.consul:9200"
        )
    return _elasticsearch_client


def get_redis_client(port, db):
    key = (port, db)
    if key not in _redis_clients:
        _redis_clients[key] = redis.Redis(f"{settings.SERVER_NAME}.node.nyc1.consul", port=port, db=db)
    return _redis_clients[key]


@app.route("/db_check/postgres")
def db_check_postgres():
    if request.args.get("consul") == "1":
        return str(1)

    connect_params = "dbname='%s' user='%s' password='%s' host='%s' port='%s'" % (
        settings.DATABASES["default"]["NAME"],
        settings.DATABASES["default"]["USER"],
        settings.DATABASES["default"]["PASSWORD"],
        f"{settings.SERVER_NAME}.node.nyc1.consul",
        settings.DATABASES["default"]["PORT"],
    )
    conn = None
    try:
        conn = psycopg2.connect(connect_params)
        cur = conn.cursor()
        cur.execute("""SELECT id FROM feeds ORDER BY feeds.id DESC LIMIT 1""")
        rows = cur.fetchall()
        for row in rows:
            return str(row[0])
        abort(Response("No rows found", 504))
    except psycopg2.Error:
        print(" ---> Postgres can't connect to the database: %s" % connect_params)
        abort(Response("Can't connect to db", 503))
    finally:
        if conn:
            conn.close()


@app.route("/db_check/mysql")
def db_check_mysql():
    if request.args.get("consul") == "1":
        return str(1)

    conn = None
    try:
        conn = pymysql.connect(
            host="mysql",
            port=settings.DATABASES["default"]["PORT"],
            user=settings.DATABASES["default"]["USER"],
            passwd=settings.DATABASES["default"]["PASSWORD"],
            db=settings.DATABASES["default"]["NAME"],
        )
        cur = conn.cursor()
        cur.execute("""SELECT id FROM feeds ORDER BY feeds.id DESC LIMIT 1""")
        rows = cur.fetchall()
        for row in rows:
            return str(row[0])
        abort(Response("No rows found", 504))
    except pymysql.Error:
        print(" ---> Mysql can't connect to the database")
        abort(Response("Can't connect to mysql db", 503))
    finally:
        if conn:
            conn.close()


@app.route("/db_check/mongo")
def db_check_mongo():
    if request.args.get("consul") == "1":
        return str(1)

    # The `mongo` hostname below is a reference to the newsblurnet docker network, where 172.18.0.0/16 is defined
    try:
        client = get_mongo_client()
        db = client.newsblur

        stories = db.stories.estimated_document_count()
        if not stories:
            abort(Response("No stories", 510))

        status = client.admin.command("replSetGetStatus")
        members = status["members"]
        primary_optime = None
        oldest_secondary_optime = None
        for member in members:
            member_state = member["state"]
            optime = member["optime"]
            if member_state == PRIMARY_STATE:
                primary_optime = optime["ts"].time
            elif member_state == SECONDARY_STATE:
                if not oldest_secondary_optime or optime["ts"].time < oldest_secondary_optime:
                    oldest_secondary_optime = optime["ts"].time

        if not primary_optime or not oldest_secondary_optime:
            abort(Response("No optime", 511))

        # if primary_optime - oldest_secondary_optime > 100:
        #     abort(Response("Data is too old", 512))

        return str(stories)

    except pymongo.errors.NotMasterError:
        abort(Response("Not Master", 504))
    except pymongo.errors.ServerSelectionTimeoutError:
        abort(Response("Server selection timeout", 503))
    except pymongo.errors.OperationFailure as e:
        if "Authentication failed" in str(e):
            abort(Response("Auth failed", 506))
        abort(Response("Operation Failure", 507))
    except HTTPException:
        # abort() above raises HTTPException; don't mask it as a generic 508.
        raise
    except Exception as e:
        abort(Response(f"Error checking replica status: {str(e)}", 508))


@app.route("/db_check/mongo_analytics")
def db_check_mongo_analytics():
    if request.args.get("consul") == "1":
        return str(1)

    try:
        client = get_mongo_analytics_client()
        db = client.nbanalytics

        fetches = db.feed_fetches.estimated_document_count()
        if not fetches:
            abort(Response("No fetches in data", 510))

        return str(fetches)

    except (pymongo.errors.NotMasterError, pymongo.errors.ServerSelectionTimeoutError):
        abort(Response("Not Master / Server selection timeout", 504))
    except pymongo.errors.OperationFailure as e:
        if "Authentication failed" in str(e):
            abort(Response("Auth failed", 505))
        abort(Response("Operation failure", 506))
    except HTTPException:
        # abort() above (e.g. the 510) raises HTTPException — re-raise it so the
        # generic `except Exception` below doesn't mask it as a confusing 507.
        raise
    except Exception as e:
        abort(Response(f"Error checking analytics: {str(e)}", 507))


@app.route("/db_check/redis_user")
def db_check_redis_user():
    if request.args.get("consul") == "1":
        return str(1)

    port = request.args.get("port", settings.REDIS_USER_PORT)

    try:
        randkey = get_redis_client(port, 0).randomkey()
    except:
        abort(Response("Can't connect to db", 503))

    if randkey:
        return str(randkey)
    else:
        abort(Response("Can't find a randomkey", 505))


@app.route("/db_check/redis_story")
def db_check_redis_story():
    if request.args.get("consul") == "1":
        return str(1)

    port = request.args.get("port", settings.REDIS_STORY_PORT)

    try:
        randkey = get_redis_client(port, 1).randomkey()
    except:
        abort(Response("Can't connect to db", 503))

    if randkey:
        return str(randkey)
    else:
        abort(Response("Can't find a randomkey", 505))


@app.route("/db_check/redis_sessions")
def db_check_redis_sessions():
    if request.args.get("consul") == "1":
        return str(1)

    port = request.args.get("port", settings.REDIS_SESSION_PORT)

    try:
        randkey = get_redis_client(port, 5).randomkey()
    except:
        abort(Response("Can't connect to db", 503))

    if randkey:
        return str(randkey)
    else:
        abort(Response("Can't find a randomkey", 505))


@app.route("/db_check/redis_pubsub")
def db_check_redis_pubsub():
    if request.args.get("consul") == "1":
        return str(1)

    port = request.args.get("port", settings.REDIS_PUBSUB_PORT)

    try:
        pubsub_numpat = get_redis_client(port, 1).pubsub_numpat()
    except:
        abort(Response("Can't connect to db", 503))

    if pubsub_numpat or isinstance(pubsub_numpat, int):
        return str(pubsub_numpat)
    else:
        abort(Response("Can't find a pubsub_numpat", 505))


@app.route("/db_check/elasticsearch")
def db_check_elasticsearch():
    if request.args.get("consul") == "1":
        return str(1)

    try:
        conn = get_elasticsearch_client()
        if conn.indices.exists(index="discover-feeds-openai-index"):
            return str("Index exists, but didn't try search")
        else:
            abort(Response("Couldn't find discover-feeds-openai-index", 504))
    except HTTPException:
        # abort() above raises HTTPException; don't report a healthy ES as down.
        raise
    except:
        abort(Response("Can't connect to db", 503))


if __name__ == "__main__":
    print(" ---> Starting NewsBlur DB monitor flask server...")
    app.run(host="0.0.0.0", port=5579)
