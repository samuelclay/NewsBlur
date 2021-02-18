#!/srv/newsblur/venv/newsblur3/bin/python
import os
import digitalocean

TOKEN_FILE = "/srv/secrets-newsblur/keys/digital_ocean.token"

with open(TOKEN_FILE) as f:
    token = f.read().strip()
    os.environ['DO_API_TOKEN'] = token

manager = digitalocean.Manager(token=token)
my_droplets = manager.get_all_droplets()
consul_manager_droplet = [d for d in my_droplets if d.name.startswith("consul-manager")][0]
consul_manager_ip_address = consul_manager_droplet.private_ip_address

print(consul_manager_ip_address)

# # write or overwrite the consul-manager ip
# if "consul_manager_ip.txt" not in os.listdir('/srv/newsblur/consul/'):
#     with open('/srv/newsblur/consul/consul_manager_ip.txt', 'w') as f:
#        f.write(consul_manager_ip_address)
