#!/usr/bin/env python

import argparse
import json
import os
import re
import select
import subprocess
import sys
import time

from requests.exceptions import ConnectionError

sys.path.insert(0, "/srv/newsblur")
os.environ["DJANGO_SETTINGS_MODULE"] = "newsblur_web.settings"

NEWSBLUR_USERNAME = "nb"
IGNORE_HOSTS = [
    "app-push",
]

# Use this to count the number of times each user shows up in the logs. Good for finding abusive accounts.
# tail -n20000 logs/newsblur.log | sed 's/\x1b\[[0-9;]*m//g' | sed -En 's/.*?[0-9]s\] \[([a-zA-Z0-9]+\*?)\].*/\1/p' | sort | uniq -c | sort
r"""
tail -n20000 logs/newsblur.log \
  | sed 's/\x1b\[[0-9;]*m//g' \
  | sed -En 's/.*?[0-9]s\] \[([a-zA-Z0-9]+\*?)\].*/\1/p' \
  | sort \
  | uniq -c \
  | sort -nr
"""


def main(hostnames=None, roles=None, command=None, path=None):
    delay = 1

    hosts = subprocess.check_output(["ansible-inventory", "--list"])
    if not hosts:
        print(" ***> Could not load ansible-inventory!")
        return
    hosts = json.loads(hosts)

    if not path:
        path = "/srv/newsblur/logs/newsblur.log"
    if not command:
        command = "tail -f"

    if hostnames in ["app", "task", "push", "work"]:
        roles = hostnames
        hostnames = None

    if hostnames:
        roles = hosts
        hostnames = validate_hostnames(hostnames.split(","), hosts)

    if not roles:
        roles = ["app"]
    if not isinstance(roles, list):
        roles = [roles]

    while True:
        try:
            if hostnames:
                streams = []
                found = set()
                for host in hostnames:
                    follow_host(roles[0], streams, found, host, command, path)
                print(" --- Loading %s %s Log Tails ---" % (len(streams), hostnames))
            else:
                streams = create_streams_for_roles(hosts, roles, command=command, path=path)
                print(" --- Loading %s %s Log Tails ---" % (len(streams), roles))
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


def validate_hostnames(hostnames, hosts):
    validated_hostnames = []
    for hostname in hostnames:
        if hostname in hosts["_meta"]["hostvars"]:
            validated_hostnames.append(hostname)
        else:
            print(f"Hostname {hostname} not found in inventory.")
    print(f"Validated hostnames: {validated_hostnames}")
    return validated_hostnames


def create_streams_for_roles(hosts, roles, command=None, path=None):
    streams = list()
    found = set()
    for role in roles:
        if role in hosts:
            for hostname in hosts[role]["hosts"]:
                if any(h in hostname for h in IGNORE_HOSTS) and role != "push":
                    continue
                follow_host(hosts, streams, found, hostname, command, path)
        else:
            host = role
            follow_host(hosts, streams, found, host, command, path)

    return streams


def follow_host(hosts, streams, found, hostname, command=None, path=None):
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
            "-l",
            NEWSBLUR_USERNAME,
            "-i",
            os.path.expanduser("/srv/secrets-newsblur/keys/docker.key"),
            address,
            "%s %s" % (command, path),
        ],
        stdout=subprocess.PIPE,
    )
    s.name = hostname
    streams.append(s)
    found.add(hostname)


def read_streams(streams):
    while True:
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
                    combination_message = "[%-15s] %s" % (stream.name[:15], data.decode())
                except UnicodeDecodeError:
                    continue
                sys.stdout.write(combination_message)
                sys.stdout.flush()
                break


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Tail logs from multiple hosts.")
    parser.add_argument("hostnames", help="Comma-separated list of hostnames", nargs="?")
    parser.add_argument("roles", help="Comma-separated list of roles", nargs="?")
    parser.add_argument("--command", help="Command to run on the remote host")
    parser.add_argument("--path", help="Path to the log file")
    args = parser.parse_args()
    main(args.hostnames, command=args.command, path=args.path)
