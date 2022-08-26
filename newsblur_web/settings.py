import sys
import os
import yaml 

# ===========================
# = Directory Declaractions =
# ===========================

SETTINGS_DIR  = os.path.dirname(__file__)
NEWSBLUR_DIR  = os.path.join(SETTINGS_DIR, "../")
MEDIA_ROOT    = os.path.join(NEWSBLUR_DIR, 'media')
STATIC_ROOT   = os.path.join(NEWSBLUR_DIR, 'static')
UTILS_ROOT    = os.path.join(NEWSBLUR_DIR, 'utils')
VENDOR_ROOT   = os.path.join(NEWSBLUR_DIR, 'vendor')
LOG_FILE      = os.path.join(NEWSBLUR_DIR, 'logs/newsblur.log')
IMAGE_MASK    = os.path.join(NEWSBLUR_DIR, 'media/img/mask.png')

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
import sentry_sdk
import paypalrestsdk
from sentry_sdk.integrations.django import DjangoIntegration
from sentry_sdk.integrations.redis import RedisIntegration
from sentry_sdk.integrations.celery import CeleryIntegration
import django.http
import re
from mongoengine import connect
from pymongo import monitoring
from utils.mongo_command_monitor import MongoCommandLogger
import boto3

# ===================
# = Server Settings =
# ===================

ADMINS       = (
    ('Samuel Clay', 'samuel@newsblur.com'),
)

SERVER_NAME  = 'newsblur'
SERVER_EMAIL = 'server@newsblur.com'
HELLO_EMAIL  = 'hello@newsblur.com'
NEWSBLUR_URL = 'https://www.newsblur.com'
IMAGES_URL   = 'https://imageproxy.newsblur.com'
PUSH_DOMAIN  = 'push.newsblur.com'
SECRET_KEY            = 'YOUR_SECRET_KEY'
IMAGES_SECRET_KEY = "YOUR_SECRET_IMAGE_KEY"
DNSIMPLE_TOKEN = "YOUR_DNSIMPLE_TOKEN"
RECAPTCHA_SECRET_KEY = "YOUR_RECAPTCHA_KEY"
YOUTUBE_API_KEY = "YOUR_YOUTUBE_API_KEY"
IMAGES_SECRET_KEY = "YOUR_IMAGES_SECRET_KEY"
DOCKERBUILD = os.getenv("DOCKERBUILD")
REDIS_USER = None
FLASK_SENTRY_DSN = None

# ===================
# = Global Settings =
# ===================

DEBUG                 = True
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

# URL prefix for admin media -- CSS, JavaScript and images. Make sure to use a
# trailing slash.
# Examples: "http://foo.com/media/", "/media/".
CIPHER_USERNAMES      = False
DEBUG_ASSETS          = True
HOMEPAGE_USERNAME     = 'popular'
ALLOWED_HOSTS         = ['*']
AUTO_PREMIUM_NEW_USERS = True
AUTO_ENABLE_NEW_USERS = True
ENFORCE_SIGNUP_CAPTCHA = False
ENABLE_PUSH           = True
PAYPAL_TEST           = False
DATA_UPLOAD_MAX_MEMORY_SIZE = 5242880 # 5 MB
FILE_UPLOAD_MAX_MEMORY_SIZE = 5242880 # 5 MB
PROMETHEUS_EXPORT_MIGRATIONS = False
MAX_SECONDS_COMPLETE_ARCHIVE_FETCH = 60 * 60 * 1 # 1 hour
MAX_SECONDS_ARCHIVE_FETCH_SINGLE_FEED = 60 * 15 # 15 minutes

# Uncomment below to force all feeds to store this many stories. Default is to cut 
# off at 25 stories for single subscriber non-premium feeds and 500 for popular feeds.
# OVERRIDE_STORY_COUNT_MAX = 1000

# ===========================
# = Django-specific Modules =
# ===========================


