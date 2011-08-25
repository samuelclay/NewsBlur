#!/usr/bin/env python

"""
Usage:

  ./rtail.py user@host:path/foo.log bar.log host2:/path/baz.log
"""

import optparse
import os
import re
import select
import subprocess
import sys


def main():
    op = optparse.OptionParser()
    options, args = op.parse_args()
    streams = list()
    for arg in args:
        if re.match(r"^(.+@)?[a-zA-Z0-9.-]+:.+", arg):
            # this is a remote location
            hostname, path = arg.split(":", 1)
            s = subprocess.Popen(["ssh", hostname, "tail -f " + path], stdout=subprocess.PIPE)
            s.name = arg
            streams.append(s)
        else:
            s = subprocess.Popen(["tail", "-f", arg], stdout=subprocess.PIPE)
            s.name = arg
            streams.append(s)

    try:
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
                    host = re.match(r'^(.*?)\.', stream.name)
                    combination_message = "[%-5s] %s" % (host.group(1), data)
                    sys.stdout.write(combination_message)
                    break
    except KeyboardInterrupt:
        print " --- End of Logging ---"

if __name__ == "__main__":
    main()
