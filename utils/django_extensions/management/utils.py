from django.conf import settings
import os

def get_project_root():
    """ get the project root directory """
    settings_mod = __import__(settings.SETTINGS_MODULE, {}, {}, [''])
    return os.path.dirname(os.path.abspath(settings_mod.__file__))
