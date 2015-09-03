import sys
import os
import dop.client
from django.conf import settings

sys.path.append('/srv/newsblur')

os.environ['DJANGO_SETTINGS_MODULE'] = 'settings'

if __name__ == '__main__':
    doapi = dop.client.Client(settings.DO_CLIENT_KEY, settings.DO_API_KEY)
    droplets = doapi.show_active_droplets()
    for droplet in droplets:
        if sys.argv[1] == droplet.name:
            print droplet.ip_address
            break
