#!/usr/bin/env python3

import os
import subprocess

TOKEN_FILE = "/srv/secrets-newsblur/keys/digital_ocean.token"
# TOKEN_FILE = "/srv/secrets-newsblur/keys/digital_ocean.readprod.token"

with open(TOKEN_FILE) as f:
    token = f.read().strip()
    os.environ['DO_API_TOKEN'] = token
    os.environ['DIGITALOCEAN_ACCESS_TOKEN'] = token

# subprocess.call('/srv/newsblur/ansible/inventories/digitalocean.py -p > '
#                 '/srv/newsblur/ansible/inventories/digital_ocean.ini', 
#                 shell=True)

subprocess.call('do-ansible-inventory --out /srv/newsblur/ansible/inventories/digital_ocean.ini', 
                shell=True)
