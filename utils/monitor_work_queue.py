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
    work_queue_size = 0
    QUEUE_DROP_AMOUNT = 0
    redis_work_queue = 0
    monitor_key = "Monitor:work_queue"
    r_monitor = redis.Redis(connection_pool=settings.REDIS_ANALYTICS_POOL)
    r = redis.Redis(connection_pool=settings.REDIS_FEED_UPDATE_POOL)

    try:
        work_queue_size = int(r.llen("work_queue"))
        redis_work_queue = int(r_monitor.get(monitor_key) or 0)
    except Exception as e:
        failed = e
    
    if work_queue_size > 300 and work_queue_size > (redis_work_queue + QUEUE_DROP_AMOUNT):
        failed = True

    if failed:
        requests.post(
                "https://api.mailgun.net/v2/%s/messages" % settings.MAILGUN_SERVER_NAME,
                auth=("api", settings.MAILGUN_ACCESS_KEY),
                data={"from": "NewsBlur Queue Monitor: %s <admin@%s.newsblur.com>" % (hostname, hostname),
                      "to": [admin_email],
                      "subject": "%s work queue rising: %s (from %s)" % (hostname, work_queue_size, redis_work_queue),
                      "text": "Work queue is rising: %s (from %s) %s" % (work_queue_size, redis_work_queue, failed)})

        r_monitor.set(monitor_key, work_queue_size)
        r_monitor.expire(monitor_key, 60*60*3) # 3 hours

        print(" ---> Work queue rising! %s %s" % (work_queue_size, failed))
    else:
        print(" ---> Work queue OK: %s" % (work_queue_size))
        
if __name__ == '__main__':
    main()
