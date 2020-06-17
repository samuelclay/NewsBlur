import os
import re
import socket
import time
from subprocess import Popen, PIPE

from vendor.munin import MuninPlugin

space_re = re.compile(r"\s+")

class MuninCassandraPlugin(MuninPlugin):
    category = "Cassandra"

    def __init__(self, *args, **kwargs):
        super(MuninCassandraPlugin, self).__init__(*args, **kwargs)
        self.nodetool_path = os.environ["NODETOOL_PATH"]
        self.host = socket.gethostname()
        self.keyspaces = [x for x in os.environ.get('CASSANDRA_KEYSPACE', '').split(',') if x]

    def execute_nodetool(self, cmd):
        p = Popen([self.nodetool_path, "-host", self.host, cmd], stdout=PIPE)
        output = p.communicate()[0]
        return output

    def parse_cfstats(self, text):
        text = text.strip().split('\n')
        cfstats = {}
        cf = None
        for line in text:
            line = line.strip()
            if not line or line.startswith('-'):
                continue

            name, value = line.strip().split(': ', 1)
            if name == "Keyspace":
                ks = {'cf': {}}
                cf = None
                cfstats[value] = ks
            elif name == "Column Family":
                cf = {}
                ks['cf'][value] = cf
            elif cf is None:
                ks[name] = value
            else:
                cf[name] = value
        return cfstats

    def cfstats(self):
        return self.parse_cfstats(self.execute_nodetool("cfstats"))

    def cinfo(self):
        text = self.execute_nodetool("info")
        lines = text.strip().split('\n')
        token = lines[0]
        info = {}
        for l in lines[1:]:
            name, value = l.split(':')
            info[name.strip()] = value.strip()
        l_num, l_units = info['Load'].split(' ', 1)
        l_num = float(l_num)
        if l_units == "KB":
            scale = 1024
        elif l_units == "MB":
            scale = 1024*1024
        elif l_units == "GB":
            scale = 1024*1024*1024
        elif l_units == "TB":
            scale = 1024*1024*1024*1024
        info['Load'] = int(l_num * scale)
        info['token'] = token
        return info

    def tpstats(self):
        out = self.execute_nodetool("tpstats")
        tpstats = {}
        for line in out.strip().split('\n')[1:]:
            name, active, pending, completed = space_re.split(line)
            tpstats[name] = dict(active=int(active), pending=int(pending), completed=int(completed))
        return tpstats
