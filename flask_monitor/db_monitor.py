from flask import Flask, abort, request, Response
import os
import psycopg2
import pymysql
import pymongo
import redis
import elasticsearch

from newsblur_web import settings

import sentry_sdk
from flask import Flask
from sentry_sdk.integrations.flask import FlaskIntegration

sentry_sdk.init(
    dsn=settings.FLASK_SENTRY_DSN,
    integrations=[FlaskIntegration()],
    traces_sample_rate=0.001,
)

app = Flask(__name__)

PRIMARY_STATE = 1
SECONDARY_STATE = 2

@app.route("/db_check/postgres")
def db_check_postgres():
    if request.args.get('consul') == '1':
        return str(1)

    connect_params = "dbname='%s' user='%s' password='%s' host='%s' port='%s'" % (
        settings.DATABASES['default']['NAME'],
        settings.DATABASES['default']['USER'],
        settings.DATABASES['default']['PASSWORD'],
        f'{settings.SERVER_NAME}.node.nyc1.consul',
        settings.DATABASES['default']['PORT'],
    )
    try:
        conn = psycopg2.connect(connect_params)
    except:
        print(" ---> Postgres can't connect to the database: %s" % connect_params)
        abort(Response("Can't connect to db", 503))

    cur = conn.cursor()
    cur.execute("""SELECT id FROM feeds ORDER BY feeds.id DESC LIMIT 1""")
    rows = cur.fetchall()
    for row in rows:
        return str(row[0])
    
    abort(Response("No rows found", 504))

@app.route("/db_check/mysql")
def db_check_mysql():
    if request.args.get('consul') == '1':
        return str(1)

    connect_params = "dbname='%s' user='%s' password='%s' host='%s' port='%s'" % (
        settings.DATABASES['default']['NAME'],
        settings.DATABASES['default']['USER'],
        settings.DATABASES['default']['PASSWORD'],
        settings.DATABASES['default']['HOST'],
        settings.DATABASES['default']['PORT'],
    )
    try:

        conn = pymysql.connect(host='mysql',
                               port=settings.DATABASES['default']['PORT'],
                               user=settings.DATABASES['default']['USER'],
                               passwd=settings.DATABASES['default']['PASSWORD'],
                               db=settings.DATABASES['default']['NAME'])
    except:
        print(" ---> Mysql can't connect to the database: %s" % connect_params)
        abort(Response("Can't connect to mysql db", 503))

    cur = conn.cursor()
    cur.execute("""SELECT id FROM feeds ORDER BY feeds.id DESC LIMIT 1""")
    rows = cur.fetchall()
    for row in rows:
        return str(row[0])
    
    abort(Response("No rows found", 504))

@app.route("/db_check/mongo")
def db_check_mongo():
    if request.args.get('consul') == '1':
        return str(1)

    try:
        # The `mongo` hostname below is a reference to the newsblurnet docker network, where 172.18.0.0/16 is defined
        client = pymongo.MongoClient(f"mongodb://{settings.MONGO_DB['username']}:{settings.MONGO_DB['password']}@{settings.SERVER_NAME}.node.nyc1.consul/?authSource=admin")
        db = client.newsblur
    except:
        abort(Response("Can't connect to db", 503))

    try:
        stories = db.stories.estimated_document_count()
    except pymongo.errors.NotMasterError:
        abort(Response("Not Master", 504))
    except pymongo.errors.ServerSelectionTimeoutError:
        abort(Response("Server selection timeout", 503))
    except pymongo.errors.OperationFailure as e:
        if 'Authentication failed' in str(e):
            abort(Response("Auth failed", 506))
        abort(Response("Operation Failure", 507))
        
    if not stories:
        abort(Response("No stories", 510))
    
    status = client.admin.command('replSetGetStatus')
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
        abort(Response("No optime", 511))

    # if primary_optime - oldest_secondary_optime > 100:
    #     abort(Response("Data is too old", 512))

    return str(stories)

