import sys
import time
import digitalocean
import subprocess

def test_ssh(drop):
    droplet_ip_address = drop.ip_address
    result = subprocess.call(f"ssh -o StrictHostKeyChecking=no root@{droplet_ip_address} ls", shell=True)
    if result == 0:
        return True
    return False

TOKEN_FILE = "/srv/secrets-newsblur/keys/digital_ocean.token"
droplet_name = sys.argv[1]

with open(TOKEN_FILE) as f:
    token = f.read().strip()

manager = digitalocean.Manager(token=token)

timeout = 180
timer = 0

ssh_works = False
while not ssh_works:
    if timer > timeout:
        raise Exception(f"The {droplet_name} droplet was not created.")
    
    droplets = [drop for drop in manager.get_all_droplets() if drop.name == droplet_name]
    if droplets:
        droplet = droplets[0]
        print(f"Found the {droplet_name} droplet. IP address is {droplet.ip_address}. Testing ssh...")
        ssh_works = test_ssh(droplet)
    time.sleep(3)
    timer += 3
print("Success!")