import sys
import logging
import os

# Route all 'print' statements to Apache
sys.stdout = sys.stderr

# ===========================
# = Directory Declaractions =
# ===========================

CURRENT_DIR = os.path.dirname(__file__)
NEWSBLUR_DIR = CURRENT_DIR
TEMPLATE_DIRS = (''.join([CURRENT_DIR, '/templates']),)
MEDIA_ROOT = ''.join([CURRENT_DIR, '/media'])
LOG_FILE = ''.join([CURRENT_DIR, '/logs/newsblur.log'])

# ===================
# = Global Settings =
# ===================

DEBUG = False
ADMINS = (
    ('Robert Samuel Clay', 'samuel@ofbrooklyn.com'),
)
MANAGERS = ADMINS

TIME_ZONE = 'America/New_York'
LANGUAGE_CODE = 'en-us'
SITE_ID = 1
USE_I18N = False
LOGIN_REDIRECT_URL = '/'
# URL prefix for admin media -- CSS, JavaScript and images. Make sure to use a
# trailing slash.
# Examples: "http://foo.com/media/", "/media/".
ADMIN_MEDIA_PREFIX = '/media/admin/'
SECRET_KEY = '6yx-@2u@v$)-=fqm&tc8lhk3$6d68+c7gd%p$q2@o7b4o8-*fz'

# ===============
# = Enviornment =
# ===============

PRODUCTION = __file__.find('/home/conesus/newsblur') == 0
STAGING = __file__.find('/home/conesus/stg-newsblur') == 0
DEV_SERVER1 = __file__.find('/Users/conesus/Projects/newsblur') == 0
DEV_SERVER2 = __file__.find('/Users/conesus/newsblur') == 0
DEVELOPMENT = DEV_SERVER1 or DEV_SERVER2

if PRODUCTION:
    DATABASE_ENGINE = 'mysql'
    DATABASE_NAME = 'newsblur'
    DATABASE_USER = 'newsblur'
    DATABASE_PASSWORD = ''
    DATABASE_HOST = 'localhost'
    DATABASE_PORT = ''
    # Absolute path to the directory that holds media.
    # Example: "/Users/media/media.lawrence.com/"
    MEDIA_URL = 'http://www.newsblur.com/media/'
    DEBUG = False
    CACHE_BACKEND = 'file:///var/tmp/django_cache'
    logging.basicConfig(level=logging.WARN,
                    format='%(asctime)s %(levelname)s %(message)s',
                    filename=LOG_FILE,
                    filemode='w')
elif STAGING:
    DATABASE_ENGINE = 'mysql'
    DATABASE_NAME = 'newsblur'
    DATABASE_USER = 'newsblur'
    DATABASE_PASSWORD = ''    
    DATABASE_HOST = 'localhost'
    DATABASE_PORT = ''         

    # Absolute path to the directory that holds media.
    # Example: "/Users/media/media.lawrence.com/"
    MEDIA_URL = '/media/'
    DEBUG = True
    CACHE_BACKEND = 'file:///var/tmp/django_cache'
    logging.basicConfig(level=logging.DEBUG,
                    format='%(asctime)s %(levelname)s %(message)s',
                    filename=LOG_FILE,
                    filemode='w')
elif DEV_SERVER1:
    DATABASE_ENGINE = 'mysql'
    DATABASE_NAME = 'newsblur'
    DATABASE_USER = 'newsblur'
    DATABASE_PASSWORD = ''    
    DATABASE_HOST = 'localhost'
    DATABASE_PORT = ''         

    # Absolute path to the directory that holds media.
    # Example: "/Users/media/media.lawrence.com/"
    MEDIA_URL = '/media/'
    DEBUG = True
    CACHE_BACKEND = 'dummy:///'
    logging.basicConfig(level=logging.DEBUG,
                    format='%(asctime)s %(levelname)s %(message)s',
                    filename=LOG_FILE,
                    filemode='w')
elif DEV_SERVER2:
    DATABASE_ENGINE = 'mysql'
    DATABASE_NAME = 'newsblur'
    DATABASE_USER = 'newsblur'
    DATABASE_PASSWORD = ''    
    DATABASE_HOST = 'localhost'
    DATABASE_PORT = ''         

    # Absolute path to the directory that holds media.
    # Example: "/Users/media/media.lawrence.com/"
    MEDIA_URL = '/media/'
    DEBUG = True
    CACHE_BACKEND = 'dummy:///'
    logging.basicConfig(level=logging.DEBUG,
                    format='%(asctime)s %(levelname)s %(message)s',
                    filename=LOG_FILE,
                    filemode='w')

TEMPLATE_DEBUG = DEBUG

# ===========================
# = Django-specific Modules =
# ===========================

TEMPLATE_LOADERS = (
    'django.template.loaders.filesystem.load_template_source',
    'django.template.loaders.app_directories.load_template_source',
    'django.template.loaders.eggs.load_template_source',
)
TEMPLATE_CONTEXT_PROCESSORS = (
    "django.core.context_processors.auth",
    "django.core.context_processors.debug",
    "django.core.context_processors.media"
)

MIDDLEWARE_CLASSES = (
    'django.middleware.gzip.GZipMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.cache.CacheMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'djangologging.middleware.LoggingMiddleware',
)

# ==========================
# = Miscellaneous Settings =
# ==========================

AUTH_PROFILE_MODULE = 'newsblur.UserProfile'
TEST_DATABASE_COLLATION = 'utf8_general_ci'
ROOT_URLCONF = 'urls'
INTERNAL_IPS = ('127.0.0.1',)
LOGGING_LOG_SQL = True

# ===============
# = Django Apps =
# ===============

INSTALLED_APPS = (
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.sites',
    'django.contrib.admin',
    'utils.django_extensions',
    'apps.rss_feeds',
    'apps.reader',
    'apps.analyzer',
    'apps.registration',
    'apps.opml_import',
    'apps.profile',
)