@app.route("/db_check/mongo_analytics")
def db_check_mongo_analytics():
    if request.args.get('consul') == '1':
        return str(1)

    try:
        client = pymongo.MongoClient(f"mongodb://{settings.MONGO_ANALYTICS_DB['username']}:{settings.MONGO_ANALYTICS_DB['password']}@{settings.SERVER_NAME}/?authSource=admin")
        db = client.nbanalytics
    except:
        abort(Response("Can't connect to db", 503))
    
    try:
        fetches = db.feed_fetches.estimated_document_count()
    except (pymongo.errors.NotMasterError, pymongo.errors.ServerSelectionTimeoutError):
        abort(Response("Not Master / Server selection timeout", 504))
    except pymongo.errors.OperationFailure as e:
        if 'Authentication failed' in str(e):
            abort(Response("Auth failed", 505))
        abort(Response("Operation failure", 506))
        
    if not fetches:
        abort(Response("No fetches in data", 510))
    
    return str(fetches)

@app.route("/db_check/redis_user")
def db_check_redis_user():
    if request.args.get('consul') == '1':
        return str(1)

    try:
        r = redis.Redis('db-redis-user.service.nyc1.consul', db=0)
    except:
        abort(Response("Can't connect to db", 503))
    
    try:
        randkey = r.randomkey()
    except:
        abort(Response("Couldn't process randomkey", 504))

    if randkey:
        return str(randkey)
    else:
        abort(Response("Can't find a randomkey", 505))

@app.route("/db_check/redis_story")
def db_check_redis_story():    
    if request.args.get('consul') == '1':
        return str(1)
    
    try:
        r = redis.Redis('db-redis-story.service.nyc1.consul', db=1)
    except:
        abort(Response("Can't connect to db", 503))
    
    try:
        randkey = r.randomkey()
    except:
        abort(Response("Couldn't process randomkey", 504))

    if randkey:
        return str(randkey)
    else:
        abort(Response("Can't find a randomkey", 505))

@app.route("/db_check/redis_sessions")
def db_check_redis_sessions():
    if request.args.get('consul') == '1':
        return str(1)

    try:
        r = redis.Redis('db-redis-sessions.service.nyc1.consul', db=5)
    except:
        abort(Response("Can't connect to db", 503))
    
    try:
        randkey = r.randomkey()
    except:
        abort(Response("Couldn't process randomkey", 504))

    if randkey:
        return str(randkey)
    else:
        abort(Response("Can't find a randomkey", 505))

@app.route("/db_check/redis_pubsub")
def db_check_redis_pubsub():
    if request.args.get('consul') == '1':
        return str(1)

    try:
        r = redis.Redis('db-redis-pubsub.service.nyc1.consul', db=1)
    except:
        abort(Response("Can't connect to db", 503))
    
    try:
        pubsub_numpat = r.pubsub_numpat()
    except:
        abort(Response("Couldn't process pubsub_numpat", 504))

    if pubsub_numpat or isinstance(pubsub_numpat, int):
        return str(pubsub_numpat)
    else:
        abort(Response("Can't find a pubsub_numpat", 505))

@app.route("/db_check/elasticsearch")
def db_check_elasticsearch():
    try:
        conn = elasticsearch.Elasticsearch("elasticsearch")
    except:
        abort(Response("Can't connect to db", 503))
    
    if request.args.get('consul') == '1':
        return str(1)
    
    if conn.indices.exists('feeds-index'):
        return str("Index exists, but didn't try search")
        # query = pyes.query.TermQuery("title", "daring fireball")
        # results = conn.search(query=query, size=1, doc_types=['feeds-type'], sort="num_subscribers:desc")
        # for result in results:
        #     return unicode(result)
        # else:
        #     abort(Response("Couldn't find any search results", 504))
    else:
        abort(Response("Couldn't find feeds-index", 504))

if __name__ == "__main__":
    print(" ---> Starting NewsBlur DB monitor flask server...")
    app.run(host="0.0.0.0", port=5579)
