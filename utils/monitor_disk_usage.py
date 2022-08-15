#!/usr/local/bin/python3
import sys
sys.path.append('/srv/newsblur')

import requests
from newsblur_web import settings
import socket

def main():
    disk_usage_output = sys.argv[1]
    disk_usage_output = disk_usage_output.split()
    if len(disk_usage_output) == 5:
        device, size, used, available, percent = disk_usage_output
    elif len(disk_usage_output) == 6:
        device, size, used, available, percent, extra = disk_usage_output
        print(disk_usage_output)

    hostname = socket.gethostname()
    percent = int(percent.strip('%'))
    admin_email = settings.ADMINS[0][1]
    # if True:
    if percent > 90:
        requests.post(
                "https://api.mailgun.net/v2/%s/messages" % settings.MAILGUN_SERVER_NAME,
                auth=("api", settings.MAILGUN_ACCESS_KEY),
                data={"from": "NewsBlur Disk Monitor: %s <admin@%s.newsblur.com>" % (hostname, hostname),
                      "to": [admin_email],
                      "subject": "%s hit %s%% disk usage!" % (hostname, percent),
                      "text": "Usage on %s: %s" % (hostname, disk_usage_output)})
        print(" ---> Disk usage is NOT fine: %s / %s%% used" % (hostname, percent))
    else:
        print(" ---> Disk usage is fine: %s / %s%% used" % (hostname, percent))
        
if __name__ == '__main__':
    main()
