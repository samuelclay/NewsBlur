#!/srv/newsblur/venv/newsblur3/bin/python
import sys
sys.path.append('/srv/newsblur')
from newsblur_web import settings

username = settings.DATABASES['default']['USER']
password = settings.DATABASES['default']['PASSWORD']
print(f"{username}:{password}")