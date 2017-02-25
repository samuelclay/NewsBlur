#!/usr/bin/env python

import os
import re
import socket
from vendor.munin import MuninPlugin

worker_re = re.compile(r'^(?P<fd>\d+) (?P<ip>[\d\.]+) (?P<client_id>[^\s]+) :\s?(?P<abilities>.*)$')

class MuninGearmanPlugin(MuninPlugin):
    category = "Gearman"

    def __init__(self):
        super(MuninGearmanPlugin, self).__init__()
        addr = os.environ.get('GM_SERVER') or "127.0.0.1"
        port = int(addr.split(':')[-1]) if ':' in addr else 4730
        host = addr.split(':')[0]
        self.addr = (host, port)
        self._sock = None

    def connect(self):
        if not self._sock:
            self._sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self._sock.connect(self.addr)
        return self._sock

    def disconnect(self):
        if self._sock:
            self._sock.close()

    def get_workers(self):
        sock = self.connect()
        sock.send("workers\n")
        buf = ""
        while ".\n" not in buf:
            buf += sock.recv(8192)

        info = []
        for l in buf.split('\n'):
            if l.strip() == '.':
                break
            m = worker_re.match(l)
            i = m.groupdict()
            i['abilities'] = [x for x in i['abilities'].split(' ') if x]
            info.append(i)
        return info

    def get_status(self):
        sock = self.connect()
        sock.send("status\n")
        buf = ""
        while ".\n" not in buf:
            buf += sock.recv(8192)

        info = {}
        for l in buf.split('\n'):
            l = l.strip()
            if l == '.':
                break
            counts = l.split('\t')
            info[counts[0]] = dict(
                total = int(counts[1]),
                running = int(counts[2]),
                workers = int(counts[3]),
            )
        return info
