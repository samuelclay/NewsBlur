import sys
import os

# ===========================
# = Directory Declaractions =
# ===========================

CURRENT_DIR   = os.path.dirname(__file__)
NEWSBLUR_DIR  = CURRENT_DIR
TEMPLATE_DIRS = (os.path.join(CURRENT_DIR, 'templates'),
                 os.path.join(CURRENT_DIR, 'vendor/zebra/templates'))
MEDIA_ROOT    = os.path.join(CURRENT_DIR, 'media')
STATIC_ROOT   = os.path.join(CURRENT_DIR, 'static')
UTILS_ROOT    = os.path.join(CURRENT_DIR, 'utils')
VENDOR_ROOT   = os.path.join(CURRENT_DIR, 'vendor')
LOG_FILE      = os.path.join(CURRENT_DIR, 'logs/newsblur.log')
IMAGE_MASK    = os.path.join(CURRENT_DIR, 'media/img/mask.png')

# ==============
# = PYTHONPATH =
# ==============

if '/utils' not in ' '.join(sys.path):
    sys.path.append(UTILS_ROOT)

if '/vendor' not in ' '.join(sys.path):
    sys.path.append(VENDOR_ROOT)

import logging
import datetime
import redis
import raven
import django.http
import re
from mongoengine import connect
from boto.s3.connection import S3Connection
from utils import jammit

# ===================
# = Server Settings =
# ===================

ADMINS       = (
    ('Samuel Clay', 'samuel@newsblur.com'),
)

SERVER_NAME  = 'newsblur'
SERVER_EMAIL = 'server@newsblur.com'
HELLO_EMAIL  = 'hello@newsblur.com'
NEWSBLUR_URL = 'http://www.newsblur.com'
SECRET_KEY            = 'YOUR_SECRET_KEY'

# ===================
# = Global Settings =
# ===================

DEBUG                 = False
TEST_DEBUG            = False
SEND_BROKEN_LINK_EMAILS = False
DEBUG_QUERIES         = False
MANAGERS              = ADMINS
PAYPAL_RECEIVER_EMAIL = 'samuel@ofbrooklyn.com'
TIME_ZONE             = 'GMT'
LANGUAGE_CODE         = 'en-us'
SITE_ID               = 1
USE_I18N              = False
LOGIN_REDIRECT_URL    = '/'
LOGIN_URL             = '/account/login'
MEDIA_URL             = '/media/'
STATIC_URL             = '/media/'
STATIC_ROOT             = '/media/'
# URL prefix for admin media -- CSS, JavaScript and images. Make sure to use a
# trailing slash.
# Examples: "http://foo.com/media/", "/media/".
CIPHER_USERNAMES      = False
DEBUG_ASSETS          = DEBUG
HOMEPAGE_USERNAME     = 'popular'
ALLOWED_HOSTS         = ['*']
AUTO_PREMIUM_NEW_USERS = False
AUTO_ENABLE_NEW_USERS = True
PAYPAL_TEST           = False

# ===============
# = Environment =
# ===============

PRODUCTION  = NEWSBLUR_DIR.find('/home/conesus/newsblur') == 0
STAGING     = NEWSBLUR_DIR.find('/home/conesus/staging') == 0
DEVELOPMENT = (not PRODUCTION and not STAGING)


# ===========================
# = Django-specific Modules =
# ===========================

TEMPLATE_CONTEXT_PROCESSORS = (
    "django.contrib.auth.context_processors.auth",
    "django.core.context_processors.debug",
    "django.core.context_processors.media",
    'django.core.context_processors.request',
)

