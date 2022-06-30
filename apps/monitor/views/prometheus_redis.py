import os
import socket

from django.views import View
from django.shortcuts import render

"""
RedisActiveConnections
RedisCommands
RedisConnects
RedisUsedMemory
RedisSize
"""

class RedisGrafanaMetric(View):
    category = "Redis"

    def autoconf(self):
        try:
            self.get_info()
        except socket.error:
            return False
        return True

    def get_info(self):
        host = os.environ.get('REDIS_HOST') or '127.0.0.1'
        port = int(os.environ.get('REDIS_PORT') or '6379')
        if host.startswith('/'):
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(host)
        else:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.connect((host, port))
        s.send("*1\r\n$4\r\ninfo\r\n")
        buf = ""
        while '\r\n' not in buf:
            buf += s.recv(1024)
        l, buf = buf.split('\r\n', 1)
        if l[0] != "$":
            s.close()
            raise Exception("Protocol error")
        remaining = int(l[1:]) - len(buf)
        if remaining > 0:
            buf += s.recv(remaining)
        s.close()
        return dict(x.split(':', 1) for x in buf.split('\r\n') if ':' in x)

    def execute(self):
        stats = self.get_info()
        values = {}
        for k, v in self.get_fields():
            try:
                value = stats[k]
            except KeyError:
                value = "U"
            values[k] = value
        return values

    def get_fields(self):
        raise NotImplementedError('You must implement the get_fields function')

    def get_context(self):
        raise NotImplementedError('You must implement the get_context function')
    
    def get(self, request):
        context = self.get_context()
        return render(request, 'monitor/prometheus_data.html', context, content_type="text/plain")

class RedisActiveConnection(RedisGrafanaMetric):
    
    def get_fields(self):
        return (
            ('connected_clients', dict(
                label = "connections",
                info = "connections",
                type = "GAUGE",
            )),
        )

    def get_context(self):
        raise NotImplementedError('You must implement the get_context function')
