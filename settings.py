# Django settings for newsblur project.
import sys
sys.stdout = sys.stderr
import logging



DEBUG = True
TEMPLATE_DEBUG = DEBUG
ADMINS = (
    ('Robert Samuel Clay', 'samuel@ofbrooklyn.com'),
)
MANAGERS = ADMINS

PRODUCTION = __file__.find('/home/conesus/newsblur') == 0
STAGING = __file__.find('/home/conesus/webapps') == 0
DEVELOPMENT = __file__.find('/Users/conesus/Projects/newsblur') == 0

if PRODUCTION:
    DATABASE_ENGINE = 'mysql'
    DATABASE_NAME = 'newsblur'
    DATABASE_USER = 'newsblur'
    DATABASE_PASSWORD = ''
    DATABASE_HOST = 'localhost'
    DATABASE_PORT = ''
    # Absolute path to the directory that holds media.
    # Example: "/Users/media/media.lawrence.com/"
    MEDIA_ROOT = '/home/conesus/newsblur/media/'
    MEDIA_URL = 'http://www.newsblur.com/media/'
    TEMPLATE_DIRS = (
        '/home/conesus/newsblur/templates'
    )
    DEBUG = True
    CACHE_BACKEND = 'locmem:///'
    logging.basicConfig(level=logging.WARN,
                    format='%(asctime)s %(levelname)s %(message)s',
                    filename='/home/conesus/newsblur/logs/newsblur.log',
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
    MEDIA_ROOT = '/home/conesus/webapps/newsblur/newsblur/media/'
    MEDIA_URL = 'http://conesus.webfactional.com/media/media/'
    TEMPLATE_DIRS = (
        '/home/conesus/webapps/newsblur/newsblur/templates'
    )
    DEBUG = True
    CACHE_BACKEND = 'file:///var/tmp/django_cache'
    logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s %(levelname)s %(message)s',
                    filename='/home/conesus/newsblur/logs/newsblur.log',
                    filemode='w')
else:
    DATABASE_ENGINE = 'mysql'
    DATABASE_NAME = 'newsblur'
    DATABASE_USER = 'newsblur'
    DATABASE_PASSWORD = ''    
    DATABASE_HOST = 'localhost'
    DATABASE_PORT = ''         

    # Absolute path to the directory that holds media.
    # Example: "/Users/media/media.lawrence.com/"
    MEDIA_ROOT = '/Users/conesus/Projects/newsblur/media/'
    MEDIA_URL = '/media/'
    TEMPLATE_DIRS = (
        '/Users/conesus/Projects/newsblur/templates'
    )
    DEBUG = True
    CACHE_BACKEND = 'dummy:///'
    logging.basicConfig(level=logging.DEBUG,
                    format='%(asctime)s %(levelname)s %(message)s',
                    filename='/Users/conesus/Projects/newsblur/logs/newsblur.log',
                    filemode='w')

TIME_ZONE = 'America/New_York'
LANGUAGE_CODE = 'en-us'
SITE_ID = 1
USE_I18N = False

# URL prefix for admin media -- CSS, JavaScript and images. Make sure to use a
# trailing slash.
# Examples: "http://foo.com/media/", "/media/".
ADMIN_MEDIA_PREFIX = '/media/admin/'
SECRET_KEY = '6yx-@2u@v$)-=fqm&tc8lhk3$6d68+c7gd%p$q2@o7b4o8-*fz'

# List of callables that know how to import templates from various sources.
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

AUTH_PROFILE_MODULE = 'newsblur.UserProfile'
TEST_DATABASE_COLLATION = 'utf8_general_ci'
ROOT_URLCONF = 'urls'
INTERNAL_IPS = ('127.0.0.1',)
LOGGING_LOG_SQL = True


INSTALLED_APPS = (
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.sites',
    'django.contrib.admin',
    'utils.django_command_extensions.django_extensions',
    'apps.rss_feeds',
    'apps.reader',
    'apps.analyzer',
    'apps.registration',
    'apps.opml_import',
    'apps.profile',
)