MIDDLEWARE_CLASSES = (
    'django.middleware.gzip.GZipMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'apps.profile.middleware.TimingMiddleware',
    'apps.profile.middleware.LastSeenMiddleware',
    'apps.profile.middleware.UserAgentBanMiddleware',
    'subdomains.middleware.SubdomainMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'apps.profile.middleware.SimpsonsMiddleware',
    'apps.profile.middleware.ServerHostnameMiddleware',
    'oauth2_provider.middleware.OAuth2TokenMiddleware',
    # 'debug_toolbar.middleware.DebugToolbarMiddleware',
    'apps.profile.middleware.DBProfilerMiddleware',
    'apps.profile.middleware.SQLLogToConsoleMiddleware',
    'utils.mongo_raw_log_middleware.MongoDumpMiddleware',
    'utils.redis_raw_log_middleware.RedisDumpMiddleware',
)

AUTHENTICATION_BACKENDS = (
    'oauth2_provider.backends.OAuth2Backend',
    'django.contrib.auth.backends.ModelBackend',
)

CORS_ORIGIN_ALLOW_ALL = True
# CORS_ORIGIN_REGEX_WHITELIST = ('^(https?://)?(\w+\.)?newsblur\.com$', )
CORS_ALLOW_CREDENTIALS = True

OAUTH2_PROVIDER = {
    'SCOPES': {
        'read': 'View new unread stories, saved stories, and shared stories.',
        'write': 'Create new saved stories, shared stories, and subscriptions.',
        'ifttt': 'Pair your NewsBlur account with other IFTTT channels.',
    },
    'CLIENT_ID_GENERATOR_CLASS': 'oauth2_provider.generators.ClientIdGenerator',
    'ACCESS_TOKEN_EXPIRE_SECONDS': 60*60*24*365*10 # 10 years
}

# ===========
# = Logging =
# ===========

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '[%(asctime)-12s] %(message)s',
            'datefmt': '%b %d %H:%M:%S'
        },
        'simple': {
            'format': '%(message)s'
        },
    },
    'handlers': {
        'null': {
            'level':'DEBUG',
            'class':'django.utils.log.NullHandler',
        },
        'console':{
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose'
        },
        'log_file':{
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': LOG_FILE,
            'maxBytes': '16777216', # 16megabytes
            'formatter': 'verbose'
        },
        'mail_admins': {
            'level': 'CRITICAL',
            'class': 'django.utils.log.AdminEmailHandler',
            'filters': ['require_debug_false'],
            'include_html': True,
        }
    },
    'loggers': {
        'django.request': {
            'handlers': ['console', 'log_file'],
            'level': 'ERROR',
            'propagate': True,
        },
        'django.db.backends': {
            'handlers': ['null'],
            'level': 'DEBUG',
            'propagate': False,
        },
        'django.security.DisallowedHost': {
            'handlers': ['null'],
            'propagate': False,
        },
        'newsblur': {
            'handlers': ['console', 'log_file'],
            'level': 'DEBUG',
            'propagate': False,
        },
        'apps': {
            'handlers': ['log_file'],
            'level': 'INFO',
            'propagate': True,
        },
    },
    'filters': {
        'require_debug_false': {
            '()': 'django.utils.log.RequireDebugFalse'
        }
    },
}

logging.getLogger("requests").setLevel(logging.WARNING)
logging.getLogger("urllib3").setLevel(logging.WARNING)

# ==========================
# = Miscellaneous Settings =
# ==========================

DAYS_OF_UNREAD          = 30
DAYS_OF_UNREAD_FREE     = 14
# DoSH can be more, since you can up this value by N, and after N days,
# you can then up the DAYS_OF_UNREAD value with no impact.
DAYS_OF_STORY_HASHES    = 30

SUBSCRIBER_EXPIRE       = 7

AUTH_PROFILE_MODULE     = 'newsblur.UserProfile'
TEST_DATABASE_COLLATION = 'utf8_general_ci'
TEST_DATABASE_NAME      = 'newsblur_test'
ROOT_URLCONF            = 'urls'
INTERNAL_IPS            = ('127.0.0.1',)
LOGGING_LOG_SQL         = True
APPEND_SLASH            = False
SOUTH_TESTS_MIGRATE     = False
SESSION_ENGINE          = 'redis_sessions.session'
TEST_RUNNER             = "utils.testrunner.TestRunner"
SESSION_COOKIE_NAME     = 'newsblur_sessionid'
SESSION_COOKIE_AGE      = 60*60*24*365 # 1 year
SESSION_COOKIE_DOMAIN   = '.newsblur.com'
SENTRY_DSN              = 'https://XXXNEWSBLURXXX@app.getsentry.com/99999999'

