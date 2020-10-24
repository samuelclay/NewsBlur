import logging
import pymongo

# ===================
# = Server Settings =
# ===================

ADMINS                = (
    ('Samuel Clay', 'samuel@newsblur.com'),
)

SERVER_EMAIL          = 'server@newsblur.com'
HELLO_EMAIL           = 'hello@newsblur.com'
NEWSBLUR_URL          = 'http://www.newsblur.com'
SESSION_COOKIE_DOMAIN = '.nb.local.com'

# ===================
# = Global Settings =
# ===================

DEBUG = True
DEBUG_ASSETS = DEBUG
MEDIA_URL = '/media/'
SECRET_KEY = 'YOUR SECRET KEY'
AUTO_PREMIUM_NEW_USERS = True
AUTO_ENABLE_NEW_USERS = True
ENFORCE_SIGNUP_CAPTCHA = False

# CACHE_BACKEND = 'dummy:///'
# CACHE_BACKEND = 'locmem:///'
# CACHE_BACKEND = 'memcached://127.0.0.1:11211'

CACHES = {
    'default': {
        'BACKEND': 'redis_cache.RedisCache',
        'LOCATION': 'redis:6579',
        'OPTIONS': {
            'DB': 6,
            'PARSER_CLASS': 'redis.connection.HiredisParser'
        },
    },
}

EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'

# Set this to the username that is shown on the homepage to unauthenticated users.
HOMEPAGE_USERNAME = 'popular'

# Google Reader OAuth API Keys
OAUTH_KEY = 'www.example.com'
OAUTH_SECRET = 'SECRET_KEY_FROM_GOOGLE'

S3_ACCESS_KEY = 'XXX'
S3_SECRET = 'SECRET'
S3_BACKUP_BUCKET = 'newsblur_backups'
S3_PAGES_BUCKET_NAME = 'pages-XXX.newsblur.com'
S3_ICONS_BUCKET_NAME = 'icons-XXX.newsblur.com'

STRIPE_SECRET = "YOUR-SECRET-API-KEY"
STRIPE_PUBLISHABLE = "YOUR-PUBLISHABLE-API-KEY"

# ===============
# = Social APIs =
# ===============

FACEBOOK_APP_ID = '111111111111111'
FACEBOOK_SECRET = '99999999999999999999999999999999'
TWITTER_CONSUMER_KEY = 'ooooooooooooooooooooo'
TWITTER_CONSUMER_SECRET = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
YOUTUBE_API_KEY = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# =============
# = Databases =
# =============

DATABASES = {
    'default': {
        'NAME': 'newsblur',
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        #'ENGINE': 'django.db.backends.mysql',
        'USER': 'newsblur',
        'PASSWORD': 'newsblur',
        'HOST': 'postgres',
    },
}

MONGO_DB = {
    'name': 'newsblur',
    'host': 'db_mongo'
}
MONGO_ANALYTICS_DB = {
    'name': 'nbanalytics',
    'host': 'db_mongo',
    'port': 27017,
}

MONGODB_SLAVE = {
    'host': 'db_mongo'
}

# Celery RabbitMQ/Redis Broker
BROKER_URL = "redis://redis:6579/0"
CELERY_RESULT_BACKEND = BROKER_URL

REDIS = {
    'host': 'redis',
}
REDIS_PUBSUB = {
    'host': 'redis',
}
REDIS_STORY = {
    'host': 'redis',
}
REDIS_SESSIONS = {
    'host': 'redis',
    'port': 6579
}

CELERY_REDIS_DB_NUM = 4
SESSION_REDIS_DB = 5

ELASTICSEARCH_FEED_HOSTS = ["elasticsearch:9200"]
ELASTICSEARCH_STORY_HOSTS = ["elasticsearch:9200"]

BACKED_BY_AWS = {
    'pages_on_node': False,
    'pages_on_s3': False,
    'icons_on_s3': False,
}

ORIGINAL_PAGE_SERVER = "node"

# ===========
# = Logging =
# ===========

# Logging (setup for development)
LOG_TO_STREAM = True

if len(logging._handlerList) < 1:
    LOG_FILE = '~/newsblur/logs/development.log'
    logging.basicConfig(level=logging.DEBUG,
                            format='%(asctime)-12s: %(message)s',
                            datefmt='%b %d %H:%M:%S',
                            handler=logging.StreamHandler)

S3_ACCESS_KEY = '000000000000000000000'
S3_SECRET = '000000000000000000000000/0000000000000000'
S3_BACKUP_BUCKET = 'newsblur_backups'
S3_PAGES_BUCKET_NAME = 'pages-dev.newsblur.com'
S3_ICONS_BUCKET_NAME = 'icons-dev.newsblur.com'
S3_AVATARS_BUCKET_NAME = 'avatars-dev.newsblur.com'

MAILGUN_ACCESS_KEY = 'key-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
MAILGUN_SERVER_NAME = 'newsblur.com'

DO_TOKEN_LOG = '0000000000000000000000000000000000000000000000000000000000000000'
DO_TOKEN_FABRIC = '0000000000000000000000000000000000000000000000000000000000000000'

SERVER_NAME = "nblocalhost"
NEWSBLUR_URL = 'http://nb.local.com'

SESSION_ENGINE = 'redis_sessions.session'

# CORS_ORIGIN_REGEX_WHITELIST = ('^(https?://)?(\w+\.)?nb.local\.com$', )

YOUTUBE_API_KEY = "000000000000000000000000000000000000000"
RECAPTCHA_SECRET_KEY = "0000000000000000000000000000000000000000"
IMAGES_SECRET_KEY = "0000000000000000000000000000000"
