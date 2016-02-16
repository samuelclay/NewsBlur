#!/srv/newsblur/venv/newsblur/bin/python

import sys
sys.path.append('/srv/newsblur')

import psutil
import requests
import settings
import socket

def main():
    usage = psutil.disk_usage('/')
    hostname = socket.gethostname()

    if usage.percent > 95:
        requests.post(
                "https://api.mailgun.net/v2/%s/messages" % settings.MAILGUN_SERVER_NAME,
                auth=("api", settings.MAILGUN_ACCESS_KEY),
                data={"from": "NewsBlur Monitor: %s <admin@%s.newsblur.com>" % (hostname, hostname),
                      "to": [settings.ADMINS[0][1]],
                      "subject": "%s hit %s%% disk usage!" % (hostname, usage.percent),
                      "text": "Usage on %s: %s" % (hostname, usage)})
    else:
        print " ---> Disk usage is fine: %s / %s%% used" % (hostname, usage.percent)
        
if __name__ == '__main__':
    main()