if not DEVELOPMENT:
    EMAIL_BACKEND = 'django_mailgun.MailgunBackend'
else:
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# ==============
# = Subdomains =
# ==============

SUBDOMAIN_URLCONFS = {
    None: 'urls',
    'www': 'urls',
}
REMOVE_WWW_FROM_DOMAIN = True

# ===========
# = Logging =
# ===========

LOG_LEVEL = logging.DEBUG
LOG_TO_STREAM = False

# ===============
# = Django Apps =
# ===============

INSTALLED_APPS = (
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.sites',
    'django.contrib.admin',
    'django_extensions',
    'djcelery',
    'vendor.paypal.standard.ipn',
    'apps.rss_feeds',
    'apps.reader',
    'apps.analyzer',
    'apps.feed_import',
    'apps.profile',
    'apps.recommendations',
    'apps.statistics',
    'apps.static',
    'apps.mobile',
    'apps.push',
    'apps.social',
    'apps.oauth',
    'apps.search',
    'apps.categories',
    'south',
    'utils',
    'vendor',
    'vendor.typogrify',
    'vendor.zebra',
    'oauth2_provider',
    'corsheaders',
)

# ==========
# = Stripe =
# ==========

STRIPE_SECRET = "YOUR-SECRET-API-KEY"
STRIPE_PUBLISHABLE = "YOUR-PUBLISHABLE-API-KEY"
ZEBRA_ENABLE_APP = True

# ==========
# = Celery =
# ==========

import djcelery
djcelery.setup_loader()
CELERY_ROUTES = {
    "work-queue": {
        "queue": "work_queue",
        "binding_key": "work_queue"
    },
    "new-feeds": {
        "queue": "new_feeds",
        "binding_key": "new_feeds"
    },
    "push-feeds": {
        "queue": "push_feeds",
        "binding_key": "push_feeds"
    },
    "update-feeds": {
        "queue": "update_feeds",
        "binding_key": "update_feeds"
    },
    "beat-tasks": {
        "queue": "beat_tasks",
        "binding_key": "beat_tasks"
    },
    "search-indexer": {
        "queue": "search_indexer",
        "binding_key": "search_indexer"
    },
    "search-indexer-tasker": {
        "queue": "search_indexer_tasker",
        "binding_key": "search_indexer_tasker"
    },
}
CELERY_QUEUES = {
    "work_queue": {
        "exchange": "work_queue",
        "exchange_type": "direct",
        "binding_key": "work_queue",
    },
    "new_feeds": {
        "exchange": "new_feeds",
        "exchange_type": "direct",
        "binding_key": "new_feeds"
    },
    "push_feeds": {
        "exchange": "push_feeds",
        "exchange_type": "direct",
        "binding_key": "push_feeds"
    },
    "update_feeds": {
        "exchange": "update_feeds",
        "exchange_type": "direct",
        "binding_key": "update_feeds"
    },
    "beat_tasks": {
        "exchange": "beat_tasks",
        "exchange_type": "direct",
        "binding_key": "beat_tasks"
    },
    "beat_feeds_task": {
        "exchange": "beat_feeds_task",
        "exchange_type": "direct",
        "binding_key": "beat_feeds_task"
    },
    "search_indexer": {
        "exchange": "search_indexer",
        "exchange_type": "direct",
        "binding_key": "search_indexer"
    },
    "search_indexer_tasker": {
        "exchange": "search_indexer_tasker",
        "exchange_type": "direct",
        "binding_key": "search_indexer_tasker"
    },
}
CELERY_DEFAULT_QUEUE = "work_queue"

