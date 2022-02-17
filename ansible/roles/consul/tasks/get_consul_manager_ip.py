#!/usr/bin/env python
import os
import digitalocean

TOKEN_FILE = "/srv/secrets-newsblur/keys/digital_ocean.token"

OLD = False
# Uncomment below to allow existing servers to find the consul-manager
OLD = True

with open(TOKEN_FILE) as f:
    token = f.read().strip()
    os.environ['DO_API_TOKEN'] = token

manager = digitalocean.Manager(token=token)
my_droplets = manager.get_all_droplets()
consul_manager_droplets = [d for d in my_droplets if d.name.startswith("db-consul")]
if OLD:
    consul_manager_ip_address = ','.join([f"\"{droplet.ip_address}\"" for droplet in consul_manager_droplets])
else:
    consul_manager_ip_address = ','.join([f"\"{droplet.private_ip_address}\"" for droplet in consul_manager_droplets])

print(consul_manager_ip_address)

# # write or overwrite the consul-manager ip
# if "consul_manager_ip.txt" not in os.listdir('/srv/newsblur/consul/'):
#     with open('/srv/newsblur/consul/consul_manager_ip.txt', 'w') as f:
#        f.write(consul_manager_ip_address)
