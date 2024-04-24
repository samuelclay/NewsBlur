#!/usr/bin/env python
import json
import os
import subprocess

import digitalocean


def get_host_ips_from_group(group_name):
    """
    Fetches IP addresses of hosts from a specified group using ansible-inventory command across combined inventory.

    :param group_name: The name of the group to fetch host IPs from.
    :param inventory_base_path: Base path to the inventory directories. Defaults to the path in ansible.cfg.
    :return: A list of IP addresses belonging to the specified group.
    """
    cmd = [
        "ansible-inventory",
        "-i",
        "/srv/newsblur/ansible/inventories/hetzner.ini",
        "-i",
        "/srv/newsblur/ansible/inventories/hetzner.yml",
        "--list",
    ]

    try:
        # Execute the ansible-inventory command
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)

        # Parse the JSON output from ansible-inventory
        inventory_data = json.loads(result.stdout)

        host_ips = []
        # Check if the group exists
        if group_name in inventory_data:
            # Get the list of hosts in the specified group
            if "hosts" in inventory_data[group_name]:
                for host in inventory_data[group_name]["hosts"]:
                    # Fetch the host details, specifically looking for the ansible_host variable for the IP
                    host_vars = inventory_data["_meta"]["hostvars"][host]
                    ip_address = host_vars.get("ansible_host", None)
                    if ip_address:
                        host_ips.append(ip_address)
                    else:
                        # If ansible_host is not defined, fallback to using the host's name
                        host_ips.append(host)
        return host_ips
    except subprocess.CalledProcessError as e:
        print(f"Failed to execute ansible-inventory: {e.stderr}")
        return []
    except json.JSONDecodeError as e:
        print(f"Failed to parse JSON output: {e}")
        return []


TOKEN_FILE = "/srv/secrets-newsblur/keys/digital_ocean.token"

with open(TOKEN_FILE) as f:
    token = f.read().strip()
    os.environ["DO_API_TOKEN"] = token

manager = digitalocean.Manager(token=token)
my_droplets = manager.get_all_droplets()
consul_manager_droplets = [d for d in my_droplets if "db-consul" in d.name]

# Use ansible-inventory to get the consul-manager ip
group_name = "hconsul"
hetzner_hosts = get_host_ips_from_group(group_name)
consul_manager_ip_address = ",".join(
    [f'"{droplet.ip_address}"' for droplet in consul_manager_droplets]
    + [f'"{host}"' for host in hetzner_hosts]
)

print(consul_manager_ip_address)

# # write or overwrite the consul-manager ip
# if "consul_manager_ip.txt" not in os.listdir('/srv/newsblur/consul/'):
#     with open('/srv/newsblur/consul/consul_manager_ip.txt', 'w') as f:
#        f.write(consul_manager_ip_address)