CELERYD_PREFETCH_MULTIPLIER = 1
CELERY_IMPORTS              = ("apps.rss_feeds.tasks",
                               "apps.social.tasks",
                               "apps.reader.tasks",
                               "apps.feed_import.tasks",
                               "apps.search.tasks",
                               "apps.statistics.tasks",)
CELERYD_CONCURRENCY         = 4
CELERY_IGNORE_RESULT        = True
CELERY_ACKS_LATE            = True # Retry if task fails
CELERYD_MAX_TASKS_PER_CHILD = 10
CELERYD_TASK_TIME_LIMIT     = 12 * 30
CELERY_DISABLE_RATE_LIMITS  = True
SECONDS_TO_DELAY_CELERY_EMAILS = 60

CELERYBEAT_SCHEDULE = {
    'task-feeds': {
        'task': 'task-feeds',
        'schedule': datetime.timedelta(minutes=1),
        'options': {'queue': 'beat_feeds_task'},
    },
    'task-broken-feeds': {
        'task': 'task-broken-feeds',
        'schedule': datetime.timedelta(hours=6),
        'options': {'queue': 'beat_feeds_task'},
    },
    'freshen-homepage': {
        'task': 'freshen-homepage',
        'schedule': datetime.timedelta(hours=1),
        'options': {'queue': 'beat_tasks'},
    },
    'collect-stats': {
        'task': 'collect-stats',
        'schedule': datetime.timedelta(minutes=1),
        'options': {'queue': 'beat_tasks'},
    },
    'collect-feedback': {
        'task': 'collect-feedback',
        'schedule': datetime.timedelta(minutes=1),
        'options': {'queue': 'beat_tasks'},
    },
    'share-popular-stories': {
        'task': 'share-popular-stories',
        'schedule': datetime.timedelta(minutes=10),
        'options': {'queue': 'beat_tasks'},
    },
    'clean-analytics': {
        'task': 'clean-analytics',
        'schedule': datetime.timedelta(hours=12),
        'options': {'queue': 'beat_tasks', 'timeout': 720*10},
    },
    'clean-spam': {
        'task': 'clean-spam',
        'schedule': datetime.timedelta(hours=12),
        'options': {'queue': 'beat_tasks'},
    },
    'premium-expire': {
        'task': 'premium-expire',
        'schedule': datetime.timedelta(hours=24),
        'options': {'queue': 'beat_tasks'},
    },
    'activate-next-new-user': {
        'task': 'activate-next-new-user',
        'schedule': datetime.timedelta(minutes=5),
        'options': {'queue': 'beat_tasks'},
    },
}

# =========
# = Mongo =
# =========

MONGO_DB = {
    'host': 'db_mongo:27017',
    'name': 'newsblur',
}
MONGO_ANALYTICS_DB = {
    'host': 'db_mongo_analytics:27017',
    'name': 'nbanalytics',
}

# ====================
# = Database Routers =
# ====================

class MasterSlaveRouter(object):
    """A router that sets up a simple master/slave configuration"""

    def db_for_read(self, model, **hints):
        "Point all read operations to a random slave"
        return 'slave'

    def db_for_write(self, model, **hints):
        "Point all write operations to the master"
        return 'default'

    def allow_relation(self, obj1, obj2, **hints):
        "Allow any relation between two objects in the db pool"
        db_list = ('slave','default')
        if obj1._state.db in db_list and obj2._state.db in db_list:
            return True
        return None

    def allow_syncdb(self, db, model):
        "Explicitly put all models on all databases."
        return True

# =========
# = Redis =
# =========

REDIS = {
    'host': 'db_redis',
}
REDIS_PUBSUB = {
    'host': 'db_redis_pubsub',
}
REDIS_STORY = {
    'host': 'db_redis_story',
}
REDIS_SESSIONS = {
    'host': 'db_redis_sessions',
}

CELERY_REDIS_DB = 4
SESSION_REDIS_DB = 5