MIDDLEWARE = (
    'django_prometheus.middleware.PrometheusBeforeMiddleware',
    'django.middleware.gzip.GZipMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'subdomains.middleware.SubdomainMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'apps.profile.middleware.TimingMiddleware',
    'apps.profile.middleware.LastSeenMiddleware',
    'apps.profile.middleware.UserAgentBanMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'apps.profile.middleware.SimpsonsMiddleware',
    'apps.profile.middleware.ServerHostnameMiddleware',
    'oauth2_provider.middleware.OAuth2TokenMiddleware',
    # 'debug_toolbar.middleware.DebugToolbarMiddleware',
    'utils.request_introspection_middleware.DumpRequestMiddleware',
    'apps.profile.middleware.DBProfilerMiddleware',
    'apps.profile.middleware.SQLLogToConsoleMiddleware',
    'utils.redis_raw_log_middleware.RedisDumpMiddleware',
    'django_prometheus.middleware.PrometheusAfterMiddleware',
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
        'ifttt': 'Pair your NewsBlur account with other services.',
    },
    'CLIENT_ID_GENERATOR_CLASS': 'oauth2_provider.generators.ClientIdGenerator',
    'ACCESS_TOKEN_EXPIRE_SECONDS': 60*60*24*365*10, # 10 years
    'AUTHORIZATION_CODE_EXPIRE_SECONDS': 60*60, # 1 hour
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
            'class':'logging.NullHandler',
        },
        'console':{
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose'
        },
        'vendor.apns':{
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose'
        },
        'log_file':{
            'level': 'DEBUG',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': LOG_FILE,
            'maxBytes': 16777216, # 16megabytes
            'formatter': 'verbose'
        },
        'mail_admins': {
            'level': 'CRITICAL',
            'class': 'django.utils.log.AdminEmailHandler',
            # 'filters': ['require_debug_false'],
            'include_html': True,
        },
    },
    'loggers': {
        'django': {
            'handlers': ['console', 'log_file', 'mail_admins'],
            'level': 'ERROR',
            'propagate': False,
        },
        'django.db.backends': {
            'handlers': ['console'],
            'level': 'INFO',
            'propagate': False,
        },
        'django.security.DisallowedHost': {
            'handlers': ['null'],
            'propagate': False,
        },
        'elasticsearch': {
            'handlers': ['console', 'log_file'],
            'level': 'ERROR',
            # 'level': 'DEBUG',
            'propagate': False,
        },
        'elasticsearch.trace': {
            'handlers': ['console', 'log_file'],
            'level': 'ERROR',
            # 'level': 'DEBUG',
            'propagate': False,
        },
        'zebra': {
            'handlers': ['console', 'log_file'],
            # 'level': 'ERROR',
            'level': 'DEBUG',
            'propagate': False,
        },
        'newsblur': {
            'handlers': ['console', 'log_file'],
            'level': 'DEBUG',
            'propagate': False,
        },
        'readability': {
            'handlers': ['console', 'log_file'],
            'level': 'WARNING',
            'propagate': False,
        },
        'apps': {
            'handlers': ['log_file'],
            'level': 'DEBUG',
            'propagate': True,
        },
        'subdomains.middleware': {
            'level': 'ERROR',
            'propagate': False,
        }
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
DAYS_OF_UNREAD_ARCHIVE  = 9999
# DoSH can be more, since you can up this value by N, and after N days,
# you can then up the DAYS_OF_UNREAD value with no impact. 
# The max is for archive subscribers.
DAYS_OF_STORY_HASHES    = DAYS_OF_UNREAD
DAYS_OF_STORY_HASHES_ARCHIVE = DAYS_OF_UNREAD_ARCHIVE

# SUBSCRIBER_EXPIRE sets the number of days after which a user who hasn't logged in
# is no longer considered an active subscriber
SUBSCRIBER_EXPIRE       = 7

# PRO_MINUTES_BETWEEN_FETCHES sets the number of minutes to fetch feeds for 
# Premium Pro accounts. Defaults to every 5 minutes, but that's for NewsBlur
# servers. On your local, you should probably set this to 10-15 minutes
PRO_MINUTES_BETWEEN_FETCHES = 5

ROOT_URLCONF            = 'newsblur_web.urls'
INTERNAL_IPS            = ('127.0.0.1',)
LOGGING_LOG_SQL         = True
APPEND_SLASH            = False
SESSION_ENGINE          = 'redis_sessions.session'
TEST_RUNNER             = "utils.testrunner.TestRunner"
SESSION_COOKIE_NAME     = 'newsblur_sessionid'
SESSION_COOKIE_AGE      = 60*60*24*365*10 # 10 years
SESSION_COOKIE_DOMAIN   = '.newsblur.com'
SESSION_COOKIE_HTTPONLY = False
SESSION_COOKIE_SECURE   = True
SENTRY_DSN              = 'https://XXXNEWSBLURXXX@app.getsentry.com/99999999'
SESSION_SERIALIZER = 'django.contrib.sessions.serializers.PickleSerializer'
DATA_UPLOAD_MAX_NUMBER_FIELDS = None # Handle long /reader/complete_river calls
EMAIL_BACKEND = 'anymail.backends.mailgun.EmailBackend'

# ==============
# = Subdomains =
# ==============

SUBDOMAIN_URLCONFS = {
    None: 'newsblur_web.urls',
    'www': 'newsblur_web.urls',
    'nb': 'newsblur_web.urls',
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

OAUTH2_PROVIDER_APPLICATION_MODEL = 'oauth2_provider.Application'

INSTALLED_APPS = (
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.sites',
    'django.contrib.admin',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django_extensions',
    'django_prometheus',
    'paypal.standard.ipn',
    'apps.rss_feeds',
    'apps.reader',
    'apps.analyzer',
    'apps.feed_import',
    'apps.profile',
    'apps.recommendations',
    'apps.statistics',
    'apps.notifications',
    'apps.static',
    'apps.mobile',
    'apps.push',
    'apps.social',
    'apps.oauth',
    'apps.search',
    'apps.categories',
    'utils', # missing models so no migrations
    'vendor',
    'typogrify',
    'vendor.zebra',
    'anymail',
    'oauth2_provider',
    'corsheaders',
    'pipeline',
)

# ===================
# = Stripe & Paypal =
# ===================

STRIPE_SECRET = "YOUR-SECRET-API-KEY"
STRIPE_PUBLISHABLE = "YOUR-PUBLISHABLE-API-KEY"
ZEBRA_ENABLE_APP = True

PAYPAL_API_CLIENTID = "YOUR-PAYPAL-API-CLIENTID"
PAYPAL_API_SECRET = "YOUR-PAYPAL-API-SECRET"

# ==========
# = Celery =
# ==========

CELERY_TASK_ROUTES = {
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
        "queue": "cron_queue",
        "binding_key": "cron_queue"
    },
    "search-indexer": {
        "queue": "search_indexer",
        "binding_key": "search_indexer"
    },
}
CELERY_TASK_QUEUES = {
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
    "cron_queue": {
        "exchange": "cron_queue",
        "exchange_type": "direct",
        "binding_key": "cron_queue"
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
}
CELERY_TASK_DEFAULT_QUEUE = "work_queue"

CELERY_WORKER_PREFETCH_MULTIPLIER = 1
CELERY_IMPORTS              = ("apps.rss_feeds.tasks",
                               "apps.social.tasks",
                               "apps.reader.tasks",
                               "apps.profile.tasks",
                               "apps.feed_import.tasks",
                               "apps.search.tasks",
                               "apps.statistics.tasks",)
CELERY_WORKER_CONCURRENCY         = 5
CELERY_TASK_IGNORE_RESULT        = True
CELERY_TASK_ACKS_LATE            = True # Retry if task fails
CELERY_WORKER_MAX_TASKS_PER_CHILD = 10
CELERY_TASK_TIME_LIMIT     = 12 * 30
CELERY_WORKER_DISABLE_RATE_LIMITS  = True
SECONDS_TO_DELAY_CELERY_EMAILS = 60

CELERY_BEAT_SCHEDULE = {
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
        'options': {'queue': 'cron_queue'},
    },
    'collect-stats': {
        'task': 'collect-stats',
        'schedule': datetime.timedelta(minutes=1),
        'options': {'queue': 'cron_queue'},
    },
    'collect-feedback': {
        'task': 'collect-feedback',
        'schedule': datetime.timedelta(minutes=1),
        'options': {'queue': 'cron_queue'},
    },
    'share-popular-stories': {
        'task': 'share-popular-stories',
        'schedule': datetime.timedelta(minutes=10),
        'options': {'queue': 'cron_queue'},
    },
    'clean-analytics': {
        'task': 'clean-analytics',
        'schedule': datetime.timedelta(hours=12),
        'options': {'queue': 'cron_queue', 'timeout': 720*10},
    },
    'reimport-stripe-history': {
        'task': 'reimport-stripe-history',
        'schedule': datetime.timedelta(hours=6),
        'options': {'queue': 'cron_queue'},
    },
    # 'clean-spam': {
    #     'task': 'clean-spam',
    #     'schedule': datetime.timedelta(hours=1),
    #     'options': {'queue': 'cron_queue'},
    # },
    'clean-social-spam': {
        'task': 'clean-social-spam',
        'schedule': datetime.timedelta(hours=6),
        'options': {'queue': 'cron_queue'},
    },
    'premium-expire': {
        'task': 'premium-expire',
        'schedule': datetime.timedelta(hours=24),
        'options': {'queue': 'cron_queue'},
    },
    'activate-next-new-user': {
        'task': 'activate-next-new-user',
        'schedule': datetime.timedelta(minutes=5),
        'options': {'queue': 'cron_queue'},
    },
}

# =========
# = Mongo =
# =========
if DOCKERBUILD:
    MONGO_PORT = 29019
else:
    MONGO_PORT = 27017
MONGO_DB = {
    'host': f'db_mongo:{MONGO_PORT}',
    'name': 'newsblur',
}
MONGO_ANALYTICS_DB = {
    'host': f'db_mongo_analytics:{MONGO_PORT}',
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

    def allow_migrate(self, db, model):
        "Explicitly put all models on all databases."
        return True


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


BACKED_BY_AWS = {
    'pages_on_s3': False,
    'icons_on_s3': False,
}

PROXY_S3_PAGES = True
S3_BACKUP_BUCKET = 'newsblur-backups'
S3_PAGES_BUCKET_NAME = 'pages.newsblur.com'
S3_ICONS_BUCKET_NAME = 'icons.newsblur.com'
S3_AVATARS_BUCKET_NAME = 'avatars.newsblur.com'

# ==================
# = Configurations =
# ==================

if DOCKERBUILD:
    from newsblur_web.docker_local_settings import *

try:
    from newsblur_web.local_settings import *
except ModuleNotFoundError:
    pass

started_task_or_app = False
try:
    from newsblur_web.task_env import *
    print(" ---> Starting NewsBlur task server...")
    started_task_or_app = True
except ModuleNotFoundError:
    pass
try:
    from newsblur_web.app_env import *
    print(" ---> Starting NewsBlur app server...")
    started_task_or_app = True
except ModuleNotFoundError:
    pass
if not started_task_or_app:
    print(" ---> Starting NewsBlur development server...")

if not DEBUG:
    INSTALLED_APPS += (
        'django_ses',

    )

    sentry_sdk.init(
        dsn=SENTRY_DSN,
        integrations=[DjangoIntegration(), RedisIntegration(), CeleryIntegration()],
        server_name=SERVER_NAME,

        # Set traces_sample_rate to 1.0 to capture 100%
        # of transactions for performance monitoring.
        # We recommend adjusting this value in production,
        traces_sample_rate=0.01,

        # If you wish to associate users to errors (assuming you are using
        # django.contrib.auth) you may enable sending PII data.
        send_default_pii=True
    )
    sentry_sdk.utils.MAX_STRING_LENGTH = 8192
    
COMPRESS = not DEBUG
ACCOUNT_ACTIVATION_DAYS = 30
AWS_ACCESS_KEY_ID = S3_ACCESS_KEY
AWS_SECRET_ACCESS_KEY = S3_SECRET

os.environ["AWS_ACCESS_KEY_ID"] = AWS_ACCESS_KEY_ID
os.environ["AWS_SECRET_ACCESS_KEY"] = AWS_SECRET_ACCESS_KEY

def clear_prometheus_aggregation_stats():
    prom_folder = '/srv/newsblur/.prom_cache'
    os.makedirs(prom_folder, exist_ok=True)
    os.environ['PROMETHEUS_MULTIPROC_DIR'] = prom_folder
    for filename in os.listdir(prom_folder):
        file_path = os.path.join(prom_folder, filename)
        try:
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.unlink(file_path)
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)
        except Exception as e:
            if 'No such file' in str(e):
                return
            print('Failed to delete %s. Reason: %s' % (file_path, e))


clear_prometheus_aggregation_stats()

if DEBUG:
    template_loaders = [
        'django.template.loaders.filesystem.Loader',
        'django.template.loaders.app_directories.Loader',
    ]
else:
    template_loaders = [
        ('django.template.loaders.cached.Loader', (
            'django.template.loaders.filesystem.Loader',
            'django.template.loaders.app_directories.Loader',
        )),
    ]


BASE_DIR = os.path.dirname(os.path.dirname(__file__))

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [os.path.join(NEWSBLUR_DIR, 'templates'),
                 os.path.join(NEWSBLUR_DIR, 'vendor/zebra/templates')],
        # 'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                "django.contrib.auth.context_processors.auth",
                "django.template.context_processors.debug",
                "django.template.context_processors.media",
                'django.template.context_processors.request',
                'django.contrib.messages.context_processors.messages',
            ],
            'loaders': template_loaders,
        },
    }
]

