#!/usr/bin/env python

import os
import socket
import socketserver
import sys
import threading
import time
from subprocess import Popen, PIPE

PLUGIN_PATH = "/etc/munin/plugins"

def parse_args():
    from optparse import OptionParser
    parser = OptionParser()
    parser.add_option("-p", "--pluginpath", dest="plugin_path",
                      help="path to plugins", default=PLUGIN_PATH)
    (options, args) = parser.parse_args()
    return options, args


def execute_plugin(path, cmd=""):
    args = [path]
    if cmd:
        args.append(cmd)
    p = Popen(args, stdout=PIPE)
    output = p.communicate()[0]
    return output

if os.name == 'posix':
    def become_daemon(our_home_dir='.', out_log='/dev/null',
                      err_log='/dev/null', umask=0o22):
        "Robustly turn into a UNIX daemon, running in our_home_dir."
        # First fork
        try:
            if os.fork() > 0:
                sys.exit(0)     # kill off parent
        except OSError as e:
            sys.stderr.write("fork #1 failed: (%d) %s\n" % (e.errno, e.strerror))
            sys.exit(1)
        os.setsid()
        os.chdir(our_home_dir)
        os.umask(umask)

        # Second fork
        try:
            if os.fork() > 0:
                os._exit(0)
        except OSError as e:
            sys.stderr.write("fork #2 failed: (%d) %s\n" % (e.errno, e.strerror))
            os._exit(1)

        si = open('/dev/null', 'r')
        so = open(out_log, 'a+', 0)
        se = open(err_log, 'a+', 0)
        os.dup2(si.fileno(), sys.stdin.fileno())
        os.dup2(so.fileno(), sys.stdout.fileno())
        os.dup2(se.fileno(), sys.stderr.fileno())
        # Set custom file descriptors so that they get proper buffering.
        sys.stdout, sys.stderr = so, se
else:
    def become_daemon(our_home_dir='.', out_log=None, err_log=None, umask=0o22):
        """
        If we're not running under a POSIX system, just simulate the daemon
        mode by doing redirections and directory changing.
        """
        os.chdir(our_home_dir)
        os.umask(umask)
        sys.stdin.close()
        sys.stdout.close()
        sys.stderr.close()
        if err_log:
            sys.stderr = open(err_log, 'a', 0)
        else:
            sys.stderr = NullDevice()
        if out_log:
            sys.stdout = open(out_log, 'a', 0)
        else:
            sys.stdout = NullDevice()

    class NullDevice:
        "A writeable object that writes to nowhere -- like /dev/null."
        def write(self, s):
            pass

class MuninRequestHandler(socketserver.StreamRequestHandler):
    def handle(self):
        # self.rfile is a file-like object created by the handler;
        # we can now use e.g. readline() instead of raw recv() calls
        plugins = []
        for x in os.listdir(self.server.options.plugin_path):
            if x.startswith('.'):
                continue
            fullpath = os.path.join(self.server.options.plugin_path, x)
            if not os.path.isfile(fullpath):
                continue
            plugins.append(x)
            
        node_name = socket.gethostname().split('.')[0]
        self.wfile.write("# munin node at %s\n" % node_name)
        while True:
            line = self.rfile.readline()
            if not line:
                break
            line = line.strip()

            cmd = line.split(' ', 1)
            plugin = (len(cmd) > 1) and cmd[1] or None

            if cmd[0] == "list":
                self.wfile.write("%s\n" % " ".join(plugins))
            elif cmd[0] == "nodes":
                self.wfile.write("nodes\n%s\n.\n" % (node_name))
            elif cmd[0] == "version":
                self.wfile.write("munins node on chatter1 version: 1.2.6\n")
            elif cmd[0] in ("fetch", "config"):
                if plugin not in plugins:
                    self.wfile.write("# Unknown service\n.\n")
                    continue
                c = (cmd[0] == "config") and "config" or ""
                out = execute_plugin(os.path.join(self.server.options.plugin_path, plugin), c)
                self.wfile.write(out)
                if out and out[-1] != "\n":
                    self.wfile.write("\n")
                self.wfile.write(".\n")
            elif cmd[0] == "quit":
                break
            else:
                self.wfile.write("# Unknown command. Try list, nodes, config, fetch, version or quit\n")


class MuninServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    pass

if __name__ == "__main__":
    HOST, PORT = "0.0.0.0", 4949
    if sys.version_info[:3] >= (2, 6, 0):
        server = MuninServer((HOST, PORT), MuninRequestHandler, bind_and_activate=False)
        server.allow_reuse_address = True
        server.server_bind()
        server.server_activate()
    else:
        server = MuninServer((HOST, PORT), MuninRequestHandler)
    ip, port = server.server_address
    options, args = parse_args()
    options.plugin_path = os.path.abspath(options.plugin_path)
    server.options = options

    become_daemon()
    server.serve_forever()