# =================
# = Elasticsearch =
# =================

ELASTICSEARCH_FEED_HOSTS = ['db_search_feed:9200']
ELASTICSEARCH_STORY_HOSTS = ['db_search_story:9200']

# ===============
# = Social APIs =
# ===============

FACEBOOK_APP_ID = '111111111111111'
FACEBOOK_SECRET = '99999999999999999999999999999999'
FACEBOOK_NAMESPACE = 'newsblur'
TWITTER_CONSUMER_KEY = 'ooooooooooooooooooooo'
TWITTER_CONSUMER_SECRET = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
YOUTUBE_API_KEY = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# ===============
# = AWS Backing =
# ===============

ORIGINAL_PAGE_SERVER = "db_pages:3060"

BACKED_BY_AWS = {
    'pages_on_s3': False,
    'icons_on_s3': False,
}

PROXY_S3_PAGES = True
S3_BACKUP_BUCKET = 'newsblur_backups'
S3_PAGES_BUCKET_NAME = 'pages.newsblur.com'
S3_ICONS_BUCKET_NAME = 'icons.newsblur.com'
S3_AVATARS_BUCKET_NAME = 'avatars.newsblur.com'

# ==================
# = Configurations =
# ==================
try:
    from gunicorn_conf import *
except ImportError, e:
    pass

from local_settings import *

if not DEVELOPMENT:
    INSTALLED_APPS += (
        'gunicorn',
        'raven.contrib.django',
        'django_ses',

    )
    RAVEN_CLIENT = raven.Client(SENTRY_DSN)

COMPRESS = not DEBUG
TEMPLATE_DEBUG = DEBUG
ACCOUNT_ACTIVATION_DAYS = 30
AWS_ACCESS_KEY_ID = S3_ACCESS_KEY
AWS_SECRET_ACCESS_KEY = S3_SECRET

os.environ["AWS_ACCESS_KEY_ID"] = AWS_ACCESS_KEY_ID
os.environ["AWS_SECRET_ACCESS_KEY"] = AWS_SECRET_ACCESS_KEY

def custom_show_toolbar(request):
    return DEBUG

DEBUG_TOOLBAR_CONFIG = {
    'INTERCEPT_REDIRECTS': True,
    'SHOW_TOOLBAR_CALLBACK': custom_show_toolbar,
    'HIDE_DJANGO_SQL': False,
}

if DEBUG:
    TEMPLATE_LOADERS = (
        'django.template.loaders.filesystem.Loader',
        'django.template.loaders.app_directories.Loader',
    )
else:
    TEMPLATE_LOADERS = (
        ('django.template.loaders.cached.Loader', (
            'django.template.loaders.filesystem.Loader',
            'django.template.loaders.app_directories.Loader',
        )),
    )

# =========
# = Mongo =
# =========

MONGO_DB_DEFAULTS = {
    'name': 'newsblur',
    'host': 'db_mongo:27017',
    'alias': 'default',
}
MONGO_DB = dict(MONGO_DB_DEFAULTS, **MONGO_DB)
# MONGO_URI = 'mongodb://%s' % (MONGO_DB.pop('host'),)

# if MONGO_DB.get('read_preference', pymongo.ReadPreference.PRIMARY) != pymongo.ReadPreference.PRIMARY:
#     MONGO_PRIMARY_DB = MONGO_DB.copy()
#     MONGO_PRIMARY_DB.update(read_preference=pymongo.ReadPreference.PRIMARY)
#     MONGOPRIMARYDB = connect(MONGO_PRIMARY_DB.pop('name'), **MONGO_PRIMARY_DB)
# else:
#     MONGOPRIMARYDB = MONGODB
# MONGODB = connect(MONGO_DB.pop('name'), host=MONGO_URI, **MONGO_DB)
MONGODB = connect(MONGO_DB.pop('name'), **MONGO_DB)