# =========
# = Email =
# =========

ANYMAIL = {
    "MAILGUN_API_KEY": MAILGUN_ACCESS_KEY,
    "MAILGUN_SENDER_DOMAIN": MAILGUN_SERVER_NAME,
}

# =========
# = Mongo =
# =========

MONGO_COMMAND_LOGGER = MongoCommandLogger()
monitoring.register(MONGO_COMMAND_LOGGER)

MONGO_DB_DEFAULTS = {
    'name': 'newsblur',
    'host': f'db_mongo:{MONGO_PORT}',
    'alias': 'default',
    'unicode_decode_error_handler': 'ignore',
    'connect': False,
}
MONGO_DB = dict(MONGO_DB_DEFAULTS, **MONGO_DB)
MONGO_DB_NAME = MONGO_DB.pop('name')
# MONGO_URI = 'mongodb://%s' % (MONGO_DB.pop('host'),)

# if MONGO_DB.get('read_preference', pymongo.ReadPreference.PRIMARY) != pymongo.ReadPreference.PRIMARY:
#     MONGO_PRIMARY_DB = MONGO_DB.copy()
#     MONGO_PRIMARY_DB.update(read_preference=pymongo.ReadPreference.PRIMARY)
#     MONGOPRIMARYDB = connect(MONGO_PRIMARY_DB.pop('name'), **MONGO_PRIMARY_DB)
# else:
#     MONGOPRIMARYDB = MONGODB
# MONGODB = connect(MONGO_DB.pop('name'), host=MONGO_URI, **MONGO_DB)
MONGODB = connect(MONGO_DB_NAME, **MONGO_DB)
# MONGODB = connect(host="mongodb://localhost:27017/newsblur", connect=False)

