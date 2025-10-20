#!/usr/bin/env python

import os
import subprocess
import sys
import time

from hetzner.robot import Robot

TOKEN_FILE = "/srv/secrets-newsblur/keys/hetzner.yaml"

import requests
import yaml

# Load credentials from a YAML file
with open(TOKEN_FILE, "r") as file:
    credentials = yaml.safe_load(file)

user = credentials["hetzner_robot"]["username"]
password = credentials["hetzner_robot"]["password"]
outfile = f"/srv/newsblur/ansible/inventories/hetzner.ini"
robot = Robot(user, password)
servers = list(getattr(robot, "servers", []) or [])
if servers:
    with open(outfile, "w") as inventory_file:
        inventory_file.write("[hetzner_servers]\n")
        for server in servers:
            # Assuming the server IP is under 'server_ip' key
            inventory_file.write(f"{server.ip}\n")
        print(f"Inventory file 'hetzner_inventory.ini' created with {len(servers)} servers")
else:
    print(f"Failed to fetch server data")
