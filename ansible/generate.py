#!/usr/bin/env python3

import os
import time
import sys
import subprocess
import digitalocean
from optparse import OptionParser

parser = OptionParser()
parser.add_option("-H", "--host", dest="host", 
                  help="Confirm this host is reachable before returning")
(options, args) = parser.parse_args()

TOKEN_FILE = "/srv/secrets-newsblur/keys/digital_ocean.token"
# TOKEN_FILE = "/srv/secrets-newsblur/keys/digital_ocean.readprod.token"

try:
    api_token = open(TOKEN_FILE, 'r').read().strip()
except IOError:
    print(f" ---> Missing Digital Ocean API token: {TOKEN_FILE}")
    exit()

# Install from https://github.com/do-community/do-ansible-inventory/releases
ansible_inventory_cmd = f'do-ansible-inventory -t {api_token} --out /srv/newsblur/ansible/inventories/digital_ocean.ini'
subprocess.call(ansible_inventory_cmd, 
                shell=True)

if options.host:
    do = digitalocean.Manager(token=api_token)
    droplets = do.get_all_droplets()
    instance = None
    for droplet in droplets:
        if droplet.name == options.host:
            instance = droplet
            break
    else:
        print(f"Couldn't find droplet: {options.host} in {droplets}")
        exit()
    
    print("\nBooting droplet: %s / %s (size: %s)" % (instance.name, instance.ip_address, instance.size_slug))

    i = 0
    while True:
        if instance.status == 'active':
            print("...booted: %s" % instance.ip_address)
            time.sleep(5)
            break
        elif instance.status == 'new':
            print(".", end=' ')
            sys.stdout.flush()
            instance = digitalocean.Droplet.get_object(api_token, instance.id)
            i += 1
            time.sleep(i)
        else:
            print("!!! Error: %s" % instance.status)
