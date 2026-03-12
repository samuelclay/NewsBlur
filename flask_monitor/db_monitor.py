import os

import elasticsearch
import psycopg2
import pymongo
import pymysql
import redis
import sentry_sdk
from flask import Flask, Response, abort, request
from sentry_sdk.integrations.flask import FlaskIntegration

from newsblur_web import settings

sentry_sdk.init(
    dsn=settings.FLASK_SENTRY_DSN,
    integrations=[FlaskIntegration()],
    traces_sample_rate=0,
)

app = Flask(__name__)

PRIMARY_STATE = 1
SECONDARY_STATE = 2


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
    client = None
    try:
        client = pymongo.MongoClient(
            f"mongodb://{settings.MONGO_DB['username']}:{settings.MONGO_DB['password']}@{settings.SERVER_NAME}.node.nyc1.consul/?authSource=admin"
        )
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
    except Exception as e:
        abort(Response(f"Error checking replica status: {str(e)}", 508))
    finally:
        if client:
            client.close()


@app.route("/db_check/mongo_analytics")
def db_check_mongo_analytics():
    if request.args.get("consul") == "1":
        return str(1)

    client = None
    try:
        client = pymongo.MongoClient(
            f"mongodb://{settings.MONGO_ANALYTICS_DB['username']}:{settings.MONGO_ANALYTICS_DB['password']}@{settings.SERVER_NAME}.node.consul/?authSource=admin"
        )
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
    except Exception as e:
        abort(Response(f"Error checking analytics: {str(e)}", 507))
    finally:
        if client:
            client.close()


@app.route("/db_check/redis_user")
def db_check_redis_user():
    if request.args.get("consul") == "1":
        return str(1)

    port = request.args.get("port", settings.REDIS_USER_PORT)
    r = None

    try:
        r = redis.Redis(f"{settings.SERVER_NAME}.node.nyc1.consul", port=port, db=0)
        randkey = r.randomkey()
    except:
        abort(Response("Can't connect to db", 503))
    finally:
        if r:
            r.close()

    if randkey:
        return str(randkey)
    else:
        abort(Response("Can't find a randomkey", 505))


@app.route("/db_check/redis_story")
def db_check_redis_story():
    if request.args.get("consul") == "1":
        return str(1)

    port = request.args.get("port", settings.REDIS_STORY_PORT)
    r = None

    try:
        r = redis.Redis(f"{settings.SERVER_NAME}.node.nyc1.consul", port=port, db=1)
        randkey = r.randomkey()
    except:
        abort(Response("Can't connect to db", 503))
    finally:
        if r:
            r.close()

    if randkey:
        return str(randkey)
    else:
        abort(Response("Can't find a randomkey", 505))


@app.route("/db_check/redis_sessions")
def db_check_redis_sessions():
    if request.args.get("consul") == "1":
        return str(1)

    port = request.args.get("port", settings.REDIS_SESSION_PORT)
    r = None

    try:
        r = redis.Redis(f"{settings.SERVER_NAME}.node.nyc1.consul", port=port, db=5)
        randkey = r.randomkey()
    except:
        abort(Response("Can't connect to db", 503))
    finally:
        if r:
            r.close()

    if randkey:
        return str(randkey)
    else:
        abort(Response("Can't find a randomkey", 505))


@app.route("/db_check/redis_pubsub")
def db_check_redis_pubsub():
    if request.args.get("consul") == "1":
        return str(1)

    port = request.args.get("port", settings.REDIS_PUBSUB_PORT)
    r = None

    try:
        r = redis.Redis(f"{settings.SERVER_NAME}.node.nyc1.consul", port=port, db=1)
        pubsub_numpat = r.pubsub_numpat()
    except:
        abort(Response("Can't connect to db", 503))
    finally:
        if r:
            r.close()

    if pubsub_numpat or isinstance(pubsub_numpat, int):
        return str(pubsub_numpat)
    else:
        abort(Response("Can't find a pubsub_numpat", 505))


@app.route("/db_check/elasticsearch")
def db_check_elasticsearch():
    if request.args.get("consul") == "1":
        return str(1)

    conn = None
    try:
        conn = elasticsearch.Elasticsearch(f"http://{settings.SERVER_NAME}.node.nyc1.consul:9200")
        if conn.indices.exists(index="discover-feeds-openai-index"):
            return str("Index exists, but didn't try search")
        else:
            abort(Response("Couldn't find discover-feeds-openai-index", 504))
    except:
        abort(Response("Can't connect to db", 503))
    finally:
        if conn:
            conn.close()


if __name__ == "__main__":
    print(" ---> Starting NewsBlur DB monitor flask server...")
    app.run(host="0.0.0.0", port=5579)
