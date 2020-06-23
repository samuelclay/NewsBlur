#!/srv/newsblur/venv/newsblur/bin/python

import sys
sys.path.append('/srv/newsblur')

import subprocess
import requests
import settings
import socket
import pymongo

def main():
    df = subprocess.Popen(["df", "/"], stdout=subprocess.PIPE)
    output = df.communicate()[0]
    device, size, used, available, percent, mountpoint = output.split("\n")[1].split()
    hostname = socket.gethostname()
    percent = int(percent.strip('%'))
    admin_email = settings.ADMINS[0][1]
    failed = False
    feeds_fetched = 0
    
    try:
        client = pymongo.MongoClient('mongodb://%s' % settings.MONGO_DB['host'])
        feeds_fetched = client.newsblur.statistics.find_one({"key": "feeds_fetched"})['value']
    except Exception as e:
        failed = e
    
    if feeds_fetched < 5000000:
        failed = True
    
    if failed:
        requests.post(
                "https://api.mailgun.net/v2/%s/messages" % settings.MAILGUN_SERVER_NAME,
                auth=("api", settings.MAILGUN_ACCESS_KEY),
                data={"from": "NewsBlur Task Monitor: %s <admin@%s.newsblur.com>" % (hostname, hostname),
                      "to": [admin_email],
                      "subject": "%s feeds fetched falling: %s" % (hostname, feeds_fetched),
                      "text": "Feed fetches are falling (%s): %s" % (hostname, feeds_fetched, failed)})
        print(" ---> Feeds fetched falling! %s" % (feeds_fetched))
    else:
        print(" ---> Feeds fetched OK: %s" % (feeds_fetched))
        
if __name__ == '__main__':
    main()
