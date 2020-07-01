import sys
import os
import digitalocean
from django.conf import settings

sys.path.append('/srv/newsblur')

os.environ['DJANGO_SETTINGS_MODULE'] = 'newsblur.settings'

if __name__ == '__main__':
    doapi = digitalocean.Manager(token=settings.DO_TOKEN_LOG)
    droplets = doapi.get_all_droplets()
    for droplet in droplets:
        if sys.argv[1] == droplet.name:
            print(droplet.ip_address)
            break
