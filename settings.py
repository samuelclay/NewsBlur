# Django settings for newsblur project.
import sys
sys.stdout = sys.stderr

DEBUG = True
TEMPLATE_DEBUG = DEBUG

ADMINS = (
    ('Robert Samuel Clay', 'samuel@ofbrooklyn.com'),
)

MANAGERS = ADMINS
PRODUCTION = False
STAGING = False
DEVELOPMENT = False

CACHE_BACKEND = 'file:///var/tmp/django_cache'
# CACHE_BACKEND = 'dummy:///'
# CACHE_BACKEND = 'locmem:///'

if __file__.find('/home/conesus/webapps') == 0:
    DATABASE_ENGINE = 'mysql'           # 'postgresql_psycopg2', 'postgresql', 'mysql', 'sqlite3' or 'oracle'.
    DATABASE_NAME = 'conesus_newsblur'             # Or path to database file if using sqlite3.
    DATABASE_USER = 'conesus_newsblur'             # Not used with sqlite3.
    DATABASE_PASSWORD = 'lapsak21'         # Not used with sqlite3.
    DATABASE_HOST = 'localhost'             # Set to empty string for localhost. Not used with sqlite3.
    DATABASE_PORT = ''             # Set to empty string for default. Not used with sqlite3.

    # Absolute path to the directory that holds media.
    # Example: "/Users/media/media.lawrence.com/"
    MEDIA_ROOT = '/home/conesus/webapps/newsblur/newsblur/media/'
    MEDIA_URL = 'http://conesus.webfactional.com/media/media/'
    TEMPLATE_DIRS = (
        '/home/conesus/webapps/newsblur/newsblur/templates'
    )
    PRODUCTION = True
    DEBUG = True
elif __file__.find('/home/conesus/newsblur') == 0:
    DATABASE_ENGINE = 'mysql'           # 'postgresql_psycopg2', 'postgresql', 'mysql', 'sqlite3' or 'oracle'.
    DATABASE_NAME = 'newsblur'             # Or path to database file if using sqlite3.
    DATABASE_USER = 'newsblur'             # Not used with sqlite3.
    DATABASE_PASSWORD = ''         # Not used with sqlite3.
    DATABASE_HOST = 'localhost'             # Set to empty string for localhost. Not used with sqlite3.
    DATABASE_PORT = ''             # Set to empty string for default. Not used with sqlite3.

    # Absolute path to the directory that holds media.
    # Example: "/Users/media/media.lawrence.com/"
    MEDIA_ROOT = '/home/conesus/newsblur/media/'
    MEDIA_URL = 'http://www.newsblur.com/media/'
    TEMPLATE_DIRS = (
        '/home/conesus/newsblur/templates'
    )
    STAGING = True
else:
    DATABASE_ENGINE = 'mysql'           # 'postgresql_psycopg2', 'postgresql', 'mysql', 'sqlite3' or 'oracle'.
    DATABASE_NAME = 'newsblur'             # Or path to database file if using sqlite3.
    DATABASE_USER = 'newsblur'             # Not used with sqlite3.
    DATABASE_PASSWORD = ''         # Not used with sqlite3.
    DATABASE_HOST = 'localhost'             # Set to empty string for localhost. Not used with sqlite3.
    DATABASE_PORT = ''             # Set to empty string for default. Not used with sqlite3.

    # Absolute path to the directory that holds media.
    # Example: "/Users/media/media.lawrence.com/"
    MEDIA_ROOT = '/Users/conesus/Projects/newsblur/media/'
    MEDIA_URL = '/media/'
    TEMPLATE_DIRS = (
        '/Users/conesus/Projects/newsblur/templates'
    )
    DEVELOPMENT = True

if DEVELOPMENT:
    # CACHE_BACKEND = 'file:///var/tmp/django_cache'
    # CACHE_BACKEND = 'dummy:///'
    CACHE_BACKEND = 'locmem:///'

# Local time zone for this installation. Choices can be found here:
# http://en.wikipedia.org/wiki/List_of_tz_zones_by_name
# although not all choices may be available on all operating systems
# If running in a Windows environment this must be set to the same as your
# system time zone.
TIME_ZONE = 'America/New_York'

# Language code for this installation. All choices can be found here:
# http://www.i18nguy.com/unicode/language-identifiers.html
LANGUAGE_CODE = 'en-us'

SITE_ID = 1

# If you set this to False, Django will make some optimizations so as not
# to load the internationalization machinery.
USE_I18N = False

# URL prefix for admin media -- CSS, JavaScript and images. Make sure to use a
# trailing slash.
# Examples: "http://foo.com/media/", "/media/".
ADMIN_MEDIA_PREFIX = '/media/admin/'

# Make this unique, and don't share it with anybody.
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
    'django.contrib.auth.middleware.AuthenticationMiddleware'
)

AUTH_PROFILE_MODULE = 'newsblur.UserProfile'

ROOT_URLCONF = 'urls'

TEST_DATABASE_COLLATION = 'utf8_general_ci'

INSTALLED_APPS = (
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.sites',
    'django.contrib.admin',
    'django.contrib.admindocs',
    'utils.django_command_extensions.django_extensions',
    'apps.rss_feeds',
    'apps.reader',
    'apps.analyzer',
    'apps.registration',
    'apps.opml_import',
    'apps.profile',
)

# Custom settings
ACCOUNT_ACTIVATION_DAYS = 30
