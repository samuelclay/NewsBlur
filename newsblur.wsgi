import os, sys

PRODUCTION = __file__.find('/home/conesus/newsblur') == 0
STAGING = __file__.find('/home/conesus/stg-newsblur') == 0
DEV_SERVER1 = __file__.find('/Users/conesus/Projects/newsblur') == 0
DEV_SERVER2 = __file__.find('/Users/conesus/newsblur') == 0
DEVELOPMENT = DEV_SERVER1 or DEV_SERVER2

if PRODUCTION:   
   apache_configuration= os.path.dirname('/home/conesus/newsblur')
   sys.path.append('/home/conesus/newsblur/')
   sys.path.append('/home/conesus/newsblur/utils')
elif STAGING:
   apache_configuration = os.path.dirname('/home/conesus/stg-newsblur')
   sys.path.append('/home/conesus/stg-newsblur/')
   sys.path.append('/home/conesus/stg-newsblur/utils')

project = os.path.dirname(apache_configuration)
workspace = os.path.dirname(project)
sys.path.append(workspace)
   
sys.path.append('/home/conesus/django/')
   
os.environ['DJANGO_SETTINGS_MODULE'] = 'settings'
import django.core.handlers.wsgi
application = django.core.handlers.wsgi.WSGIHandler()