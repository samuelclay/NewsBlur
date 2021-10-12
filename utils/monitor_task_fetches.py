#!/usr/local/bin/python3

import sys
sys.path.append('/srv/newsblur')

import requests
from newsblur_web import settings
import socket
import redis
import pymongo

def main():
    hostname = socket.gethostname()
    admin_email = settings.ADMINS[0][1]
    failed = False
    feeds_fetched = 0
    FETCHES_DROP_AMOUNT = 100000
    redis_task_fetches = 0
    monitor_key = "Monitor:task_fetches"
    r = redis.Redis(connection_pool=settings.REDIS_ANALYTICS_POOL)

    try:
        client = pymongo.MongoClient(f"mongodb://{settings.MONGO_DB['username']}:{settings.MONGO_DB['password']}@{settings.MONGO_DB['host']}/?authSource=admin")
        feeds_fetched = client.newsblur.statistics.find_one({"key": "feeds_fetched"})['value']
        redis_task_fetches = int(r.get(monitor_key) or 0)
    except Exception as e:
        failed = e
    
    if feeds_fetched < 5000000 and not failed:
        if redis_task_fetches > 0 and feeds_fetched < (redis_task_fetches - FETCHES_DROP_AMOUNT):
            failed = True
        # Ignore 0's below, as they simply imply low number, not falling    
        # elif redis_task_fetches <= 0:
        #     failed = True
    if failed:
        requests.post(
                "https://api.mailgun.net/v2/%s/messages" % settings.MAILGUN_SERVER_NAME,
                auth=("api", settings.MAILGUN_ACCESS_KEY),
                data={"from": "NewsBlur Task Monitor: %s <admin@%s.newsblur.com>" % (hostname, hostname),
                      "to": [admin_email],
                      "subject": "%s feeds fetched falling: %s (from %s)" % (hostname, feeds_fetched, redis_task_fetches),
                      "text": "Feed fetches are falling: %s (from %s) %s" % (feeds_fetched, redis_task_fetches, failed)})

        r.set(monitor_key, feeds_fetched)
        r.expire(monitor_key, 60*60*12) # 3 hours

        print(" ---> Feeds fetched falling! %s %s" % (feeds_fetched, failed))
    else:
        print(" ---> Feeds fetched OK: %s" % (feeds_fetched))
        
if __name__ == '__main__':
    main()
