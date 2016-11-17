#!/usr/bin/env python

import os
import socket
from vendor.munin import MuninPlugin

class MuninMemcachedPlugin(MuninPlugin):
    category = "Memcached"

    def autoconf(self):
        try:
            self.get_stats()
        except socket.error:
            return False
        return True

    def get_stats(self):
        host = os.environ.get('MEMCACHED_HOST') or '127.0.0.1'
        port = int(os.environ.get('MEMCACHED_PORT') or '11211')
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect((host, port))
        s.send("stats\n")
        buf = ""
        while 'END\r\n' not in buf:
            buf += s.recv(1024)
        stats = (x.split(' ', 2) for x in buf.split('\r\n'))
        stats = dict((x[1], x[2]) for x in stats if x[0] == 'STAT')
        s.close()
        return stats

    def execute(self):
        stats = self.get_stats()
        values = {}
        for k, v in self.fields:
            try:
                value = stats[k]
            except KeyError:
                value = "U"
            values[k] = value
        return values
