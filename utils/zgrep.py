#!/usr/bin/env python

import argparse
import json
import os
import re
import select
import subprocess
import sys
import time
from pprint import pprint

from requests.exceptions import ConnectionError

sys.path.insert(0, "/srv/newsblur")
os.environ["DJANGO_SETTINGS_MODULE"] = "newsblur_web.settings"

NEWSBLUR_USERNAME = "nb"
IGNORE_HOSTS = [
    "app-push",
]


def main(role, find, follow=True, current_only=False):
    delay = 1

    hosts = subprocess.check_output(["ansible-inventory", "--list"])
    if not hosts:
        print(" ***> Could not load ansible-inventory!")
        return
    hosts = json.loads(hosts)

    if current_only:
        path = "/srv/newsblur/logs/newsblur.log"
        command = 'grep -a "%s" %s' % (find, path)
    else:
        path = "/srv/newsblur/logs/newsblur.log*"
        command = 'zgrep -a "%s" %s' % (find, path)
    # if exclude:
    #     command += " | zgrep -v \"%s\"" % exclude
    print(f" ---> {command}")

    if not follow:
        # For non-follow mode, just execute once and return
        streams = create_streams_for_role(hosts, role, command=command)
        print(" --- Loading %s %s logs (no follow) ---" % (len(streams), role))
        read_streams(streams, follow=False)
    else:
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
        for hostname in hosts[role]["hosts"]:
            if any(h in hostname for h in IGNORE_HOSTS) and role != "push":
                continue
            follow_host(hosts, streams, found, hostname, command)
    else:
        host = role
        follow_host(hosts, streams, found, host, command)

    return streams


def follow_host(hosts, streams, found, hostname, command=None):
    if isinstance(hostname, dict):
        address = hostname["address"]
        hostname = hostname["name"]
    elif ":" in hostname:
        hostname, address = hostname.split(":", 1)
    elif isinstance(hostname, tuple):
        hostname, address = hostname[0], hostname[1]
    else:
        address = hosts["_meta"]["hostvars"][hostname]["ansible_host"]
        print(" ---> Following %s \t[%s]" % (hostname, address))
    if hostname in found:
        return
    s = subprocess.Popen(
        [
            "ssh",
            "-o",
            "StrictHostKeyChecking=no",
            "-o",
            "UserKnownHostsFile=/dev/null",
            "-l",
            NEWSBLUR_USERNAME,
            "-i",
            os.path.expanduser("/srv/secrets-newsblur/keys/docker.key"),
            address,
            command,
        ],
        stdout=subprocess.PIPE,
    )
    s.name = hostname
    streams.append(s)
    found.add(hostname)


def read_streams(streams, follow=True):
    while streams:
        if follow:
            r, _, _ = select.select([stream.stdout.fileno() for stream in streams], [], [])
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
        else:
            # Non-follow mode: read all data from each stream
            for stream in list(streams):
                data = stream.stdout.read()
                if data:
                    try:
                        lines = data.decode().splitlines()
                        for line in lines:
                            combination_message = "[%-13s] %s\n" % (stream.name[:13], line)
                            sys.stdout.write(combination_message)
                    except UnicodeDecodeError:
                        pass
                stream.wait()
                streams.remove(stream)
            break


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Search NewsBlur logs across servers')
    parser.add_argument('role', help="Role/hostname to search (e.g., 'web', 'app', 'task', or specific hostname)")
    parser.add_argument('search_string', help='String to search for in logs')
    parser.add_argument('--no-follow', action='store_true', help='Do not tail -f, just return existing matches')
    parser.add_argument('--current-only', action='store_true', help='Only search newsblur.log, not archived logs')
    
    args = parser.parse_args()
    
    main(args.role, args.search_string, follow=not args.no_follow, current_only=args.current_only)