MONGO_ANALYTICS_DB_DEFAULTS = {
    'name': 'nbanalytics',
    'host': f'db_mongo_analytics:{MONGO_PORT}',
    'alias': 'nbanalytics',
}
MONGO_ANALYTICS_DB = dict(MONGO_ANALYTICS_DB_DEFAULTS, **MONGO_ANALYTICS_DB)
# MONGO_ANALYTICS_DB_NAME = MONGO_ANALYTICS_DB.pop('name')
# MONGOANALYTICSDB = connect(MONGO_ANALYTICS_DB_NAME, **MONGO_ANALYTICS_DB)

if 'username' in MONGO_ANALYTICS_DB:
    MONGOANALYTICSDB = connect(db=MONGO_ANALYTICS_DB['name'], host=f"mongodb://{MONGO_ANALYTICS_DB['username']}:{MONGO_ANALYTICS_DB['password']}@{MONGO_ANALYTICS_DB['host']}/?authSource=admin", alias="nbanalytics")
else:
    MONGOANALYTICSDB = connect(db=MONGO_ANALYTICS_DB['name'], host=f"mongodb://{MONGO_ANALYTICS_DB['host']}/", alias="nbanalytics")


# =========
# = Redis =
# =========
if DOCKERBUILD:
    REDIS_PORT = 6579
