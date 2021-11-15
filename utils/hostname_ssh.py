#!/usr/bin/env python3
import sys
import os
import subprocess
import json
import digitalocean
# from django.conf import settings

sys.path.append('/srv/newsblur')

os.environ['DJANGO_SETTINGS_MODULE'] = 'newsblur_web.settings'

if __name__ == '__main__':
    # Check and clean second argument (ex: sshdo task 2)
    second_arg = sys.argv[2] if len(sys.argv) > 2 else "1"
    droplet_index = int(second_arg) if str(second_arg).isnumeric() else 1
    droplet_name = sys.argv[1]

    # Use correct Digital Ocean team based on "old"
    commands = ['ansible-inventory', '--list']
    env = None
    if second_arg == "old":
        env = dict(os.environ, ANSIBLE_CONFIG="ansible.old.cfg")
    hosts = subprocess.check_output(commands, env=env)
    if not hosts:
        print(" ***> Could not load ansible-inventory!")

    hosts = json.loads(hosts)
    for host, ip_host in hosts['_meta']['hostvars'].items():
        if host.startswith(droplet_name):
            print(ip_host['ansible_host'])
            break