MONGO_ANALYTICS_DB_DEFAULTS = {
    'name': 'nbanalytics',
    'host': 'db_mongo_analytics:27017',
    'alias': 'nbanalytics',
}
MONGO_ANALYTICS_DB = dict(MONGO_ANALYTICS_DB_DEFAULTS, **MONGO_ANALYTICS_DB)
# MONGO_ANALYTICS_URI = 'mongodb://%s' % (MONGO_ANALYTICS_DB.pop('host'),)
# MONGOANALYTICSDB = connect(MONGO_ANALYTICS_DB.pop('name'), host=MONGO_ANALYTICS_URI, **MONGO_ANALYTICS_DB)
MONGOANALYTICSDB = connect(MONGO_ANALYTICS_DB.pop('name'), **MONGO_ANALYTICS_DB)


# =========
# = Redis =
# =========

BROKER_BACKEND = "redis"
BROKER_URL = "redis://%s:6379/%s" % (REDIS['host'], CELERY_REDIS_DB)
CELERY_RESULT_BACKEND = BROKER_URL
SESSION_REDIS_HOST = REDIS_SESSIONS['host']

CACHES = {
    'default': {
        'BACKEND': 'redis_cache.RedisCache',
        'LOCATION': '%s:6379' % REDIS['host'],
        'OPTIONS': {
            'DB': 6,
            'PARSER_CLASS': 'redis.connection.HiredisParser'
        },
    },
}

REDIS_POOL                 = redis.ConnectionPool(host=REDIS['host'], port=6379, db=0)
REDIS_ANALYTICS_POOL       = redis.ConnectionPool(host=REDIS['host'], port=6379, db=2)
REDIS_STATISTICS_POOL      = redis.ConnectionPool(host=REDIS['host'], port=6379, db=3)
REDIS_FEED_UPDATE_POOL     = redis.ConnectionPool(host=REDIS['host'], port=6379, db=4)
# REDIS_STORY_HASH_POOL2   = redis.ConnectionPool(host=REDIS['host'], port=6379, db=8)
REDIS_STORY_HASH_TEMP_POOL = redis.ConnectionPool(host=REDIS['host'], port=6379, db=10)
# REDIS_CACHE_POOL         = redis.ConnectionPool(host=REDIS['host'], port=6379, db=6) # Duped in CACHES
REDIS_SESSION_POOL         = redis.ConnectionPool(host=SESSION_REDIS_HOST, port=6379, db=5)
REDIS_STORY_HASH_POOL      = redis.ConnectionPool(host=REDIS_STORY['host'], port=6379, db=1)
REDIS_FEED_SUB_POOL        = redis.ConnectionPool(host=SESSION_REDIS_HOST, port=6379, db=2)
REDIS_PUBSUB_POOL          = redis.ConnectionPool(host=REDIS_PUBSUB['host'], port=6379, db=0)

# ==========
# = Assets =
# ==========

JAMMIT = jammit.JammitAssets(NEWSBLUR_DIR)

if DEBUG:
    MIDDLEWARE_CLASSES += ('utils.request_introspection_middleware.DumpRequestMiddleware',)
    MIDDLEWARE_CLASSES += ('utils.exception_middleware.ConsoleExceptionMiddleware',)

# =======
# = AWS =
# =======

S3_CONN = None
if BACKED_BY_AWS.get('pages_on_s3') or BACKED_BY_AWS.get('icons_on_s3'):
    S3_CONN = S3Connection(S3_ACCESS_KEY, S3_SECRET)
    if BACKED_BY_AWS.get('pages_on_s3'):
        S3_PAGES_BUCKET = S3_CONN.get_bucket(S3_PAGES_BUCKET_NAME)
    if BACKED_BY_AWS.get('icons_on_s3'):
        S3_ICONS_BUCKET = S3_CONN.get_bucket(S3_ICONS_BUCKET_NAME)

django.http.request.host_validation_re = re.compile(r"^([a-z0-9.-_\-]+|\[[a-f0-9]*:[a-f0-9:]+\])(:\d+)?$")
