#!/usr/bin/env python

import os
import re
import time
import select
import subprocess
import sys
import json
from pprint import pprint
from requests.exceptions import ConnectionError

sys.path.insert(0, '/srv/newsblur')
os.environ['DJANGO_SETTINGS_MODULE'] = 'newsblur_web.settings'

NEWSBLUR_USERNAME = 'nb'
IGNORE_HOSTS = [
    'app-push',
]

def main(role, find):
    delay = 1

    hosts = subprocess.check_output(['ansible-inventory', '--list'])
    if not hosts:
        print(" ***> Could not load ansible-inventory!")
        return
    hosts = json.loads(hosts)

    path = "/srv/newsblur/logs/newsblur.log*"
    command = "zgrep \"%s\" %s" % (find, path)
    # if exclude:
    #     command += " | zgrep -v \"%s\"" % exclude
    print(f" ---> {command}")

    while True:
        try:
            streams = create_streams_for_role(hosts, role, command=command)
            print(" --- Loading %s %s Log Tails ---" % (len(streams), role))
            read_streams(streams)
        # except UnicodeDecodeError: # unexpected end of data
        #     print " --- Lost connections - Retrying... ---"
        #     time.sleep(1)
        #     continue
        except ConnectionError:
            print(" --- Retrying in %s seconds... ---" % delay)
            time.sleep(delay)
            delay += 1
            continue
        except KeyboardInterrupt:
            print(" --- End of Logging ---")
            break

def create_streams_for_role(hosts, role, command):
    streams = list()
    found = set()
    if role in hosts:
        for hostname in hosts[role]['hosts']:
            if any(h in hostname for h in IGNORE_HOSTS) and role != 'push': continue
            follow_host(hosts, streams, found, hostname, command)
    else:
        host = role
        follow_host(hosts, streams, found, host, command)

    return streams

def follow_host(hosts, streams, found, hostname, command=None):
    if isinstance(hostname, dict):
        address = hostname['address']
        hostname = hostname['name']
    elif ':' in hostname:
        hostname, address = hostname.split(':', 1)
    elif isinstance(hostname, tuple):
        hostname, address = hostname[0], hostname[1]
    else:
        address = hosts['_meta']['hostvars'][hostname]['ansible_host']
        print(" ---> Following %s \t[%s]" % (hostname, address))
    if hostname in found: return
    s = subprocess.Popen(["ssh", "-l", NEWSBLUR_USERNAME, 
                            "-i", os.path.expanduser("/srv/secrets-newsblur/keys/docker.key"),
                            address, command], stdout=subprocess.PIPE)
    s.name = hostname
    streams.append(s)
    found.add(hostname)

def read_streams(streams):
    while True:
        r, _, _ = select.select(
            [stream.stdout.fileno() for stream in streams], [], [])
        for fileno in r:
            for stream in streams:
                if stream.stdout.fileno() != fileno:
                    continue
                data = os.read(fileno, 4096)
                if not data:
                    streams.remove(stream)
                    break
                try:
                    combination_message = "[%-13s] %s" % (stream.name[:13], data.decode())
                except UnicodeDecodeError:
                    continue
                sys.stdout.write(combination_message)
                sys.stdout.flush()
                break

if __name__ == "__main__":
    main(*sys.argv[1:])