else:
    REDIS_PORT = 6379

if REDIS_USER is None:
    # REDIS has been renamed to REDIS_USER. 
    REDIS_USER = REDIS

CELERY_REDIS_DB_NUM = 4
SESSION_REDIS_DB = 5
CELERY_BROKER_URL = "redis://%s:%s/%s" % (REDIS_USER['host'], REDIS_PORT,CELERY_REDIS_DB_NUM)
CELERY_RESULT_BACKEND = CELERY_BROKER_URL
BROKER_TRANSPORT_OPTIONS = {
    "max_retries": 3, 
    "interval_start": 0, 
    "interval_step": 0.2, 
    "interval_max": 0.5
}

SESSION_REDIS = {
    'host': REDIS_SESSIONS['host'],
    'port': REDIS_PORT,
    'db': SESSION_REDIS_DB,
    # 'password': 'password',
    'prefix': '',
    'socket_timeout': 10,
    'retry_on_timeout': True
}

CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': 'redis://%s:%s/6' % (REDIS_USER['host'], REDIS_PORT),
    },
}

REDIS_POOL                 = redis.ConnectionPool(host=REDIS_USER['host'], port=REDIS_PORT, db=0, decode_responses=True)
REDIS_ANALYTICS_POOL       = redis.ConnectionPool(host=REDIS_USER['host'], port=REDIS_PORT, db=2, decode_responses=True)
REDIS_STATISTICS_POOL      = redis.ConnectionPool(host=REDIS_USER['host'], port=REDIS_PORT, db=3, decode_responses=True)
REDIS_FEED_UPDATE_POOL     = redis.ConnectionPool(host=REDIS_USER['host'], port=REDIS_PORT, db=4, decode_responses=True)
REDIS_STORY_HASH_TEMP_POOL = redis.ConnectionPool(host=REDIS_USER['host'], port=REDIS_PORT, db=10, decode_responses=True)
# REDIS_CACHE_POOL         = redis.ConnectionPool(host=REDIS_USER['host'], port=REDIS_PORT, db=6) # Duped in CACHES
REDIS_STORY_HASH_POOL      = redis.ConnectionPool(host=REDIS_STORY['host'], port=REDIS_PORT, db=1, decode_responses=True)
REDIS_FEED_READ_POOL       = redis.ConnectionPool(host=REDIS_SESSIONS['host'], port=REDIS_PORT, db=1, decode_responses=True)
REDIS_FEED_SUB_POOL        = redis.ConnectionPool(host=REDIS_SESSIONS['host'], port=REDIS_PORT, db=2, decode_responses=True)
REDIS_SESSION_POOL         = redis.ConnectionPool(host=REDIS_SESSIONS['host'], port=REDIS_PORT, db=5, decode_responses=True)
REDIS_PUBSUB_POOL          = redis.ConnectionPool(host=REDIS_PUBSUB['host'], port=REDIS_PORT, db=0, decode_responses=True)

