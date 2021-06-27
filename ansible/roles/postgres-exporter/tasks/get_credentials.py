#!/srv/newsblur/venv/newsblur3/bin/python
import sys
sys.path.append('/srv/newsblur')
from newsblur_web import settings

username = settings.DATABASES['default']['USER']
password = settings.DATABASES['default']['PASSWORD']

if sys.argv[1] =='postgres_credentials':
    print(f"{username}:{password}")
if sys.argv[1] =='s3_bucket':
    print(settings.S3_BACKUP_BUCKET)