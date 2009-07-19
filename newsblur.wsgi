import os, sys
   
apache_configuration= os.path.dirname('/home/conesus/newsblur')
project = os.path.dirname(apache_configuration)
workspace = os.path.dirname(project)
sys.path.append(workspace)
   
sys.path.append('/home/conesus/django/')
sys.path.append('/home/conesus/newsblur/')
sys.path.append('/home/conesus/newsblur/utils')
   
os.environ['DJANGO_SETTINGS_MODULE'] = 'settings'
import django.core.handlers.wsgi
application = django.core.handlers.wsgi.WSGIHandler()