# ==========
# = Celery =
# ==========

# celeryapp.autodiscover_tasks(INSTALLED_APPS)
accept_content = ['pickle', 'json', 'msgpack', 'yaml']

# ==========
# = Assets =
# ==========

STATIC_URL        = '/static/'

# STATICFILES_STORAGE = 'pipeline.storage.PipelineManifestStorage'
STATICFILES_STORAGE = 'utils.pipeline_utils.PipelineStorage'
# STATICFILES_STORAGE = 'utils.pipeline_utils.GzipPipelineStorage'
STATICFILES_FINDERS = (
    # 'pipeline.finders.FileSystemFinder',
    # 'django.contrib.staticfiles.finders.FileSystemFinder',
    # 'django.contrib.staticfiles.finders.AppDirectoriesFinder',
    # 'pipeline.finders.AppDirectoriesFinder',
    'utils.pipeline_utils.AppDirectoriesFinder',
    'utils.pipeline_utils.FileSystemFinder',
    # 'pipeline.finders.PipelineFinder',
)
STATICFILES_DIRS = [
    # '/usr/local/lib/python3.9/site-packages/django/contrib/admin/static/',
    MEDIA_ROOT,
]
with open(os.path.join(SETTINGS_DIR, 'assets.yml')) as stream:
    assets = yaml.safe_load(stream)

