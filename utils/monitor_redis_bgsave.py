#!/srv/newsblur/venv/newsblur/bin/python

import sys
sys.path.append('/srv/newsblur')

import os
import datetime
import requests
import settings
import socket

def main():
    t = os.popen('stat -c%Y /var/lib/redis/dump.rdb')
    timestamp = t.read().split('\n')[0]
    modified = datetime.datetime.fromtimestamp(int(timestamp))
    ten_min_ago = datetime.datetime.now() - datetime.timedelta(minutes=10)
    hostname = socket.gethostname()
    modified_minutes = datetime.datetime.now() - modified
    log_tail = os.popen('tail -n 100 /var/log/redis.log').read()
    
    if modified < ten_min_ago:
        requests.post(
                "https://api.mailgun.net/v2/%s/messages" % settings.MAILGUN_SERVER_NAME,
                auth=("api", settings.MAILGUN_ACCESS_KEY),
                data={"from": "NewsBlur Redis Monitor: %s <admin@%s.newsblur.com>" % (hostname, hostname),
                      "to": [settings.ADMINS[0][1]],
                      "subject": "%s hasn't bgsave'd redis in %s!" % (hostname, modified_minutes),
                      "text": "Last modified %s: %s ago\n\n----\n\n%s" % (hostname, modified_minutes, log_tail)})
    else:
        print(" ---> Redis bgsave fine: %s / %s ago" % (hostname, modified_minutes))
        
if __name__ == '__main__':
    main()
