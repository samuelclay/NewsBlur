#!/usr/bin/env python

import os
import time
import select
import subprocess
import sys
from optparse import OptionParser
from requests.exceptions import ConnectionError

sys.path.insert(0, '/srv/newsblur')
os.environ['DJANGO_SETTINGS_MODULE'] = 'settings'
import fabfile

NEWSBLUR_USERNAME = 'sclay'
IGNORE_HOSTS = [
    'push',
]

def main(role="app", role2="work", command=None):
    delay = 1

    while True:
        try:
            streams = create_streams_for_roles(role, role2, command=command)
            print " --- Loading %s App Log Tails ---" % len(streams)
            read_streams(streams)
        except (UnicodeDecodeError, ConnectionError, KeyboardInterrupt):
            print " --- End of Logging ---"
            break

def create_streams_for_roles(role, role2, command=None):
    streams = list()
    hosts = fabfile.assign_digitalocean_roledefs(split=True)
    found = set()

    if not command:
        command = "tail -f"
    for hostname in (hosts[role] + hosts[role2]):
        if isinstance(hostname, dict):
            address = hostname['address']
            hostname = hostname['name']
        elif ':' in hostname:
            hostname, address = hostname.split(':', 1)
        elif isinstance(hostname, tuple):
            hostname, address = hostname[0], hostname[1]
        else:
            address = hostname
        if any(h in hostname for h in IGNORE_HOSTS): continue
        if hostname in found: continue
        if 'ec2' in hostname:
            s = subprocess.Popen(["ssh", 
                                  "-i", os.path.expanduser(os.path.join(fabfile.env.SECRETS_PATH,
                                                                        "keys/ec2.pem")),
                                  address, command], stdout=subprocess.PIPE)
        else:
            s = subprocess.Popen(["ssh", "-l", NEWSBLUR_USERNAME, 
                                  "-i", os.path.expanduser(os.path.join(fabfile.env.SECRETS_PATH,
                                                                        "keys/newsblur.key")),
                                  address, command], stdout=subprocess.PIPE)
        s.name = hostname
        streams.append(s)
        found.add(hostname)
        
    return streams

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
                combination_message = "[%-6s] %s" % (stream.name[:6], data)
                sys.stdout.write(combination_message)
                break

if __name__ == "__main__":
    parser = OptionParser()
    parser.add_option("-f", "--find", dest="find")
    parser.add_option("-p", "--path", dest="path")
    parser.add_option("-r", "--role", dest="role")
    parser.add_option("-e", "--exclude", dest="exclude")
    (options, args) = parser.parse_args()

    path = options.path or "/srv/newsblur/logs/newsblur.log"
    find = options.find
    role = options.role or 'app'
    exclude = options.exclude or None
    command = "zgrep \"%s\" %s" % (find, path)
    if exclude:
        command += " | zgrep -v \"%s\"" % exclude
    print command
    main(role=role, command=command)