PIPELINE = {
    'PIPELINE_ENABLED': not DEBUG_ASSETS,
    'PIPELINE_COLLECTOR_ENABLED': not DEBUG_ASSETS,
    'SHOW_ERRORS_INLINE': DEBUG_ASSETS,
    'CSS_COMPRESSOR': 'pipeline.compressors.yuglify.YuglifyCompressor',
    'JS_COMPRESSOR': 'pipeline.compressors.closure.ClosureCompressor',
    # 'CSS_COMPRESSOR': 'pipeline.compressors.NoopCompressor',
    # 'JS_COMPRESSOR': 'pipeline.compressors.NoopCompressor',
    'CLOSURE_BINARY': '/usr/bin/java -jar /usr/local/bin/compiler.jar',
    'CLOSURE_ARGUMENTS': '--language_in ECMASCRIPT_2016 --language_out ECMASCRIPT_2016 --warning_level DEFAULT',
    'JAVASCRIPT': {
        'common': {
            'source_filenames': assets['javascripts']['common'],
            'output_filename': 'js/common.js',
        },
        'statistics': {
            'source_filenames': assets['javascripts']['statistics'],
            'output_filename': 'js/statistics.js',
        },
        'payments': {
            'source_filenames': assets['javascripts']['payments'],
            'output_filename': 'js/payments.js',
        },
        'bookmarklet': {
            'source_filenames': assets['javascripts']['bookmarklet'],
            'output_filename': 'js/bookmarklet.js',
        },
        'blurblog': {
            'source_filenames': assets['javascripts']['blurblog'],
            'output_filename': 'js/blurblog.js',
        },
    },
    'STYLESHEETS': {
        'common': {
            'source_filenames': assets['stylesheets']['common'],
            'output_filename': 'css/common.css',
            # 'variant': 'datauri',
        },
        'bookmarklet': {
            'source_filenames': assets['stylesheets']['bookmarklet'],
            'output_filename': 'css/bookmarklet.css',
            # 'variant': 'datauri',
        },
        'blurblog': {
            'source_filenames': assets['stylesheets']['blurblog'],
            'output_filename': 'css/blurblog.css',
            # 'variant': 'datauri',
        },
    }
}

paypalrestsdk.configure({
    "mode": "sandbox" if DEBUG else "live",
    "client_id": PAYPAL_API_CLIENTID,
    "client_secret": PAYPAL_API_SECRET
})

# =======
# = AWS =
# =======

S3_CONN = None
if BACKED_BY_AWS.get('pages_on_s3') or BACKED_BY_AWS.get('icons_on_s3'):
    boto_session = boto3.Session(
        aws_access_key_id=S3_ACCESS_KEY,
        aws_secret_access_key=S3_SECRET,
    )
    S3_CONN = boto_session.resource('s3')

django.http.request.host_validation_re = re.compile(r"^([a-z0-9.-_\-]+|\[[a-f0-9]*:[a-f0-9:]+\])(:\d+)?$")


from django.contrib import auth

def monkey_patched_get_user(request):
    """
    Return the user model instance associated with the given request session.
    If no user is retrieved, return an instance of `AnonymousUser`.

    Monkey patched for the django 2.0 upgrade because session authentication,
    added in 1.7 and required in 1.10, invalidates all existing 1.5 session auth
    tokens. These tokens need to be refreshed as users login over the year, so
    until then, leave this moneky patch running until we're ready to invalidate
    any user who hasn't logged in during the window between the django 2.0 launch
    and when this monkey patch is removed.
    """
    from django.contrib.auth.models import AnonymousUser
    user = None
    try:
        user_id = auth._get_user_session_key(request)
        backend_path = request.session[auth.BACKEND_SESSION_KEY]
    except KeyError:
        pass
    else:
        if backend_path in AUTHENTICATION_BACKENDS:
            backend = auth.load_backend(backend_path)
            user = backend.get_user(user_id)
            session_hash = request.session.get(auth.HASH_SESSION_KEY)
            logging.debug(request, " ---> Ignoring session hash: %s vs %s" % (user.get_session_auth_hash() if user else "[no user]", session_hash))
            # # Verify the session
            # if hasattr(user, 'get_session_auth_hash'):
            #     session_hash = request.session.get(HASH_SESSION_KEY)
            #     session_hash_verified = session_hash and constant_time_compare(
            #         session_hash,
            #         user.get_session_auth_hash()
            #     )
            #     if not session_hash_verified:
            #         request.session.flush()
            #         user = None

    return user or AnonymousUser()

auth.get_user = monkey_patched_get_user
