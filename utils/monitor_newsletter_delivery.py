#!/usr/local/bin/python3

import sys
sys.path.append('/srv/newsblur')

import requests
from newsblur_web import settings
import socket

def main():
    hostname = socket.gethostname()
    admin_email = settings.ADMINS[0][1]

    r = requests.get("https://api.mailgun.net/v3/newsletters.newsblur.com/stats/total",
                     auth=("api", settings.MAILGUN_ACCESS_KEY),
                     params={"event": ["accepted", "delivered", "failed"],
                             "duration": "2h"})
    stats = r.json()['stats'][0]
    delivered = stats['delivered']['total']
    accepted = stats['delivered']['total']
    bounced = stats['failed']['permanent']['total'] + stats['failed']['temporary']['total']
    if bounced / float(delivered) > 0.5:
        requests.post(
                "https://api.mailgun.net/v2/%s/messages" % settings.MAILGUN_SERVER_NAME,
                auth=("api", settings.MAILGUN_ACCESS_KEY),
                data={"from": "NewsBlur Newsletter Monitor: %s <admin@%s.newsblur.com>" % (hostname, hostname),
                      "to": [admin_email],
                      "subject": "%s newsletters bounced (2h): %s/%s accepted/delivered -> %s bounced" % (hostname, accepted, delivered, bounced),
                      "text": "Newsletters are not being delivered! %s delivered, %s bounced" % (delivered, bounced)})
        print(" ---> %s newsletters bounced: %s > %s > %s" % (hostname, accepted, delivered, bounced))
    else:
        print(" ---> %s newsletters OK: %s > %s > %s" % (hostname, accepted, delivered, bounced))
        
if __name__ == '__main__':
    main()
